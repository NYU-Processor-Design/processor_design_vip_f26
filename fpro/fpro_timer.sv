// ============================================================================
// fpro_timer.sv : 48-bit system timer (slot 0)                  [ASSIGNMENT]
//
// WHAT IT DOES
//   A free-running counter that adds 1 every clock (25 MHz on the board), so
//   software can measure time and wait: 25 counts = 1 microsecond. 48 bits
//   wrap only after ~130 days. The driver builds sleep_us() / now_ms() on it.
//
// REGISTER MAP (word offsets inside the slot)
//   offset | access | contents
//   -------+--------+---------------------------------------------------------
//     0    |  R     | counter bits [31:0]
//     1    |  R     | counter bits [47:32] in bits [15:0] (upper bits 0)
//     2    |  W     | CTRL: bit 0 = go (1 = count, 0 = pause)
//          |        |       bit 1 = clear (1 = set the counter to 0; this bit
//          |        |               is NOT stored: it acts once, on the write)
//     2    |  R     | bit 0 = go (bit 1 reads 0)
//   other  |  R     | 0          (writes to offsets 0 and 1 are ignored)
//
// REQUIREMENTS
//   R1  After reset the counter is 0 and go = 1: time starts at power-on.
//   R2  While go = 1 the counter increments by exactly 1 every clock.
//       While go = 0 it holds its value.
//   R3  A write to CTRL with bit 1 = 1 sets the counter to 0 in that clock
//       (clear wins over counting). go takes the value of bit 0 of the same
//       write, so writing 3 means "clear and keep running" and writing 2 means
//       "clear and stay paused".
//   R4  Registers change only when  cs && write && (addr == offset).
//   R5  rd_data is combinational from addr; reading changes nothing.
//   R6  always_ff / always_comb / logic, synchronous active-high reset.
//
// HINTS
//   * This is the shortest core: two registers (count, go) and a read mux.
//   * Software reads the 48-bit value in two 32-bit halves; the driver (not
//     the hardware) handles a carry between the two reads.
//
// TEST IT
//   sw/run_unit_test.sh timer     this file alone          (tb/unit/tb_timer.sv)
//   sw/run_soc_test.sh timer      + driver + fpro_mmio_sys (sw/tests/timer_test.cpp)
// ======================== END OF SPECIFICATION ========================

module fpro_timer (
    input  logic        clk,
    input  logic        reset,
    // slot interface (FPro bus)
    input  logic        cs,
    input  logic        read,
    input  logic        write,
    input  logic [4:0]  addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data
);
    // TODO: 48-bit counter and the go bit (R1, R2)

    // TODO: CTRL write decoding: go and the one-shot clear (R3, R4)

    // TODO: read multiplexer (R5)

    // ---- placeholder so the project compiles: DELETE it as you implement ----
    assign rd_data = '0;
endmodule
