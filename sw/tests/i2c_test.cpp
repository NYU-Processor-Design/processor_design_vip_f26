// i2c_test.cpp : I2C core + I2cCore driver, on the whole SoC.
// The testbench has a 16-byte memory at address 0x50 (mem[i] = 0xC0 + i at start).
#include "fpro/i2c_core.h"
#include "test_util.h"

I2cCore i2c(get_slot_addr(BRIDGE_BASE, S4_I2C));

int main() {
    uint32_t f = 0;
    i2c.set_freq(400000);                         // 400 kHz
    if (io_read(get_slot_addr(BRIDGE_BASE, S4_I2C), 1) != 15) f |= 1u << 0;   // dvsr

    const uint8_t w[] = {0x02, 0x11, 0x22, 0x33};   // pointer 2, then three bytes
    if (i2c.write_transaction(0x50, w, 4) != 0) f |= 1u << 1;

    uint8_t p = 0x02, r[3] = {0, 0, 0};
    if (i2c.write_read(0x50, &p, 1, r, 3) != 0) f |= 1u << 2;
    if (r[0] != 0x11 || r[1] != 0x22 || r[2] != 0x33) f |= 1u << 3;

    if (i2c.write_transaction(0x51, w, 1) != -1) f |= 1u << 4;   // nobody at 0x51

    p = 0x0A;
    if (i2c.write_read(0x50, &p, 1, r, 2) != 0) f |= 1u << 5;
    if (r[0] != 0xCA || r[1] != 0xCB) f |= 1u << 6;
    test_done(f);
}
