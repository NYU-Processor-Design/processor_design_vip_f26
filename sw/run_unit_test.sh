#!/bin/bash
# Unit-test peripheral cores on their own: the testbench drives the slot bus
# directly (no CPU, no software), so you can test your hardware before the
# driver or fpro_mmio_sys exist.
#   usage:  sw/run_unit_test.sh uart          one peripheral
#           sw/run_unit_test.sh gpio pwm      several
#           sw/run_unit_test.sh               all six: gpio timer uart spi i2c pwm
#   VERBOSE=1 sw/run_unit_test.sh uart     also show which group of checks is running
#   waveforms:  VFLAGS="--trace -DVCD" sw/run_unit_test.sh uart   -> uart.vcd
# needs:   verilator (v5+), a C++ compiler
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
. "$HERE/hdl_files.sh"
OUT=${OUT:-$ROOT/build}
list=("$@"); [ ${#list[@]} -eq 0 ] && list=("${PERIPHERALS[@]}")

mkdir -p "$OUT"
rc=0
for p in "${list[@]}"; do
    src=${PERIPH_SRC[$p]:-}
    [ -n "$src" ] || { echo "unknown peripheral '$p' (one of: ${PERIPHERALS[*]})"; rc=2; continue; }
    if ! verilator_build "tb_$p" "$OUT/unit_$p" "$src" "${MODEL_SRCS[@]}" "$ROOT/testbench/unit/tb_$p.sv" > "$OUT/unit_$p.log" 2>&1; then
        cat "$OUT/unit_$p.log"
        echo "UNIT TEST $p: BUILD FAILED"; rc=1; continue
    fi
    res=$( "$OUT/unit_$p/Vtb_$p" 2>&1 )
    if [ -n "${VERBOSE:-}" ]; then echo "$res" | grep -E 'FAIL|PASS|TIMEOUT|^--'
    else                           echo "$res" | grep -E 'FAIL|PASS|TIMEOUT'; fi
    echo "$res" | grep -q "UNIT TEST $p: PASS" || rc=1
done
exit $rc
