#!/bin/bash
# Run the official riscv-tests rv32ui suite on a SystemVerilog core, using Verilator.
#   usage:  sw/run_riscv_tests_sv.sh /path/to/riscv-tests
#
# Differences from run_riscv_tests.sh (the Icarus/Verilog version):
#   * the RTL is *.sv, and any package files (*_pkg.sv) are compiled FIRST
#   * Verilator compiles the core ONCE into a C++ simulator (instead of once per test).
#     Each test then runs in its own folder containing instr.mem / data.mem, which the
#     simulator loads with $readmemh at start-up (the testbench defaults to those names).
#   * the testbench uses #delays, so Verilator needs --timing (Verilator 5.x)
#
# needs: verilator >= 5.0, riscv64-unknown-elf-gcc, python3, a C++ compiler + make
set -u
RVT=${1:?path to riscv-tests checkout}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
OUT=${OUT:-/tmp/rv_out_sv}
TOP=${TOP:-tb}                              # name of the testbench module
TB=${TB:-$ROOT/testbench/integration-test/core_tb.sv}               # testbench file
CC=${CC:-riscv64-unknown-elf-gcc}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
SKIP="fence_i ma_data"                      # outside this core's scope (Zifencei, misaligned access)
mkdir -p "$OUT"

# ---- 1. build the simulator once -------------------------------------------
# packages first (order matters in SystemVerilog), then everything else
PKGS=$(ls "$ROOT"/src/*_pkg.sv 2>/dev/null)
RTL=$(ls "$ROOT"/src/*.sv | grep -v '_pkg\.sv$')
echo "== building Verilator model =="
if ! verilator --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style \
        --top-module "$TOP" -Mdir "$OUT/obj_dir" \
        -DIMEM_FILE='"instr.mem"' -DDMEM_FILE='"data.mem"' \
        $PKGS $RTL "$TB" > "$OUT/verilator_build.log" 2>&1; then
    echo "Verilator build FAILED; see $OUT/verilator_build.log"
    tail -20 "$OUT/verilator_build.log"
    exit 2
fi
SIM=$OUT/obj_dir/V$TOP

# ---- 2. build and run every test -------------------------------------------
pass=0; fail=0; failed=""
for src in "$RVT"/isa/rv32ui/*.S; do
    t=$(basename "$src" .S)
    case " $SKIP " in *" $t "*) echo "SKIP  $t"; continue;; esac
    d=$OUT/$t; mkdir -p "$d"
    if ! $CC -march=rv32i -mabi=ilp32 -mno-relax -mcmodel=medany -static -nostdlib -nostartfiles \
         -I"$HERE" -I"$RVT/isa/macros/scalar" -T"$HERE/link.ld" "$src" -o "$d/$t.elf" 2> "$d/cc.log"; then
        echo "BUILD-FAIL $t"; fail=$((fail+1)); failed="$failed $t"; continue
    fi
    $OBJCOPY -O binary -j .text "$d/$t.elf" "$d/imem.bin"
    $OBJCOPY -O binary -j .data -j .rodata "$d/$t.elf" "$d/dmem.bin"
    python3 "$HERE/bin2mem.py" "$d/imem.bin" "$d/instr.mem"
    python3 "$HERE/bin2mem.py" "$d/dmem.bin" "$d/data.mem"
    res=$(cd "$d" && "$SIM" 2>&1 | grep -E 'PASS|FAIL|TIMEOUT' | head -1)
    printf '%-8s %s\n' "$t" "${res:-NO-RESULT}"
    case "$res" in PASS*) pass=$((pass+1));; *) fail=$((fail+1)); failed="$failed $t";; esac
done
echo "------------------------------"
echo "passed: $pass   failed: $fail   $failed"
[ "$fail" -eq 0 ]