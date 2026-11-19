#!/bin/bash
# hdl_files.sh : the ONE list of SystemVerilog sources, in compile order, and
# the Verilator build helper. Sourced by the scripts:  . "$HERE/hdl_files.sh"
# (needs ROOT set).
#
# Order matters for SystemVerilog: a package must be compiled before any module
# that imports it, so riscv_pkg.sv comes first. If you add a .sv file, add it here.

RTL_SRCS=(
    # "$ROOT/src/riscv_pkg.sv"          # package: must be first
    "$ROOT/src/alu.sv"
    "$ROOT/src/control_unit.sv"
    "$ROOT/src/reg_file.sv"
    "$ROOT/src/data_mem.sv"
    "$ROOT/src/instr_mem.sv"
    "$ROOT/src/instr_imm.sv"
    "$ROOT/src/branch_decoder.sv"
    "$ROOT/src/top.sv"
)

# the bus (finished) ...
BUS_SRCS=(
    "$ROOT/fpro/fpro_bridge.sv"
    "$ROOT/fpro/fpro_mmio_ctrl.sv"
    "$ROOT/fpro/fpro_scratch.sv"
)

# ... and one file per peripheral: the six assignment files
declare -A PERIPH_SRC=(
    [gpio]="$ROOT/fpro/fpro_gpio.sv"
    [timer]="$ROOT/fpro/fpro_timer.sv"
    [uart]="$ROOT/fpro/fpro_uart.sv"
    [spi]="$ROOT/fpro/fpro_spi.sv"
    [i2c]="$ROOT/fpro/fpro_i2c.sv"
    [pwm]="$ROOT/fpro/fpro_pwm.sv"
)
PERIPHERALS=(gpio timer uart spi i2c pwm)

FPRO_SRCS=(
    "${BUS_SRCS[@]}"
    "${PERIPH_SRC[gpio]}" "${PERIPH_SRC[timer]}" "${PERIPH_SRC[uart]}"
    "${PERIPH_SRC[spi]}"  "${PERIPH_SRC[i2c]}"   "${PERIPH_SRC[pwm]}"
    "$ROOT/fpro/fpro_mmio_sys.sv"
)

SOC_SRCS=(
    "$ROOT/soc/fpro_soc.sv"
)

# behavioural models of the outside world, used only by the testbenches
MODEL_SRCS=(
    "$ROOT/testbench/models/spi_slave_model.sv"
    "$ROOT/testbench/models/i2c_slave_model.sv"
)

# ---------------------------------------------------------------------------
# verilator_build TOP OUTDIR  file.sv ...
#   Builds a self-contained simulator executable OUTDIR/V<TOP> from a
#   testbench with delays (#, @, wait), using Verilator's --binary --timing.
#   The build log goes to OUTDIR/build.log; on failure it is printed.
#   Extra Verilator options can be passed in the VFLAGS environment variable,
#   e.g.  VFLAGS="--trace -DVCD" sw/run_unit_test.sh uart   (waveforms)
# ---------------------------------------------------------------------------
VERILATOR_FLAGS=(
    --binary --timing            # standalone executable; honour # / @ / wait in testbenches
    --timescale 1ns/1ps          # RTL files have no `timescale; testbenches use 1ns/1ps
    -O2 --x-assign fast --x-initial fast
    -Wno-fatal                   # report warnings, but don't stop the build on them
    -Wno-TIMESCALEMOD
    -I"$ROOT/fpro"               # for `include "fpro_map.svh"
    -I"$ROOT/testbench"                 # for `include "unit/slot_tb.svh"
)
verilator_build() {
    local top=$1 outdir=$2; shift 2
    mkdir -p "$outdir"
    # shellcheck disable=SC2086
    if ! verilator "${VERILATOR_FLAGS[@]}" ${VFLAGS:-} -j "$(nproc 2>/dev/null || echo 2)" \
            --top-module "$top" -Mdir "$outdir/obj_$top" -o "../V$top" "$@" \
            > "$outdir/build.log" 2>&1; then
        cat "$outdir/build.log"
        echo "verilator build of $top FAILED"
        return 1
    fi
}
