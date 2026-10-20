# NYU Processor Design VIP - Fall 2026

This repository contains the work that the processor design VIP team completed, has in-progress, and future work that will be done going forward. It also contains documentation on several different aspects of the project, and will contain hand-off documentation for future team leads and group members.

## Introduction

The project work for this semester is building a simple microcontroller from scratch, implementing a soft core onto an FPGA board. This includes:

* Designing a custom processor capable of executing RISC-V RV32I Base Integer Instruction Set machine code.
* Creating a custom assembler capable of assembling RV32I instructions into RV32I machine code compliant with the standard for purposes of our custom architecture.
* Implementing bus protocols for communication between the processor and custom microprocessor modules.
* Creating custom microprocessor modules that give basic microcontroller functionality, such as:
	* GPIO
	* Timers
	* UART
	* SPI
	* I2C
	* PWM
* Mapping memory to certain peripheral modules, as well as mapping on-board FPGA components (such as pins) to peripherals as well.
* Implementing the final design on an FPGA board and showcasing it by the end of the semester.

Some topics will not be visited until Spring 2027 and those include:

* Interrupts; only polling is supported currently.
* XADC: using the on-board ADC on Xilinx boards for purposes of the microcontroller.
* Multi-cycle design for the processor. This can be later expanded to pipelining if time permits, or a goal for Fall 2027.

## RV32I Core Modules

The RV32I core modules are the basic modules that make up the CPU. As part of the initial design for simulation and testing purposes, data memory is accessible directly without a memory controller. The following sections will define the modules in detail.

### Top

### Control Unit

### Register File

### Data Memory

### ALU - Arithmetic Logic Unit

### Branch Decoder

### Instruction Immediate Decoder

## Testing and Verification

Extensive testing will be done throughout the lifecycle of the project iteration this semester. This includes unit testing, where each individual module is tested, and integration testing, where the modules are tested altogether as one.

Within unit and integration testing, there are three levels of testing which is done for the sake of completeness:
* **Level 1 Verification:** tests to ensure that compilation is possible with no errors; basic tests with SystemVerilog testbenches are used to generate waveform files to ensure base-level correctness of the unit/integration. Team members assigned to these modules may use Icarus Verilog or Verilator as simulation tools.
* **Level 2 Verification:** tests are more thorough in nature, and now use SystemC testbenches and Verilator as a simulation tool. Various functionality of the unit or integration is tested by passing in various inputs and using assertions to ensure correctness.
* **Level 3 Verification:** these tests use the industry-standard Universal Verification Methodology (UVM) class library for SystemVerilog in order to test specific functions of a unit or integration that the other tests haven't caught. This includes directed testing, constrained random testing, error injection, edge cases such as overflow and underflow, and more.

### Running the Checks

The same checks run locally and in CI (`.github/workflows/sim.yml`, on every push and pull request). They need Icarus Verilog, Verilator, g++, make, and Python 3.

* `make lint`: lints each module in `src/` with `verilator -Wall`, then compiles everything with Icarus.
	* Modules listed in `LINT_SKIP` in the `Makefile` are unfinished stubs: they still fail on errors, but warnings are not enforced. Remove your module from that list in the pull request that implements it.
* `make l1`: runs every non-empty level 1 testbench in `testbench/level1_tb`. A test passes only if it prints `TEST PASSED`.
	* `<module>_tb.sv` runs with Icarus.
	* `<module>_tb.cpp` is built with Verilator against `src/<module>.sv`.
	* Logs go to `build/l1/`.
* `make table-check`: fails if `testbench/common/control_table.svh` is out of date with `docs/control_table.csv`; run `python3 scripts/gen_control_table.py` to regenerate it.
* `make ci`: runs all of the above, in that order. This is what CI runs.
