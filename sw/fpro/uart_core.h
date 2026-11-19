// ============================================================================
// uart_core.h : C++ driver for the UART (slot 1)                  [ASSIGNMENT]
//
// HOW EVERY DRIVER WORKS: see gpio_core.h and the finished scratch_core.h.
//   io_read(base_, REG) / io_write(base_, REG, value) access register REG.
//
// THE HARDWARE (registers of fpro/fpro_uart.sv)
//   offset 0  R  [7:0] received byte, [8] rx_empty, [9] tx_full
//   offset 1  W  baud divisor  dvsr = round(f_clk / (16 * baud)) - 1
//   offset 2  W  byte to transmit (lost if the TX FIFO is full: check tx_full first)
//   offset 3  W  any value: remove the received byte you just read
//
// WHAT TO WRITE: the methods below. Test with
//   sw/run_soc_test.sh uart     (program: sw/tests/uart_test.cpp)
//
// EXAMPLE
//   UartCore uart(get_slot_addr(BRIDGE_BASE, S1_UART));
//   uart.set_baud_rate(9600);
//   uart.disp("x = "); uart.disp(42); uart.disp('\n');    // prints "x = 42"
//   uart.disp(255, 16, 4);                                 // prints "00FF"
//   int c = uart.rx_byte(); if (c >= 0) uart.disp((char)c); // echo
//
// NOTE: f_clk in Hz is SYS_CLK_FREQ * 1000000 (fpro_map.h). "round(a / b)"
// in integer math is  (a + b/2) / b.
// ======================== END OF SPECIFICATION ========================
#ifndef UART_CORE_H
#define UART_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class UartCore {
public:
    enum { REG_RD = 0, REG_DVSR = 1, REG_WR = 2, REG_RM = 3 };
    enum { MASK_DATA = 0xFF, MASK_RX_EMPTY = 0x100, MASK_TX_FULL = 0x200 };
    constexpr explicit UartCore(uint32_t base) : base_(base) {}

    // Program the divisor for this baud rate (formula above, rounded).
    void set_baud_rate(uint32_t baud) {
        (void)baud;   // TODO
    }

    // Status bits from register 0.
    bool tx_full()  const { return false; }   // TODO
    bool rx_empty() const { return true; }    // TODO

    // Send one byte: wait while the TX FIFO is full, then write register 2.
    void tx_byte(uint8_t b) {
        (void)b;      // TODO
    }

    // Receive: return -1 if nothing has arrived (do not wait). Otherwise
    // return the byte (0..255) and remove it from the FIFO (write register 3).
    // Read register 0 only ONCE (status and data come together).
    int rx_byte() {
        return -1;    // TODO
    }

    // ---- console output: a very small printf replacement ----
    void disp(char ch)       { (void)ch; }   // TODO: one character
    void disp(const char *s) { (void)s; }    // TODO: a 0-terminated string
    void disp(int n)         { disp(n, 10, 0); }

    // Print n in `base` (2, 8, 10 or 16; digits above 9 are 'A'..'F'), with
    // leading zeros up to `len` digits (0 = no padding). In base 10 a negative
    // number prints as '-' and its magnitude; in other bases print the bits as
    // unsigned:  disp(-42) -> "-42",  disp(0xBEEF,16,4) -> "BEEF",
    //            disp(5, 2, 8) -> "00000101".
    // Hint: produce the digits backwards (u % base, u /= base) into a small
    // char array, then send them in reverse order. Careful with the most
    // negative int: negate as unsigned (0u - (unsigned)n).
    void disp(int n, int base, int len) {
        (void)n; (void)base; (void)len;   // TODO
    }

private:
    uint32_t base_;
};

#endif
