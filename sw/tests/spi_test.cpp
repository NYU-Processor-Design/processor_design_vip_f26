// spi_test.cpp : SPI core + SpiCore driver, on the whole SoC.
// Slave 0 (mode 0) answers 11 22 33; slave 1 (mode 3) answers A5 5A.
#include "fpro/spi_core.h"
#include "test_util.h"

SpiCore spi(get_slot_addr(BRIDGE_BASE, S3_SPI));

int main() {
    uint32_t f = 0;
    spi.set_freq(1000000);                        // 1 MHz
    if ((io_read(get_slot_addr(BRIDGE_BASE, S3_SPI), 3) & 0xFFFF) != 12) f |= 1u << 0;  // dvsr

    spi.set_mode(0, 0);
    spi.select(0);
    uint8_t r0 = spi.transfer(0x5A);
    uint8_t r1 = spi.transfer(0xC3);
    uint8_t r2 = spi.transfer(0x81);
    spi.deselect(0);
    if (r0 != 0x11 || r1 != 0x22 || r2 != 0x33) f |= 1u << 1;

    spi.set_mode(1, 1);
    if ((io_read(get_slot_addr(BRIDGE_BASE, S3_SPI), 3) >> 16) != 3) f |= 1u << 2;     // CPOL=CPHA=1
    spi.select(1);
    uint8_t q0 = spi.transfer(0x3C);
    uint8_t q1 = spi.transfer(0x96);
    spi.deselect(1);
    if (q0 != 0xA5 || q1 != 0x5A) f |= 1u << 3;
    test_done(f);
}
