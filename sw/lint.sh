#!/bin/bash
# Lint the synthesizable SystemVerilog with Verilator, without building a
# simulator (fast): syntax, width mismatches, always_comb/always_ff misuse,
# latches, multiply-driven signals, ...
#   usage:  sw/lint.sh            whole SoC + board top level
#           sw/lint.sh uart       just one peripheral file (gpio timer uart spi i2c pwm)
#           sw/lint.sh -Wall ...  also style warnings (unused signals, ...)
# needs:   verilator (v5+)
#
# The board top level (arty_top) uses two Xilinx primitives that only exist in
# Vivado; tb/sim_stubs/xilinx_prims.sv stands in for them here.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
. "$HERE/hdl_files.sh"
FLAGS=()
while [[ "${1:-}" == -* ]]; do FLAGS+=("$1"); shift; done

if [ -n "${1:-}" ]; then
    p=$1
    src=${PERIPH_SRC[$p]:-}
    [ -n "$src" ] || { echo "unknown peripheral '$p' (one of: ${PERIPHERALS[*]})"; exit 2; }
    verilator --lint-only "${FLAGS[@]}" -I"$ROOT/fpro" --top-module "fpro_$p" "$src"
    echo "lint $p: clean"
else
    verilator --lint-only "${FLAGS[@]}" -I"$ROOT/fpro" --top-module arty_top \
        "${RTL_SRCS[@]}" "${FPRO_SRCS[@]}" "${SOC_SRCS[@]}" \
        "$ROOT/testbench/sim_stubs/xilinx_prims.sv" "$ROOT/soc/arty_top.sv"
    echo "lint: clean"
fi
