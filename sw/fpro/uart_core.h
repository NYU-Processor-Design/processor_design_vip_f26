// UART console driver for FPro slot 1
// offset 0: RX byte, rx_empty at bit 8, tx_full at bit 9
// offset 1: 11-bit divisor, baud = clock_hz / (16 x (divisor + 1))
// offset 2: enqueue TX byte; offset 3: remove RX byte
#ifndef UART_CORE_H
#define UART_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

// retain the slot address without runtime initialization
class UartCore {
public:
    // register offsets and status fields
    enum { REG_RD = 0, REG_DVSR = 1, REG_WR = 2, REG_RM = 3 };
    enum { MASK_DATA = 0xFF, MASK_RX_EMPTY = 0x100, MASK_TX_FULL = 0x200 };
    constexpr explicit UartCore(uint32_t base) : base_(base) {}

    // round to the nearest tick period and clamp to the 11-bit divisor range
    void set_baud_rate(uint32_t baud) {
        // a zero baud request preserves the current setting
        if (baud == 0) return;

        // dividing first preserves rounding without overflowing at large baud
        const uint32_t bit_clocks = (SYS_CLK_FREQ * 1000000u) / baud;
        uint32_t ticks = (bit_clocks >> 4) + ((bit_clocks & 15u) >= 8u);

        // saturate unsupported rates instead of wrapping the divisor
        if (ticks == 0) ticks = 1;
        if (ticks > 2048u) ticks = 2048u;
        io_write(base_, REG_DVSR, ticks - 1u);
    }

    // read the current TX FIFO status
    bool tx_full() const {
        return (io_read(base_, REG_RD) & MASK_TX_FULL) != 0;
    }

    // read the current RX FIFO status
    bool rx_empty() const {
        return (io_read(base_, REG_RD) & MASK_RX_EMPTY) != 0;
    }

    // wait for FIFO space before sending one byte
    void tx_byte(uint8_t b) {
        // volatile MMIO reads observe the transmitter draining the FIFO
        while (tx_full()) {}
        io_write(base_, REG_WR, b);
    }

    // read status and data once, then remove only a valid RX byte
    int rx_byte() {
        const uint32_t status = io_read(base_, REG_RD);

        // an empty FIFO is not modified
        if ((status & MASK_RX_EMPTY) != 0) return -1;
        io_write(base_, REG_RM, 0);
        return static_cast<int>(status & MASK_DATA);
    }

    // preserve every character bit, including values above 127
    void disp(char ch) {
        tx_byte(static_cast<uint8_t>(ch));
    }

    // send a zero-terminated string; a null pointer produces no output
    void disp(const char *s) {
        // reject a missing string before dereferencing it
        if (s == nullptr) return;

        // use byte writes without newline translation
        while (*s != '\0') tx_byte(static_cast<uint8_t>(*s++));
    }

    // decimal output without padding
    void disp(int n) {
        disp(n, 10, 0);
    }

    // print decimal magnitude or unsigned bits in base 2, 8 or 16
    // len counts digits only; padding follows an optional minus sign
    void disp(int n, int base, int len) {
        // reject unsupported bases before division
        if (base != 2 && base != 8 && base != 10 && base != 16) return;
        uint32_t value = static_cast<uint32_t>(n);

        // unsigned negation also handles the most negative int
        if (base == 10 && n < 0) {
            tx_byte('-');
            value = 0u - value;
        }

        // collect at most 32 binary digits, including one digit for zero
        char digits[32];
        int used = 0;
        const uint32_t shift = base == 2 ? 1u : base == 8 ? 3u : 4u;
        const uint32_t mask = static_cast<uint32_t>(base - 1);

        // extract digits without general division for power-of-two bases
        do {
            uint32_t digit;

            // halve the remainder calculation to avoid a second division helper
            if (base == 10) {
                const uint32_t quotient = value / 10u;
                digit = ((value >> 1) - 5u * quotient) * 2u + (value & 1u); // restore parity
                value = quotient;
            } else {
                // binary, octal and hexadecimal take low bits directly
                digit = value & mask;
                value >>= shift;
            }

            // store least-significant digits first with uppercase hex letters
            digits[used++] = static_cast<char>(digit < 10u ? '0' + digit : 'A' + digit - 10u);
        } while (value != 0);

        // stream padding separately so len cannot overrun the digit buffer
        while (len > used) {
            tx_byte('0');
            --len;
        }

        // send the stored digits in their display order
        while (used != 0) tx_byte(static_cast<uint8_t>(digits[--used]));
    }

private:
    // byte address of the UART slot
    uint32_t base_;
};

#endif
