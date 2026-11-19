// ============================================================================
// xilinx_prims.sv : tiny behavioural stand-ins for the two Xilinx primitives
// used by soc/arty_top.sv, so that sw/lint.sh can check the board top level
// outside Vivado. NOT for synthesis: Vivado supplies the real primitives.
// ============================================================================
module MMCME2_BASE #(
    parameter real CLKIN1_PERIOD    = 10.0,
    parameter real CLKFBOUT_MULT_F  = 8.0,
    parameter int  DIVCLK_DIVIDE    = 1,
    parameter real CLKOUT0_DIVIDE_F = 32.0
)(
    input  logic CLKIN1, CLKFBIN, PWRDWN, RST,
    output logic CLKFBOUT, CLKOUT0, LOCKED
);
    assign CLKFBOUT = CLKIN1;
    assign CLKOUT0  = CLKIN1;     // lint only: frequency is not modelled
    assign LOCKED   = 1'b1;
endmodule

module BUFG (input logic I, output logic O);
    assign O = I;
endmodule
