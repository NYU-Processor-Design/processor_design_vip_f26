// Self-checking testbench helpers. Include inside the testbench module:
//   module alu_tb;
//       `include "tb_utils.svh"
// Checks use !== / !== 1'b1, so X and Z count as failures.
// End every test with `TB_FINISH, which prints TEST PASSED or TEST FAILED;
// test runners use that line to decide pass/fail.
// Every test dumps a waveform of the whole design to <testbench>.vcd, or to the
// path given with +wave=<file>.

int tb_errors = 0;
string tb_wave_file;

initial begin
    if (!$value$plusargs("wave=%s", tb_wave_file)) tb_wave_file = $sformatf("%m.vcd");
    $dumpfile(tb_wave_file);
    $dumpvars;
end

`define CHECK(COND, MSG) \
    begin \
        if ((COND) !== 1'b1) begin \
            tb_errors++; \
            $display("FAIL %s:%0d: %s", `__FILE__, `__LINE__, MSG); \
        end \
    end

`define CHECK_EQ(ACT, EXP, MSG) \
    begin \
        if ((ACT) !== (EXP)) begin \
            tb_errors++; \
            $display("FAIL %s:%0d: %s: got 0x%0h, expected 0x%0h", \
                     `__FILE__, `__LINE__, MSG, ACT, EXP); \
        end \
    end

`define TB_FINISH \
    begin \
        if (tb_errors == 0) $display("TEST PASSED"); \
        else $display("TEST FAILED (%0d errors)", tb_errors); \
        $finish; \
    end
