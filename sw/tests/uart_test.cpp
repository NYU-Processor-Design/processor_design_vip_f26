// uart_test.cpp : UART core + UartCore driver, on the whole SoC.
// Prints one line, then echoes two bytes the testbench sends (each + 1).
// The testbench checks the text:  "hi 1234 0xBEEF -42 00000101\nBD\n"
#include "fpro/uart_core.h"
#include "test_util.h"

UartCore uart(get_slot_addr(BRIDGE_BASE, S1_UART));

int main() {
    uint32_t f = 0;
    uart.set_baud_rate(156250);                   // 25 MHz / (16 * 10): exact, fast in simulation
    if (io_read(get_slot_addr(BRIDGE_BASE, S1_UART), 1) != 9) f |= 1u << 0;   // divisor
    if (!uart.rx_empty()) f |= 1u << 1;
    if (uart.rx_byte() != -1) f |= 1u << 2;       // nothing received yet

    uart.disp("hi ");
    uart.disp(1234);
    uart.disp(" 0x");
    uart.disp(0xBEEF, 16, 4);
    uart.disp(' ');
    uart.disp(-42);
    uart.disp(' ');
    uart.disp(5, 2, 8);                           // binary, padded to 8 digits
    uart.disp('\n');

    int c1, c2;
    uint32_t n = 0;
    while ((c1 = uart.rx_byte()) < 0 && n < 500000) n++;
    while ((c2 = uart.rx_byte()) < 0 && n < 500000) n++;
    if (n >= 500000) f |= 1u << 3;
    uart.disp((char)(c1 + 1));
    uart.disp((char)(c2 + 1));
    uart.disp('\n');
    while (!uart.rx_empty()) { }                  // (nothing more should arrive)

    n = 0;                                        // wait until the line is out
    while (n < 20000) n++;
    test_done(f);
}
