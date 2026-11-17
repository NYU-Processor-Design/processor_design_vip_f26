// ============================================================================
// fpro_i2c.sv : I2C master core (slot 4)                         [ASSIGNMENT]
//
// WHAT IT DOES
//   I2C is a two-wire bus (SCL clock, SDA data) shared by many devices
//   (sensors, EEPROMs, ...), each with a 7-bit address. Both wires are OPEN
//   DRAIN: a device can only pull a line low or let go of it; a pull-up
//   resistor makes it 1 when nobody pulls. So this core never drives a 1:
//     *_o = 0  pull the line low          *_o = 1  release it
//     *_i      the actual level of the line (what everybody sees)
//   The board's top level turns *_o into real open-drain pins (arty_top.sv).
//   On the board: shield header SCL / SDA, with the on-board pull-ups on.
//
//   Software drives the bus one COMMAND at a time:
//     START    SDA falls while SCL is high (bus is now ours; SCL is then held low)
//     WR       send 8 bits MSB first, then read the 9th (ACK) bit from the slave
//     RD       read 8 bits, then send the ACK bit (0 = "more please",
//              1 = NACK = "that was the last byte")
//     STOP     SDA rises while SCL is high (bus released)
//     RESTART  a START without a STOP first (switch from writing to reading)
//   Example, read register 3 of the device at 0x50:
//     START, WR 0xA0 (=0x50<<1|W), WR 0x03, RESTART, WR 0xA1 (=0x50<<1|R), RD last, STOP
//
// TIMING: everything is built from quarter periods of (dvsr+1) clocks;
//   f_scl = f_clk / (4 * (dvsr + 1)).   One data/ACK bit = 4 quarters:
//        q1          q2          q3          q4
//   SCL  low         high        high        low
//   SDA  <- set the bit while SCL is low; hold it while SCL is high ->
//                    sample SDA at the END of q2 (middle of the high time)
//   SDA may only change while SCL is low, EXCEPT for START (falls) and STOP
//   (rises), which happen while SCL is high: that is how devices tell them
//   apart from data.
//     START   (from idle: SCL=1, SDA=1)  SDA=0 for 2 quarters, then SCL=0 -> hold
//     STOP    (from hold: SCL=0)         SDA=0 1q; SCL=1 2q; SDA=1 2q -> idle
//     RESTART (from hold)                SDA=1 1q; SCL=1 2q; then a START
//
// FILE CONTENTS: two modules (finish both)
//   fpro_i2c_master   executes one command at a time
//   fpro_i2c          slot wrapper: registers + the master
//
// REGISTER MAP (word offsets inside the slot)
//   offset | access | contents
//   -------+--------+---------------------------------------------------------
//     0    |  R     | [7:0] byte from the last RD command
//          |        | [8]   ACK: 1 if the slave acknowledged the last WR byte
//          |        | [9]   READY: 1 = a new command may be written
//     1    |  W/R   | [15:0] dvsr. Reset value 62 (~100 kHz at 25 MHz)
//     2    |  W     | command: [10:8] = 0 START, 1 WR, 2 RD, 3 STOP, 4 RESTART
//          |        |          [7:0]  = byte to send (WR);  [0] = 1 "last byte" (RD)
//   other  |  R     | 0
//
// REQUIREMENTS
//   R1  START is accepted only when idle; WR, RD, STOP, RESTART only after a
//       START (bus held, SCL low). Any other command is ignored.
//   R2  READY is 1 when idle or holding the bus between commands, 0 while a
//       command runs. A command written while READY = 0 is ignored.
//   R3  Bit timing and the START/STOP/RESTART sequences exactly as above.
//       After reset and after STOP both lines are released (1).
//   R4  WR: the 9th bit is read with SDA released; ACK = (SDA was 0).
//       RD: SDA released for 8 bits; the 9th bit drives 0 (ACK) or, if
//       data[0] of the command was 1, releases SDA (NACK).
//   R5  scl_o / sda_o must come from flip-flops (no glitches on the bus).
//   R6  Registers change only when cs && write && (addr == offset); rd_data is
//       combinational; always_ff / always_comb / logic; synchronous reset.
//   (Clock stretching by slow slaves is NOT required: i2c_scl_i may be unused.)
//
// HINTS
//   * States: IDLE, START1, HOLD, D1..D4 (the four quarters of a bit),
//     STOP1..STOP3, RESTART1, RESTART2 (typedef enum). A counter times the
//     quarters; a flag or a second count handles the 2-quarter states.
//   * One 9-bit shift register can hold what to send: {data, 1} for WR,
//     {8'hFF, last} for RD; another collects what was sampled.
//   * Registering the outputs one clock behind the state is fine.
//   * Chu's "FPGA Prototyping by SystemVerilog Examples" has an I2C chapter
//     with a similar command-based design.
//
// TEST IT
//   sw/run_unit_test.sh i2c       this file alone, vs. an I2C memory model (tb/unit/tb_i2c.sv)
//   sw/run_soc_test.sh i2c        + driver + fpro_mmio_sys (sw/tests/i2c_test.cpp)
// ======================== END OF SPECIFICATION ========================

// ---------------------------------------------------------------------------
// Bus engine: executes one command at a time
// ---------------------------------------------------------------------------
module fpro_i2c_master (
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] dvsr,              // quarter period = dvsr+1 clocks
    input  logic        wr_cmd,            // 1-clock pulse: a new command
    input  logic [2:0]  cmd,               // 0 START, 1 WR, 2 RD, 3 STOP, 4 RESTART
    input  logic [7:0]  din,               // WR: byte to send; RD: din[0] = last byte
    output logic [7:0]  dout,              // byte from the last RD
    output logic        ack,               // 1 = last WR byte was acknowledged
    output logic        ready,             // 1 = idle or holding the bus
    output logic        scl_o,             // 0 = pull SCL low, 1 = release
    output logic        sda_o,             // 0 = pull SDA low, 1 = release
    input  logic        scl_i,             // actual SCL level (only for clock stretching)
    input  logic        sda_i              // actual SDA level
);
    // command codes
    localparam logic [2:0] CMD_START = 3'd0, CMD_WR = 3'd1, CMD_RD = 3'd2,
                           CMD_STOP  = 3'd3, CMD_RESTART = 3'd4;

    // TODO: state machine, quarter-period timer, bit counter (0..8),
    //       transmit / receive shift registers, dout and ack registers,
    //       registered scl_o / sda_o

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign dout  = '0;
    assign ack   = 1'b0;
    assign ready = 1'b1;
    assign scl_o = 1'b1;
    assign sda_o = 1'b1;
endmodule

// ---------------------------------------------------------------------------
// Slot wrapper
// ---------------------------------------------------------------------------
module fpro_i2c (
    input  logic        clk,
    input  logic        reset,
    // slot interface (FPro bus)
    input  logic        cs,
    input  logic        read,
    input  logic        write,
    input  logic [4:0]  addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    // external pins (open drain: *_o = 0 pulls the line low, *_i = line level)
    output logic        i2c_scl_o,
    output logic        i2c_sda_o,
    input  logic        i2c_scl_i,
    input  logic        i2c_sda_i
);
    // TODO: dvsr register (offset 1, reset 62)

    // TODO: instantiate fpro_i2c_master; a write to offset 2 is a command:
    //       cmd = wr_data[10:8], din = wr_data[7:0]

    // TODO: read multiplexer: offset 0 = {22'd0, ready, ack, rx_byte}, offset 1 = dvsr

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign rd_data   = '0;
    assign i2c_scl_o = 1'b1;
    assign i2c_sda_o = 1'b1;
endmodule
