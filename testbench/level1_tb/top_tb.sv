// level 1 compilation and clocked simulation without functional output checks
module top_tb;
    // local timing keeps the clock independent of other modules
    timeunit 1ns;
    timeprecision 1ps;

    // clock stimulus and optional waveform path
    logic clk;
    string wave_file;

    // load the synthetic fixture relative to the repository root
    top #(
        .INSTR_MEM_FILE("testbench/level1_tb/top_smoke.mem")
    ) dut (
        .clk(clk)
    );

    // generate a waveform without replacing unfinished production modules
    initial begin
        clk = 1'b0;

        // accept the existing level 1 runner's waveform destination
        if (!$value$plusargs("wave=%s", wave_file)) begin
            wave_file = "top_tb.vcd";
        end
        $dumpfile(wave_file);
        $dumpvars(0, top_tb);
        $display("top: smoke simulation only; no functional output checks");
        $display("top: unfinished dependencies may propagate unknown values");

        // run four cycles without randomized stimulus or assertions
        repeat (4) begin
            #5 clk = 1'b1; // 10 ns clock period
            #5 clk = 1'b0;
        end

        // the runner marker reports simulation completion only
        $display("TEST PASSED: top compiled and completed four clock cycles");
        $finish;
    end
endmodule
