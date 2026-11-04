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
    string wave_file;

    // initialize the fixture below instead of loading an external image
    top #(
        .INSTR_MEM_FILE("")
    ) dut (
        .clk(clk)
    );

    // generate a waveform without replacing unfinished production modules
    initial begin
        clk = 1'b0;

        // preload little-endian NOPs before the first rising edge
        for (int index = 0; index < FIXTURE_INSTRUCTIONS; index++) begin
            dut.instr_mem[2 * index] = NOP_INSTRUCTION[15:0]; // low halfword first
            dut.instr_mem[2 * index + 1] = NOP_INSTRUCTION[31:16];
        end

        // accept the existing level 1 runner's waveform destination
        if (!$value$plusargs("wave=%s", wave_file)) begin
            wave_file = "top_tb.vcd";
        end
        $dumpfile(wave_file);
        $dumpvars(0, top_tb);
        $display("top: smoke simulation only; no functional output checks");
        $display("top: unfinished dependencies may propagate unknown values");

        // use the same cycle count for fixture sizing and clock stimulus
        repeat (SMOKE_CYCLES) begin
            #5 clk = 1'b1; // 10 ns clock period
            #5 clk = 1'b0;
        end

        // the runner marker reports simulation completion only
        $display("TEST PASSED: top compiled and completed %0d clock cycles", SMOKE_CYCLES);
        $finish;
    end
endmodule
