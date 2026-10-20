# Level 1 Verification

At this level, you are expected to write your own testbenches to ensure that compilation is possible with no errors; basic tests with SystemVerilog testbenches are used to generate waveform files to ensure base-level correctness of the unit/integration. Team members assigned to these modules may use Icarus Verilog or Verilator as simulation tools.
## Writing a Test

Write either a SystemVerilog testbench (`<module>_tb.sv`, run with Icarus) or a C++ testbench (`<module>_tb.cpp`, run with Verilator).

### SystemVerilog (Icarus)

1. Copy `tb_template.sv` to `<module>_tb.sv` and rename the module to `<module>_tb`
2. Include `tb_utils.svh` inside the module (it lives in `testbench/common`, so compile with `-I testbench/common`)
3. Check results with the macros, and end the test with `` `TB_FINISH ``:
	* `` `CHECK(cond, "message") `` fails unless `cond` is exactly 1.
	* `` `CHECK_EQ(actual, expected, "message") `` fails unless the values match exactly.
	* `` `TB_FINISH `` prints `TEST PASSED` or `TEST FAILED` and ends the simulation.

X and Z count as failures. Every test writes a waveform to `<module>_tb.vcd`, or to the path given with `+wave=<file>`.

### C++ (Verilator)

1. Copy `tb_template.cpp` to `<module>_tb.cpp` and replace `Valu` with `V<module>`
2. Include `tb_utils.h`; set inputs, call `tb_eval(dut)` (instead of `dut.eval()`), then check the outputs:
	* `CHECK(cond, "message")` and `CHECK_EQ(actual, expected, "message")` work like the SystemVerilog macros.
	* `tick(dut)` runs one clock cycle for modules with a `clk` input.
	* End `main` with `return TB_FINISH();`.

Built with `--trace`, every `tb_eval` and `tick` adds a sample to `waves.vcd`, or to the path given with `+wave=<file>`.

Verilator only models 0 and 1, so undriven or uninitialized signals read as 0 instead of failing.
