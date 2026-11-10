# Project Toolchain + Testing Files
The following directory contains the toolchain components necessary for C++ compilation into valid RV32I assembly, as well as the files necessary for the official RV32I ISA tests to run.
## Requirements
Before running anything, there is a minimum set of dependencies given a Linux environment which must be installed in your environment. The following command installs all of them given your package manager is for Ubuntu:
```
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
                 python3 git make \
                 verilator build-essential
```
## Running The Official RV32I ISA Tests
The official set of tests is provided to the general public in a GitHub repository which we can clone locally. For purposes of our project, the tests have already been tested against for integration, but if you so choose you may do so by:
1. Making sure that ```sw/run_riscv_tests.sh``` is an executable. This can be done on the bash shell with the following command:
```
chmod +x sw/run_riscv_tests.sh
```
2. Cloning the official RISCV tests. Make sure to do this OUTSIDE of our project directory as we do not want to pollute it.
```
git clone https://github.com/riscv-software-src/riscv-tests.git
```
3. Run the following command from the root project directory:
```
sw/run_riscv_tests.sh ../path-to-cloned/riscv-tests/
```
4. The results of the tests will be displayed in the terminal (should all pass).
## Compiling Our Own C++ Files
The more fun part of this toolchain is that it allows us to write C++ code without having to deal with the specifics of assembly language. The following steps all assume that commands are run from the root project directory. The steps to compilation and simulation are as follows:
1. Compile C++ program(s) into valid RV32I machine code instructions returned as ```instr.mem``` and ```data.mem```.
```
sw/build.sh sw/prog.cpp
```
2. (optional) View what the C++ code actually assembles into (RV32I assembly).
```
# show real instructions instead of pseudo-instructions (e.g. addi x0,x0,0 instead of nop)
riscv64-unknown-elf-objdump -d -M no-aliases build/prog.elf
```
3. Build the Verilator simulation object.
```
verilator --binary --timing -Wno-fatal --timescale 1ns/1ps \
    --top-module tb -Mdir build/obj_dir \
    -DIMEM_FILE='"build/instr.mem"' -DDMEM_FILE='"build/data.mem"' \
    src/*.sv testbench/integration-test/core_tb.sv
```
4. Run the simulation.
```
build/obj_dir/Vtb
```
The simulation won't return anything specific like values of registers or whatnot, but it will tell you if the simulation passes or fails on the basis of interacting with an address in the IO address space. Refer to ```init_smoke.cpp``` for context.