// ============================================================================
// fpro_pwm.sv : pulse-width modulation core, 8 channels (slot 5) [ASSIGNMENT]
//
// WHAT IT DOES
//   Generates periodic digital waveforms with a configurable duty cycle.
//   Something slow (an LED seen by the eye, a motor) only responds to the
//   AVERAGE level, so the duty cycle sets brightness / speed.
//   On the board: ch0-2 = RGB LED LD0 (R,G,B), ch3-5 = RGB LED LD1 (R,G,B),
//   ch6-7 = Pmod JD pins 1-2 (motor driver, servo, oscilloscope).
//
//   All channels share one 8-bit counter that counts 0, 1, ..., 255, 0, ...
//   (one PERIOD = 256 steps). Each step lasts (dvsr+1) clocks.
//   Channel n is high while  count < duty[n]:
//
//     count:  0 1 2 ...    duty ...           255 | 0 1 2 ...
//     pwm  :  ‾‾‾‾‾‾‾‾‾‾‾‾‾|__________________    | ‾‾‾‾‾‾‾
//     average level = duty / 256        f_pwm = f_clk / (256 * (dvsr + 1))
//
//   duty = 0 is always off, 128 is 50 %, 256 is always on (that is why the
//   duty registers have 9 bits: 0..256 needs 257 values).
//
// FILE CONTENTS: two modules (finish both)
//   fpro_pwm_chan   one output channel (instantiated N times)
//   fpro_pwm        slot wrapper: registers, prescaler, shared counter, N channels
//
// REGISTER MAP (word offsets inside the slot)
//   offset | access | contents
//   -------+--------+---------------------------------------------------------
//     0    |  W/R   | [31:0] dvsr (prescaler). Reset value:
//          |        |   round(CLK_HZ / (256 * 1000)) - 1  = 97 at 25 MHz (~1 kHz)
//   16 + n |  W/R   | [8:0] duty of channel n (n = 0..N-1). Values 256..511
//          |        |   mean "always on". Reset value 0.
//   other  |  R     | 0
//
// REQUIREMENTS
//   R1  Prescaler: the counter advances once every (dvsr+1) clocks. If
//       software writes a smaller dvsr than the prescaler's current count,
//       the next step must come right away (compare with >=, not ==).
//   R2  Output n is high exactly while count < active duty n, so over one
//       period it is high for exactly duty * (dvsr+1) clocks (all 256*(dvsr+1)
//       for duty >= 256, none for 0).
//   R3  GLITCH-FREE UPDATE: a newly written duty takes effect at the start of
//       the NEXT period (when the counter wraps from 255 to 0), never in the
//       middle of a period. Reading back offset 16+n returns the value written
//       (even before it takes effect).
//   R4  Outputs come from flip-flops (register the comparison): no glitches.
//   R5  After reset all outputs are low and all duties are 0.
//   R6  Registers change only when cs && write && (addr == offset); rd_data is
//       combinational; always_ff / always_comb / logic; synchronous reset.
//
// HINTS
//   * fpro_pwm_chan needs two duty registers: the one software wrote, and the
//     "active" one copied from it when period_start = 1.
//   * fpro_pwm: a generate loop  for (genvar i = 0; i < N; i++) begin : g_ch
//     creates the channels; the write enable for channel i is
//     cs && write && (addr == 5'(16 + i)).
//   * For the read mux over N channels, an always_comb with a for loop works.
//
// TEST IT
//   sw/run_unit_test.sh pwm       this file alone          (tb/unit/tb_pwm.sv)
//   sw/run_soc_test.sh pwm        + driver + fpro_mmio_sys (sw/tests/pwm_test.cpp)
// ======================== END OF SPECIFICATION ========================

// ---------------------------------------------------------------------------
// One output channel
// ---------------------------------------------------------------------------
module fpro_pwm_chan (
    input  logic       clk,
    input  logic       reset,
    input  logic       wr_duty,           // 1-clock pulse: load duty_in
    input  logic [8:0] duty_in,
    input  logic       period_start,      // 1 for one clock when the count wraps to 0
    input  logic [7:0] count,             // the shared 0..255 counter
    output logic [8:0] duty,              // the value software wrote (for read-back)
    output logic       pwm_out
);
    // TODO: written duty register, active duty register (copied at period_start),
    //       registered comparison  count < active

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign duty    = '0;
    assign pwm_out = 1'b0;
endmodule

// ---------------------------------------------------------------------------
// Slot wrapper
// ---------------------------------------------------------------------------
module fpro_pwm #(
    parameter int N      = 8,              // number of channels (1..16)
    parameter int CLK_HZ = 25_000_000
)(
    input  logic         clk,
    input  logic         reset,
    // slot interface (FPro bus)
    input  logic         cs,
    input  logic         read,
    input  logic         write,
    input  logic [4:0]   addr,
    input  logic [31:0]  wr_data,
    output logic [31:0]  rd_data,
    // external pins
    output logic [N-1:0] pwm
);
    // reset value of the prescaler: ~1 kHz PWM frequency
    localparam logic [31:0] DVSR_INIT = 32'((CLK_HZ + 128_000) / 256_000 - 1);

    // TODO: dvsr register (offset 0)

    // TODO: prescaler (R1) and the shared 8-bit counter; period_start pulse

    // TODO: N x fpro_pwm_chan in a generate loop

    // TODO: read multiplexer (offset 0 and offsets 16 .. 16+N-1)

    // ---- placeholders so the project compiles: DELETE these as you implement ----
    assign rd_data = '0;
    assign pwm     = '0;
endmodule
