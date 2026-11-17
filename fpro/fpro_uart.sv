// ============================================================================
// fpro_uart.sv : serial port (UART) core (slot 1)                [ASSIGNMENT]
//
// WHAT IT DOES
//   Sends and receives bytes over a serial line: 8 data bits, no parity,
//   1 stop bit ("8N1"). On the board it is the USB-UART: a terminal program
//   on the PC talks to the microcontroller (it is the system console).
//
//   One frame on the wire (the line idles at 1):
//       ___     ___ ___ ___ ___ ___ ___ ___ ___ ________
//          |___|b0_|b1_|b2_|b3_|b4_|b5_|b6_|b7_|  stop  (idle)
//          start  (data LSB first)               =1
//   Every bit lasts 16 "ticks". A tick is a 1-clock pulse every (dvsr+1)
//   clocks, so  baud = f_clk / (16 * (dvsr + 1)).
//
// FILE CONTENTS: four modules (finish all four)
//   fpro_fifo     small first-in-first-out buffer (used twice: RX and TX)
//   fpro_uart_rx  receiver: line -> bytes
//   fpro_uart_tx  transmitter: bytes -> line
//   fpro_uart     slot wrapper: baud generator, registers, the two FIFOs
//                 and the two engines connected together
//
// REGISTER MAP (word offsets inside the slot)
//   offset | access | contents
//   -------+--------+---------------------------------------------------------
//     0    |  R     | [7:0] received byte (head of the RX FIFO)
//          |        | [8]   rx_empty (1 = no byte waiting)
//          |        | [9]   tx_full  (1 = TX FIFO cannot take another byte)
//     1    |  W/R   | [10:0] baud divisor dvsr. Reset value:
//          |        |        round(CLK_HZ / (16 * BAUD)) - 1   (162 at 25 MHz, 9600)
//     2    |  W     | [7:0] byte to send: pushed into the TX FIFO
//          |        |       (dropped if the FIFO is full)
//     3    |  W     | any value: remove the head byte of the RX FIFO
//   other  |  R     | 0
//
// REQUIREMENTS
//   R1  FIFOs: 2**FIFO_AW entries (16). Writing a full FIFO or removing from
//       an empty one does nothing. The head entry is visible at all times
//       (asynchronous read). Reset empties them.
//   R2  Baud generator: tick = 1 for one clock every (dvsr+1) clocks.
//   R3  Transmitter: when the TX FIFO is not empty, take the head byte
//       (pop it) and send start bit, b0..b7, stop bit; each exactly 16 ticks.
//       tx is 1 when idle and during reset.
//   R4  Receiver: input goes through a 2-flip-flop synchronizer. Wait for the
//       line to go low, check it is still low at the MIDDLE of the start bit
//       (tick 7; otherwise it was a glitch), then sample each data bit and the
//       stop bit in their middles (every 16 ticks). Only a stop bit of 1 makes
//       a valid byte: push it into the RX FIFO (lost if the FIFO is full).
//       A frame with a 0 stop bit is discarded.
//   R5  Reading register 0 does NOT remove the byte (reads never change
//       anything); software writes register 3 to remove it.
//   R6  Registers change only when cs && write && (addr == offset); rd_data is
//       combinational; always_ff / always_comb / logic; synchronous reset.
//
// HINTS
//   * Both engines are small state machines: IDLE, START, DATA, STOP, using a
//     4-bit tick counter (0..15) and a 3-bit bit counter (0..7).
//   * Use a typedef enum for the states, e.g.
//         typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
//   * FIFO: two pointers with ONE EXTRA BIT. Equal pointers = empty; same
//     index but different top bit = full.
//   * Chu's "FPGA Prototyping by SystemVerilog Examples" covers both the FIFO
//     and the UART with this same design.
//
// TEST IT
//   sw/run_unit_test.sh uart      this file alone          (tb/unit/tb_uart.sv)
//   sw/run_soc_test.sh uart       + driver + fpro_mmio_sys (sw/tests/uart_test.cpp)
// ======================== END OF SPECIFICATION ========================

// ---------------------------------------------------------------------------
// Synchronous FIFO with an always-visible head entry
// ---------------------------------------------------------------------------
module fpro_fifo #(
    parameter int W  = 8,                  // bits per entry
    parameter int AW = 4                   // depth = 2**AW entries
)(
    input  logic         clk,
    input  logic         reset,
    input  logic         wr,               // push wdata (ignored when full)
    input  logic [W-1:0] wdata,
    input  logic         rd,               // remove the head entry (ignored when empty)
    output logic [W-1:0] rdata,            // the head entry (valid when !empty)
    output logic         empty,
    output logic         full
);
    // TODO: storage array, write/read pointers (AW+1 bits each), empty/full

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign rdata = '0;
    assign empty = 1'b1;
    assign full  = 1'b0;
endmodule

// ---------------------------------------------------------------------------
// Receiver: serial line -> bytes
// ---------------------------------------------------------------------------
module fpro_uart_rx (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,               // 16x baud enable pulse
    input  logic       rx,                 // asynchronous serial input
    output logic       done,               // 1-clock pulse: `data` holds a valid byte
    output logic [7:0] data
);
    // TODO: 2-FF synchronizer, state machine, tick counter, bit counter, shift register

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign done = 1'b0;
    assign data = '0;
endmodule

// ---------------------------------------------------------------------------
// Transmitter: bytes -> serial line
// ---------------------------------------------------------------------------
module fpro_uart_tx (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,               // 16x baud enable pulse
    input  logic       start,              // a byte is waiting (TX FIFO not empty)
    input  logic [7:0] din,                // that byte (TX FIFO head)
    output logic       pop,                // 1-clock pulse: "I took the byte" (removes it)
    output logic       tx                  // serial output, 1 when idle
);
    // TODO: state machine, tick counter, bit counter, shift register

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign pop = 1'b0;
    assign tx  = 1'b1;
endmodule

// ---------------------------------------------------------------------------
// Slot wrapper
// ---------------------------------------------------------------------------
module fpro_uart #(
    parameter int CLK_HZ  = 25_000_000,    // system clock frequency
    parameter int BAUD    = 9600,          // baud rate selected at reset
    parameter int FIFO_AW = 4              // FIFO depth = 2**FIFO_AW bytes
)(
    input  logic        clk,
    input  logic        reset,
    // slot interface (FPro bus)
    input  logic        cs,
    input  logic        read,
    input  logic        write,
    input  logic [4:0]  addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    // external pins
    input  logic        rx,
    output logic        tx
);
    // reset value of the divisor (rounded): 162 for 25 MHz and 9600 baud
    localparam logic [10:0] DVSR_INIT = 11'((CLK_HZ + 8*BAUD) / (16*BAUD) - 1);

    // TODO: dvsr register (offset 1) and the baud-rate tick generator (R2)

    // TODO: write decoding for offsets 1, 2 and 3

    // TODO: instantiate two fpro_fifo (RX and TX), fpro_uart_rx and fpro_uart_tx
    //       and connect them:  rx engine -> RX FIFO -> register 0
    //                          register 2 -> TX FIFO -> tx engine

    // TODO: read multiplexer: offset 0 = {22'd0, tx_full, rx_empty, rx_head}, offset 1 = dvsr

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign rd_data = '0;
    assign tx      = 1'b1;
endmodule
