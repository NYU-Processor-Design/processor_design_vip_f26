# The FPro bus and the slot interface

This is an implementation of the FPro bus from Pong P. Chu's *FPGA
Prototyping by SystemVerilog Examples*, written from the book's specification.
The bus protocol, address layout and slot interface follow the book.

## Big picture

```
risc_v core ──io_* port──► fpro_bridge ──FPro bus──► fpro_mmio_ctrl ──► slot 0 .. slot N-1
 (loads/stores            (decode window,           (slot decode +      (your cores)
  at 0xC0000000+)          split mmio/video)         read-data mux)
```

Every peripheral ("core") owns one **slot** of 32 word-sized registers.
Register `r` of the core in slot `n` is at the byte address

    0xC0000000 + n*128 + r*4

In C++ use `get_slot_addr(BRIDGE_BASE, n)` and `io_read` / `io_write`
(`sw/fpro/fpro_io.h`).

## The slot interface: every core has exactly these ports

```systemverilog
input  logic        clk,        // system clock (25 MHz)
input  logic        reset,      // synchronous, active high
input  logic        cs,         // this slot is selected
input  logic        read,       // bus read strobe   (broadcast to all slots)
input  logic        write,      // bus write strobe  (broadcast to all slots)
input  logic [4:0]  addr,       // register offset in the slot (broadcast)
input  logic [31:0] wr_data,    // write data (broadcast)
output logic [31:0] rd_data     // read data: combinational from addr
```

plus the core's own pins.

## Timing: one clock per transaction

* **Write:** a store puts address, data and `write` on the bus for one clock.
  The target register samples it at the rising edge that ends that clock.
  So a register's write enable is `cs && write && (addr == N)`, used in an
  `always_ff`.
* **Read:** the read data path is combinational all the way back to the CPU
  (slot decode → your `rd_data` mux → CPU), and must settle within the clock.
  So `rd_data` comes from an `always_comb` `case (addr)`.
* There is **no ready/handshake**: a core cannot make the CPU wait. If an
  operation takes time (a UART byte, an SPI transfer), the core provides a
  status bit that software polls.
* Reads may happen at any time, so **reading a register must never change
  anything** in a core. Actions are always triggered by writes (e.g. the
  UART's "remove the received byte" is a write to register 3).

## Files

| File | Status | Purpose |
|---|---|---|
| `fpro_map.svh` | finished | slot numbers, bridge base, clock, board widths |
| `fpro_bridge.sv` | finished | CPU io port → FPro bus |
| `fpro_mmio_ctrl.sv` | finished | slot decode + read multiplexer |
| `fpro_scratch.sv` | finished | four plain registers: **the worked example** (slot 6) |
| `fpro_mmio_sys.sv` | **assignment** | controller + all cores: connect yours here |
| `fpro_gpio.sv` … `fpro_pwm.sv` | **assignment** | the six peripheral cores |

A slot with nothing attached reads `0xFFFFFFFF`, so a wrong slot number in
software is easy to spot. (The placeholders in `fpro_mmio_sys.sv` read the
same way until you connect your core.)
