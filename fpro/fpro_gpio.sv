// ============================================================================
// fpro_gpio.sv : general-purpose input/output core (slot 2)      [ASSIGNMENT]
//
// WHAT IT DOES
//   One core that handles both directions of simple digital I/O. Software
//   writes a register to drive N_OUT output pins, and reads N_IN input pins.
//   It also remembers rising edges (e.g. button presses), so a program that
//   only checks the buttons now and then does not miss a short press.
//   On the Arty board (wired in fpro_mmio_sys.sv / fpro_soc.sv):
//     dout[3:0] -> green LEDs LD4-LD7
//     din[3:0]  <- slide switches SW0-SW3      din[7:4] <- buttons BTN0-BTN3
//
// REGISTER MAP (word offsets inside the slot)
//   offset | access | contents
//   -------+--------+---------------------------------------------------------
//     0    |  W/R   | DATA_OUT: bits [N_OUT-1:0] drive dout. Upper write bits
//          |        |   are ignored; upper read bits are 0. Reset value 0.
//     1    |  R     | DATA_IN: the input pins after a 2-flip-flop synchronizer,
//          |        |   zero-extended to 32 bits. Writes are ignored.
//     2    |  R     | EDGE: bit i = 1 if input i went 0 -> 1 since software
//          |        |   last cleared that bit. Reset value 0.
//     2    |  W     | write 1s to clear EDGE bits ("write-1-to-clear"):
//          |        |   writing 0x05 clears bits 0 and 2, leaves the rest alone.
//   other  |  R     | 0
//
// REQUIREMENTS
//   R1  A register changes only when  cs && write && (addr == its offset).
//   R2  rd_data is combinational from addr (an always_comb case statement).
//       Reading must never change anything: the CPU may read at any time.
//   R3  din is asynchronous to clk, so pass it through TWO flip-flops before
//       using it anywhere. DATA_IN must not change in the very first clock
//       after a pin changes.
//   R4  Edge detection: compare the synchronized input with its value one
//       clock earlier (one more flip-flop). A 0 -> 1 change sets the flag; the
//       flag stays set until software clears it, even if the input goes low
//       again. Falling edges set nothing. If software clears a bit in the same
//       clock that a new edge arrives on it, the edge wins (flag stays 1).
//   R5  Synchronous, active-high reset clears DATA_OUT and EDGE.
//   R6  always_ff for flip-flops, always_comb for combinational logic, logic
//       for every signal.
//
// HINTS
//   * fpro/fpro_scratch.sv is a finished core with exactly this structure.
//   * 32'(x) zero-extends x to 32 bits; '0 is "all zeros, any width".
//   * Keep the code parameterized (N_IN, N_OUT): the board uses 8 and 4.
//
// TEST IT
//   sw/run_unit_test.sh gpio      this file alone          (tb/unit/tb_gpio.sv)
//   sw/run_soc_test.sh gpio       + driver + fpro_mmio_sys (sw/tests/gpio_test.cpp)
// ======================== END OF SPECIFICATION ========================

module fpro_gpio #(
    parameter int N_IN  = 8,
    parameter int N_OUT = 4
)(
    input  logic             clk,
    input  logic             reset,
    // slot interface (FPro bus)
    input  logic             cs,
    input  logic             read,
    input  logic             write,
    input  logic [4:0]       addr,
    input  logic [31:0]      wr_data,
    output logic [31:0]      rd_data,
    // external pins
    input  logic [N_IN-1:0]  din,
    output logic [N_OUT-1:0] dout
);
                     // TODO (R1): write enables for offset 0 (DATA_OUT) and offset 2 (EDGE clear)

                        // TODO: DATA_OUT register (always_ff, reset to 0) driving dout
	logic wr_out_en;
	logic wr_edge_clr;

	assign wr_out_en   = cs && write && (addr == 5'd0);
	assign wr_edge_clr = cs && write && (addr == 5'd2);

	always_ff @(posedge clk) begin
        if (reset)
            dout <= '0;
        else if (wr_out_en)
            dout <= wr_data[N_OUT-1:0];
	end
                        // TODO (R3): two-flip-flop synchronizer for din
	logic [N_IN-1:0] din_sync1;
	logic [N_IN-1:0] din_sync2;

	always_ff @(posedge clk) begin
            if (reset) begin
                din_sync1 <= '0;
                din_sync2 <= '0;
            end else begin
                din_sync1 <= din;
                din_sync2 <= din_sync1;
            end
	end
                        // TODO (R4): one more flip-flop + rising-edge flags (EDGE register)
	logic [N_IN-1:0] din_prev;
	logic [N_IN-1:0] edge_reg;
	logic [N_IN-1:0] rising_edge;

	assign rising_edge = din_sync2 & ~din_prev;

	always_ff @(posedge clk) begin
            if (reset) begin
                din_prev <= '0;
                edge_reg <= '0;
            end else begin
                din_prev <= din_sync2;

                if (wr_edge_clr)
                        edge_reg <= (edge_reg & ~wr_data[N_IN-1:0]) | rising_edge;
                else
                        edge_reg <= edge_reg | rising_edge;
            end
	end
                        // TODO (R2): read multiplexer (always_comb case on addr)
	always_comb begin
            case (addr)
                5'd0:    rd_data = 32'(dout);
                5'd1:    rd_data = 32'(din_sync2);
                5'd2:    rd_data = 32'(edge_reg);
                default: rd_data = 32'd0;
            endcase
	end
                        // ---- placeholders so the project compiles: DELETE these as you implement ----
endmodule
