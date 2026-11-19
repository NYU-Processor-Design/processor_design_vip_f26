// gpio_test.cpp : GPIO core + GpioCore driver, on the whole SoC.
// The testbench holds the switches at 0110, presses BTN2 at phase 1 and
// releases it at phase 2. Each failed check sets one bit of `f`.
#include "fpro/gpio_core.h"
#include "test_util.h"

GpioCore gpio(get_slot_addr(BRIDGE_BASE, S2_GPIO));

int main() {
    uint32_t f = 0;
    if (gpio.switches() != 0x6) f |= 1u << 0;     // switches = 0110
    if (gpio.buttons()  != 0x0) f |= 1u << 1;
    gpio.write(0x9u);
    if (gpio.read_out() != 0x9) f |= 1u << 2;     // output register read-back
    gpio.write(0, 0);                             // clear bit 0 only -> 0x8
    if (gpio.read_out() != 0x8) f |= 1u << 3;
    gpio.write(2, 1);                             // set bit 2 only -> 0xC
    if (gpio.read_out() != 0xC) f |= 1u << 4;

    gpio.clear_edges(0xFF);                       // forget edges seen at power-up
    if (gpio.edges() != 0) f |= 1u << 5;

    test_phase(1);                                // testbench presses BTN2
    uint32_t n = 0;
    while (!gpio.pressed(2) && n < 200000) n++;
    if (n >= 200000) f |= 1u << 6;                // never saw the press
    if (!gpio.read(4 + 2)) f |= 1u << 7;          // button still held: input bit 6 = 1
    if (gpio.edges() & (1u << 6)) f |= 1u << 8;   // pressed() must clear the flag

    test_phase(2);                                // testbench releases BTN2
    n = 0;
    while (gpio.read(6) && n < 200000) n++;
    spin(50);
    if (gpio.pressed(2)) f |= 1u << 9;            // releasing is not a rising edge

    gpio.write(gpio.switches());                  // LEDs = switches (checked by the testbench)
    test_done(f);
}
