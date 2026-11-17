// ============================================================================
// fpro_spi.sv : SPI master core (slot 3)                         [ASSIGNMENT]
//
// WHAT IT DOES
//   SPI is a fast synchronous serial bus: the master (us) drives the clock
//   SCLK and shifts a byte out on MOSI while the selected slave shifts a byte
//   back on MISO, at the same time, MSB first. Each slave has its own
//   active-low select line ss_n; software controls the selects directly.
//   On the board: Pmod JA  pin 1 = ss_n[0], 2 = MOSI, 3 = MISO, 4 = SCLK,
//   7 = ss_n[1].
//
// THE FOUR SPI MODES  (CPOL = idle level of SCLK, CPHA = which edge samples)
//   The first SCLK edge of each bit is the LEADING edge, the second the
//   TRAILING edge.
//     CPHA = 0: MOSI/MISO must be valid BEFORE the leading edge; both sides
//               SAMPLE on the leading edge and SHIFT on the trailing edge.
//     CPHA = 1: both sides SHIFT on the leading edge and SAMPLE on the
//               trailing edge.
//
//   One bit = two half periods, each (dvsr+1) clocks:   f_sclk = f_clk / (2*(dvsr+1))
//                    |<-  P0  ->|<-  P1  ->|
//   CPOL=0, CPHA=0:  ____________/‾‾‾‾‾‾‾‾‾‾\   (rises at P0->P1: sample)
//   CPOL=0, CPHA=1:  /‾‾‾‾‾‾‾‾‾‾\____________   (rises at the start of P0: shift)
//   With CPOL=1 the clock is simply inverted.
//   So in EVERY mode: sample MISO at the end of P0, shift MOSI at the end of
//   P1. Only the SCLK waveform differs.
//
// FILE CONTENTS: two modules (finish both)
//   fpro_spi_engine  transfers one byte when told to
//   fpro_spi         slot wrapper: registers + the engine
//
// REGISTER MAP (word offsets inside the slot)
//   offset | access | contents
//   -------+--------+---------------------------------------------------------
//     0    |  R     | [7:0] byte received in the last transfer
//          |        | [8]   READY (1 = idle, a new transfer may start)
//     1    |  W/R   | [N_SS-1:0] ss_n output values (0 = slave selected).
//          |        |   Reset: all 1 (nothing selected).
//     2    |  W     | [7:0] byte to send: STARTS a transfer if READY = 1;
//          |        |   ignored while a transfer is running.
//     3    |  W/R   | CTRL: [15:0] dvsr, [16] CPOL, [17] CPHA.
//          |        |   Reset: dvsr = 12 (~1 MHz), CPOL = CPHA = 0.
//   other  |  R     | 0
//
// REQUIREMENTS
//   R1  A transfer is exactly 8 bits, MSB first, 16 SCLK edges, each SCLK
//       half period exactly (dvsr+1) clocks.
//   R2  SCLK equals CPOL whenever no transfer is running (also after reset).
//   R3  READY drops in the clock after the write to register 2 and comes back
//       when the 8th bit has finished; the received byte is then readable
//       from register 0 and stays there until the next transfer finishes.
//   R4  ss_n comes straight from register 1 (the engine never touches it).
//       Software changes CPOL/CPHA/dvsr only while READY = 1 and nothing is
//       selected; you do not need to handle changes during a transfer.
//   R5  Registers change only when cs && write && (addr == offset); rd_data is
//       combinational; always_ff / always_comb / logic; synchronous reset.
//
// HINTS
//   * Engine states: IDLE, P0, P1 (typedef enum). A 16-bit counter times each
//     half period; a 3-bit counter counts bits; two 8-bit shift registers
//     (out and in). MOSI is just the top bit of the "out" register.
//   * SCLK = CPOL XOR active, where active is 1 during P1 (CPHA=0) or
//     during P0 (CPHA=1).
//   * Chu's "FPGA Prototyping by SystemVerilog Examples" has an SPI chapter
//     with a similar design.
//
// TEST IT
//   sw/run_unit_test.sh spi       this file alone, all 4 modes (tb/unit/tb_spi.sv)
//   sw/run_soc_test.sh spi        + driver + fpro_mmio_sys     (sw/tests/spi_test.cpp)
// ======================== END OF SPECIFICATION ========================

// ---------------------------------------------------------------------------
// Shift engine: one 8-bit transfer per start pulse
// ---------------------------------------------------------------------------
module fpro_spi_engine (
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] dvsr,              // half period = dvsr+1 clocks
    input  logic        cpol,
    input  logic        cpha,
    input  logic        start,             // 1-clock pulse: begin a transfer (only when ready)
    input  logic [7:0]  din,               // byte to send
    output logic [7:0]  dout,              // byte received (valid after done)
    output logic        ready,             // 1 = idle
    output logic        done,              // 1-clock pulse when a transfer ends
    output logic        sclk,
    output logic        mosi,
    input  logic        miso
);
    // TODO: state machine (IDLE, P0, P1), half-period counter, bit counter,
    //       shift registers; sclk / mosi / ready from the state

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign dout  = '0;
    assign ready = 1'b1;
    assign done  = 1'b0;
    assign sclk  = cpol;
    assign mosi  = 1'b1;
endmodule

// ---------------------------------------------------------------------------
// Slot wrapper
// ---------------------------------------------------------------------------
module fpro_spi #(
    parameter int N_SS = 2                 // number of slave-select lines
)(
    input  logic            clk,
    input  logic            reset,
    // slot interface (FPro bus)
    input  logic            cs,
    input  logic            read,
    input  logic            write,
    input  logic [4:0]      addr,
    input  logic [31:0]     wr_data,
    output logic [31:0]     rd_data,
    // external pins
    output logic            spi_sclk,
    output logic            spi_mosi,
    input  logic            spi_miso,
    output logic [N_SS-1:0] spi_ss_n
);
    // TODO: write decoding for offsets 1, 2, 3

    // TODO: ss_n register (reset all 1s) and CTRL register (reset dvsr = 12, CPOL = CPHA = 0)

    // TODO: instantiate fpro_spi_engine; a write to offset 2 is its start pulse

    // TODO: read multiplexer

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign rd_data  = '0;
    assign spi_sclk = 1'b0;
    assign spi_mosi = 1'b1;
    assign spi_ss_n = '1;
endmodule
