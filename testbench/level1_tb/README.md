# Level 1 Verification

At this level, you are expected to write your own testbenches to ensure that compilation is possible with no errors; basic tests with SystemVerilog testbenches are used to generate waveform files to ensure base-level correctness of the unit/integration. Team members assigned to these modules may use Icarus Verilog or Verilator as simulation tools.
## Writing a Test

1. Copy `tb_template.sv` to `<module>_tb.sv` and rename the module to `<module>_tb`
2. Include `tb_utils.svh` inside the module (it lives in `testbench/common`, so compile with `-I testbench/common`)
3. Check results with the macros, and end the test with `` `TB_FINISH ``:
	* `` `CHECK(cond, "message") `` fails unless `cond` is exactly 1.
	* `` `CHECK_EQ(actual, expected, "message") `` fails unless the values match exactly.
	* `` `TB_FINISH `` prints `TEST PASSED` or `TEST FAILED` and ends the simulation.

X and Z count as failures in Icarus. Verilator only models 0 and 1, so it can't catch them; run your test in Icarus too.
