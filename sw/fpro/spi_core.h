// ============================================================================
// spi_core.h : C++ driver for the SPI master (slot 3)            [ASSIGNMENT]
//
// HOW EVERY DRIVER WORKS: see gpio_core.h and the finished scratch_core.h.
//   io_read(base_, REG) / io_write(base_, REG, value) access register REG.
//
// THE HARDWARE (registers of fpro/fpro_spi.sv)
//   offset 0  R  [7:0] byte received in the last transfer, [8] READY
//   offset 1  W  [1:0] slave selects ss_n (0 = selected, active low)
//   offset 2  W  [7:0] byte to send: starts a transfer (only when READY = 1)
//   offset 3  W  CTRL: [15:0] dvsr, [16] CPOL, [17] CPHA
//                f_sclk = f_clk / (2 * (dvsr + 1))
//
// WHAT TO WRITE: the methods below. Test with
//   sw/run_soc_test.sh spi      (program: sw/tests/spi_test.cpp)
//
// EXAMPLE: read the ID register 0x0F of a typical SPI sensor in mode 0
//   SpiCore spi(get_slot_addr(BRIDGE_BASE, S3_SPI));
//   spi.set_freq(1000000);  spi.set_mode(0, 0);
//   spi.select(0);
//   spi.transfer(0x80 | 0x0F);          // command: read register 0x0F
//   uint8_t id = spi.transfer(0x00);    // send a dummy byte, get the answer
//   spi.deselect(0);
//
// NOTE: registers 1 and 3 hold several fields, but the hardware only lets you
// write the whole word. Keep a copy of what you last wrote (ctrl_, ss_) and
// change only the field you need: dvsr in set_freq, CPOL/CPHA in set_mode.
// ======================== END OF SPECIFICATION ========================
#ifndef SPI_CORE_H
#define SPI_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class SpiCore {
public:
    enum { REG_RD = 0, REG_SS = 1, REG_WR = 2, REG_CTRL = 3 };
    enum { MASK_DATA = 0xFF, MASK_READY = 0x100, CPOL_BIT = 16, CPHA_BIT = 17 };
    // ctrl_ and ss_ start at the hardware's reset values
    constexpr explicit SpiCore(uint32_t base) : base_(base), ctrl_(12), ss_(0xFFFFFFFFu) {}

    // SCLK frequency: dvsr = round(f_clk / (2 * hz)) - 1, f_clk = SYS_CLK_FREQ * 1000000.
    // Keep CPOL/CPHA as they are.  (1 MHz -> dvsr = 12)
    void set_freq(uint32_t hz) {
        (void)hz;   // TODO
    }

    // Choose the SPI mode (cpol, cpha each 0 or 1). Keep dvsr as it is.
    void set_mode(int cpol, int cpha) {
        (void)cpol; (void)cpha;   // TODO
    }

    // Slave select: drive ss_n[n] low (select) / high (deselect); leave the
    // other lines unchanged.
    void select(int n)   { (void)n; }   // TODO
    void deselect(int n) { (void)n; }   // TODO
    void deselect_all()  { }            // TODO

    // READY bit of register 0.
    bool ready() const { return true; } // TODO

    // One full-duplex byte: wait until ready, write `out` to register 2
    // (starts the transfer), wait until ready again, return the received byte.
    uint8_t transfer(uint8_t out) {
        (void)out;
        return 0;   // TODO
    }

private:
    uint32_t base_;
    uint32_t ctrl_;     // last value written to CTRL (offset 3)
    uint32_t ss_;       // last value written to the slave selects (offset 1)
};

#endif
