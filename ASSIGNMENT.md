# Assignment: peripherals for our RISC-V microcontroller

We have a working RISC-V processor, the FPro bus that connects it to
peripherals, a C++ toolchain, and a full test setup. The table below details the peripherals that must be added in order to have a working microcontroller.

| Peripheral | Slot | What it does | Board pins |
|---|---|---|---|
| **GPIO**  | 2 | LEDs out, switches/buttons in, button-press capture | 4 LEDs, 4 switches, 4 buttons |
| **Timer** | 0 | 48-bit clock counter: measure time, `sleep_us()` | — |
| **UART**  | 1 | serial port, 8N1 (the system console) | USB-UART |
| **SPI**   | 3 | SPI master, all 4 modes, 2 slave selects | Pmod JA |
| **I2C**   | 4 | I2C master (START / WR / RD / STOP / RESTART) | shield SCL / SDA |
| **PWM**   | 5 | 8 channels, duty cycle 0..256/256 | RGB LEDs LD0/LD1, Pmod JD |

```
                      ┌──────────────── fpro_soc ─────────────────────────────────┐
  C++ program         │  risc_v ──io──► fpro_bridge ──FPro bus──► fpro_mmio_sys    │
  + YOUR DRIVERS ───► │  (CPU)          (0xC000_0000+)            │  slot 0 TIMER  │──
  (sw/fpro/*.h)       │                                           │  slot 1 UART   │── pins
                      │                                           │  slot 2 GPIO   │──
                      │                                           │  slot 3 SPI    │──
                      │                                           │  slot 4 I2C    │──
                      │                                           │  slot 5 PWM    │──
                      │                                           │  slot 6 scratch│ (finished example)
                      └───────────────────────────────────────────────────────────┘
```

## For each peripheral you do three things

| # | Part | File | What is in it already |
|---|---|---|---|
| 1 | **Hardware** (SystemVerilog) | `fpro/fpro_<name>.sv` | the full specification at the top (register map, requirements, hints); every module with its complete port list (FPro slot bus + pins); `TODO` markers; placeholder lines that keep everything compiling |
| 2 | **Connect it** | `fpro/fpro_mmio_sys.sv`, section `>>> SLOT n <NAME>` | which slot, parameters and pins to use; placeholder lines to delete |
| 3 | **Driver** (C++) | `sw/fpro/<name>_core.h` | the register map from software's point of view, an example of use, every method with its job and a hint |

**Finished examples to copy from:** `fpro/fpro_scratch.sv` (a complete core),
the `scratch_slot6` instance at the bottom of `fpro_mmio_sys.sv`, and
`sw/fpro/scratch_core.h` (a complete driver).

The six peripherals do **not** depend on each other: each one's tests use only
its own three parts, so group members can work in parallel. (The timer and
UART are needed by the final board demo, `sw/demo/board_demo.cpp`.)

## Workflow for one peripheral (example: UART)

1. **Read the specification** at the top of `fpro/fpro_uart.sv`.
2. **Write the hardware** and test it on its own (no CPU, no software):
   ```
   sw/lint.sh uart              # syntax / width / always_comb problems, in seconds
   sw/run_unit_test.sh uart     # testbench/unit/tb_uart.sv drives the slot bus directly
   ```
   A failing check names the requirement, e.g.
   `FAIL  reading does not remove the byte : got 0x...0A3, expected 0x...055`.
3. **Connect it** in `fpro/fpro_mmio_sys.sv` (section `>>> SLOT 1 UART`) and
   delete that section's placeholder lines. `sw/lint.sh` must stay clean.
4. **Write the driver** `sw/fpro/uart_core.h`.
5. **Test everything together**: the CPU runs `sw/tests/uart_test.cpp`, which
   uses your driver to talk to your hardware, while the testbench checks the
   pins (here: a serial terminal reads what you print and types back):
   ```
   sw/run_soc_test.sh uart
   ```
   If the program's own checks fail, it reports a code: bit *n* set = check
   *n* failed. Look for `f |= 1u << n` in `sw/tests/uart_test.cpp`.
6. When everything is done: `sw/check_all.sh` prints the whole table.

## Rules

* Edit only: `fpro/fpro_{gpio,timer,uart,spi,i2c,pwm}.sv`, the `TODO`
  sections of `fpro/fpro_mmio_sys.sv`, and `sw/fpro/{gpio,timer,uart,spi,i2c,pwm}_core.h`.
  You may add helper modules inside your `.sv` file.
* Do not change port lists, register maps or method signatures: the tests,
  the other drivers and the board files depend on them.
* Do not edit the testbenches or test programs. Grading uses the original
  copies of them.
* SystemVerilog style (checked by `sw/lint.sh` and in review): `logic` for
  every signal, `always_ff` for flip-flops, `always_comb` for combinational
  logic, synchronous active-high `reset`, no latches.

## Debugging

* `VERBOSE=1 sw/run_unit_test.sh spi` shows which group of checks is running.
* Waveforms: `VFLAGS="--trace -DVCD" sw/run_unit_test.sh spi` writes `spi.vcd`
  (`sw/run_soc_test.sh` writes `soc_spi.vcd`); open it with GTKWave.
* `sw/lint.sh -Wall uart` also warns about unused signals: often a sign of a
  wire you forgot to connect.
* Verilator is a 2-state simulator: there is no `x`. A flip-flop you forgot
  to reset starts at 0, which can hide a bug that would show on the board.
* The models of the outside world are in `testbench/models/` (SPI slave, I2C
  memory); reading them is a good way to see what the bus should look like.

## What "done" means

`sw/check_all.sh` shows PASS for lint, core, and both the **unit** and **SoC**
column of your peripheral, and the code follows the style rules. Then load
the design on the board and run `sw/demo/board_demo.cpp`.
