# RISC-V microcontroller on the Arty A7-100T

A single-cycle RV32I core with Pong Chu's FPro bus, written in SystemVerilog,
simulated with Verilator. **Start with [ASSIGNMENT.md](ASSIGNMENT.md).**

```
src/        the CPU core (finished)
fpro/       the FPro bus (finished) and the six peripheral cores (assignment);
            fpro/README.md explains the bus and the slot interface
soc/        fpro_soc.sv (CPU + bus + cores), arty_top.sv (board pins), arty_a7_100t.xdc
testbench/         tb_soc.sv (whole SoC + device models), tb_risc_v.sv (CPU only)
testbench/unit/    one unit testbench per peripheral + shared helpers (slot_tb.svh)
testbench/models/  behavioural SPI slave and I2C memory used by the testbenches
sw/         toolchain (build.sh, link.ld, crt0.S) and the test scripts
sw/fpro/    C++ drivers: one header per core (assignment) + scratch_core.h (example)
sw/tests/   one C++ test program per peripheral (run by sw/run_soc_test.sh)
sw/demo/    board_demo.cpp: everything together, for the real board
```

## Tools

* Verilator **5 or newer**, a host C++ compiler (`g++`/`clang++`) and `make`
* `riscv64-unknown-elf-gcc` (no multilib needed), `python3`
* Vivado for the board (any recent version with Arty A7 support)

If your RISC-V toolchain uses another prefix (e.g. `riscv32-unknown-elf-`),
change `P=` in `sw/build.sh`.

## Commands (run from this folder)

| Command | What it does |
|---|---|
| `sw/lint.sh [name]` | Verilator lint: whole design, or one peripheral file |
| `sw/run_unit_test.sh [name ...]` | peripheral hardware alone (testbench drives the slot bus) |
| `sw/run_soc_test.sh [name ...]` | CPU + driver + hardware + `fpro_mmio_sys` (C++ test program) |
| `sw/check_all.sh [name ...]` | all of the above, with a summary table |
| `sw/run_core_test.sh sw/smoke.c` | CPU smoke test (C); also `sw/cpp_smoke.cpp` (C++) |
| `sw/run_riscv_tests.sh <riscv-tests>` | the 40 official RV32I tests on the CPU |
| `sw/build.sh a.cpp b.cpp ...` | compile a program into `build/instr.mem`, `build/data.mem` |

`name` is one of `gpio timer uart spi i2c pwm`. Waveforms: put
`VFLAGS="--trace -DVCD"` in front of a test command.

## Memory map

| Address | What |
|---|---|
| `0x0000_0000` | instruction memory, 32 KB (own bus: Harvard) |
| `0x1000_0000` | data RAM, 16 KB (.data, .rodata, .bss, stack) |
| `0xC000_0000` | FPro I/O: slot *n*, register *r* at `0xC000_0000 + n*128 + r*4` |

Slots: 0 timer, 1 UART, 2 GPIO, 3 SPI, 4 I2C, 5 PWM, 6 scratch
(`fpro/fpro_map.svh` and `sw/fpro/fpro_map.h`, which must agree).

## Board pins (Arty A7-100T)

| Function | Pins |
|---|---|
| clock / reset | 100 MHz E3 → MMCM → 25 MHz system clock; red RESET button C2 |
| GPIO | SW0–3 and BTN0–3 in, green LEDs LD4–LD7 out |
| UART | USB-UART bridge (A9 in, D10 out) |
| SPI  | Pmod JA: 1 = SS0, 2 = MOSI, 3 = MISO, 4 = SCLK, 7 = SS1 |
| I2C  | shield header SCL (L18) / SDA (M18), on-board pull-ups enabled |
| PWM  | ch0–2 RGB LED LD0 (R,G,B), ch3–5 RGB LED LD1, ch6–7 Pmod JD pins 1–2 |

## Vivado

* Design sources: `src/*.sv`, `fpro/*.sv`, `soc/*.sv` (not `testbench/`). Top: `arty_top`.
* Add `fpro/` to the include path (for `fpro_map.svh`); mark it as a global
  include if Vivado asks.
* Constraints: `soc/arty_a7_100t.xdc`.
* Memory init: run `sw/build.sh sw/fpro/fpro_init.cpp your_program.cpp` and add
  `build/instr.mem` and `build/data.mem` to the project.
* The design has not been through Vivado timing closure yet: check the timing
  report for the 25 MHz clock.
