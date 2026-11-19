#!/bin/bash
# Run peripherals on the whole SoC: the CPU runs sw/tests/<name>_test.cpp,
# which uses YOUR driver (sw/fpro/<name>_core.h) to drive YOUR core through
# fpro_mmio_sys. The testbench (tb/tb_soc.sv) checks the pins.
#   usage:  sw/run_soc_test.sh uart           one peripheral
#           sw/run_soc_test.sh spi i2c        several
#           sw/run_soc_test.sh                all six
#   waveforms:  VFLAGS="--trace -DVCD" sw/run_soc_test.sh uart   -> soc_uart.vcd
# needs:   riscv64-unknown-elf-gcc, verilator (v5+), a C++ compiler, python3
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
. "$HERE/hdl_files.sh"
OUT=${OUT:-$ROOT/build}
mkdir -p "$OUT"
list=("$@"); [ ${#list[@]} -eq 0 ] && list=("${PERIPHERALS[@]}")

# the SoC model is built once and runs any program
if ! verilator_build tb_soc "$OUT/sim_soc" "${RTL_SRCS[@]}" "${FPRO_SRCS[@]}" "${SOC_SRCS[@]}" \
        "${MODEL_SRCS[@]}" "$ROOT/testbench/tb_soc.sv" > "$OUT/sim_soc.log" 2>&1; then
    cat "$OUT/sim_soc.log"
    for p in "${list[@]}"; do echo "SOC TEST $p: BUILD FAILED (hardware)"; done
    exit 1
fi

rc=0
for p in "${list[@]}"; do
    src="$HERE/tests/${p}_test.cpp"
    [ -f "$src" ] || { echo "unknown test '$p' (one of: ${PERIPHERALS[*]})"; rc=2; continue; }
    d="$OUT/prog_$p"; mkdir -p "$d"
    if ! OUT="$d" "$HERE/build.sh" "$src" > "$d/build.log" 2>&1; then
        cat "$d/build.log"
        echo "SOC TEST $p: BUILD FAILED (software)"; rc=1; continue
    fi
    res=$( "$OUT/sim_soc/Vtb_soc" +TEST="$p" +IMEM="$d/instr.mem" +DMEM="$d/data.mem" 2>&1 )
    echo "$res" | grep -E 'FAIL|PASS|TIMEOUT|terminal:|TB:'
    echo "$res" | grep -q "SOC TEST $p: PASS" || rc=1
done
exit $rc
