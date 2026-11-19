#!/bin/bash
# Build a C / C++ program and run it on the core alone (tb/tb_risc_v.sv, Verilator).
# The program reports its verdict by writing 0xC0000000 (1 = PASS).
#   usage:  sw/run_core_test.sh sw/smoke.c
#           sw/run_core_test.sh sw/cpp_smoke.cpp
# needs:   riscv64-unknown-elf-gcc, verilator (v5+), a C++ compiler, python3
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$HERE/..
. "$HERE/hdl_files.sh"
OUT=${OUT:-$ROOT/build}
OUT="$OUT" "$HERE/build.sh" "$@" > /dev/null 2>&1
verilator_build tb "$OUT/sim_core" "${RTL_SRCS[@]}" "$ROOT/testbench/tb_risc_v.sv"
"$OUT/sim_core/Vtb" +IMEM="$OUT/instr.mem" +DMEM="$OUT/data.mem" | grep -E 'PASS|FAIL|TIMEOUT'
