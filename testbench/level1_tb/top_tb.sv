// level 1 compilation and clocked simulation without functional output checks
module top_tb;
    // local timing keeps the clock independent of other modules
    timeunit 1ns;
    timeprecision 1ps;

    // one extra instruction covers the fetch after the final PC update
    localparam int SMOKE_CYCLES = 4;
    localparam int FIXTURE_INSTRUCTIONS = SMOKE_CYCLES + 1;
    localparam logic [31:0] NOP_INSTRUCTION = 32'h00000013;

    // clock stimulus and optional waveform path
    logic clk;
    logic reset;
    logic [31:0] io_addr, io_wdata;
    logic io_we, io_re;
    string wave_file;

    // instr_mem starts as all NOPs when no image is given
    top #(
        .IMEM_INIT(""),
        .DMEM_INIT("")
    ) dut (
        .clk(clk),
        .reset(reset),
        .io_addr(io_addr),
        .io_wdata(io_wdata),
        .io_we(io_we),
        .io_re(io_re),
        .io_rdata(32'h0)
    );

    // generate a waveform without replacing unfinished production modules
    initial begin
        clk = 1'b0;
        reset = 1'b1;

        // accept the existing level 1 runner's waveform destination
        if (!$value$plusargs("wave=%s", wave_file)) begin
            wave_file = "top_tb.vcd";
        end
        $dumpfile(wave_file);
        $dumpvars(0, top_tb);
        $display("top: smoke simulation only; no functional output checks");
        $display("top: unfinished dependencies may propagate unknown values");

        // use the same cycle count for fixture sizing and clock stimulus
        #5 clk = 1'b1;
        #5 clk = 1'b0;
        reset = 1'b0;
        repeat (SMOKE_CYCLES) begin
            #5 clk = 1'b1; // 10 ns clock period
            #5 clk = 1'b0;
        end

        // the runner marker reports simulation completion only
        $display("TEST PASSED: top compiled and completed %0d clock cycles", SMOKE_CYCLES);
        $finish;
    end
endmodule
