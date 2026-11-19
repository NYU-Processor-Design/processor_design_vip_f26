// ============================================================================
// i2c_core.h : C++ driver for the I2C master (slot 4)            [ASSIGNMENT]
//
// HOW EVERY DRIVER WORKS: see gpio_core.h and the finished scratch_core.h.
//   io_read(base_, REG) / io_write(base_, REG, value) access register REG.
//
// THE HARDWARE (registers of fpro/fpro_i2c.sv)
//   offset 0  R  [7:0] byte from the last RD, [8] ACK of the last WR, [9] READY
//   offset 1  W  dvsr:  f_scl = f_clk / (4 * (dvsr + 1))
//   offset 2  W  command = (code << 8) | data
//                code 0 START, 1 WR (data = byte), 2 RD (data bit 0 = last byte),
//                     3 STOP,  4 RESTART
//   Write a command only when READY = 1, and wait for READY again before
//   looking at the result of WR (ACK) or RD (data).
//
// I2C ADDRESSES: a device has a 7-bit address dev. The first byte after
// START is (dev << 1) | 0 to write to it, (dev << 1) | 1 to read from it.
//
// WHAT TO WRITE: the methods below. Build the low-level ones first; the two
// transactions are made only of calls to them. Test with
//   sw/run_soc_test.sh i2c      (program: sw/tests/i2c_test.cpp)
//
// EXAMPLE: a temperature sensor at 0x48 -- set its register pointer to 0,
// then read 2 bytes:
//   I2cCore i2c(get_slot_addr(BRIDGE_BASE, S4_I2C));
//   i2c.set_freq(100000);
//   uint8_t reg = 0, t[2];
//   if (i2c.write_read(0x48, &reg, 1, t, 2) != 0) { /* no answer */ }
// ======================== END OF SPECIFICATION ========================
#ifndef I2C_CORE_H
#define I2C_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class I2cCore {
public:
    enum { REG_RD = 0, REG_DVSR = 1, REG_CMD = 2 };
    enum { CMD_START = 0, CMD_WR = 1, CMD_RD = 2, CMD_STOP = 3, CMD_RESTART = 4 };
    enum { MASK_DATA = 0xFF, MASK_ACK = 0x100, MASK_READY = 0x200 };
    constexpr explicit I2cCore(uint32_t base) : base_(base) {}

    // SCL frequency: dvsr = round(f_clk / (4 * hz)) - 1   (400 kHz -> 15)
    void set_freq(uint32_t hz) {
        (void)hz;   // TODO
    }

    // READY bit of register 0.
    bool ready() const { return true; }   // TODO

    // ---- low level: one command each ----
    // Use the private helper command() below for all of them.
    void start()   { /* TODO */ }
    void restart() { /* TODO */ }
    void stop()    { /* TODO */ }

    // Send one byte; wait until READY; return true if the slave ACKed it.
    bool write_byte(uint8_t b) {
        (void)b;
        return false;   // TODO
    }

    // Read one byte; `last` = true makes the master NACK it (the last byte of
    // a read). Wait until READY, then return the byte.
    uint8_t read_byte(bool last) {
        (void)last;
        return 0;       // TODO
    }

    // ---- transactions ----
    // START, (dev<<1)|0, data[0..n-1], STOP.
    // Return 0 if every byte was ACKed, -1 otherwise. Stop sending at the
    // first NACK, but ALWAYS finish with STOP (and wait until READY) so the
    // bus is released.
    int write_transaction(uint8_t dev, const uint8_t *data, int n) {
        (void)dev; (void)data; (void)n;
        return -1;      // TODO
    }

    // The usual "read registers" pattern:
    // START, (dev<<1)|0, wdata[0..wn-1], RESTART, (dev<<1)|1,
    // read rn bytes into rdata (the last one with last = true), STOP.
    // Return 0 on success, -1 if any written byte was NACKed (then skip the
    // reading, but still send STOP).
    int write_read(uint8_t dev, const uint8_t *wdata, int wn, uint8_t *rdata, int rn) {
        (void)dev; (void)wdata; (void)wn; (void)rdata; (void)rn;
        return -1;      // TODO
    }

private:
    // Wait until READY, then write (cmd << 8) | data to register 2.
    void command(int cmd, uint8_t data) {
        (void)cmd; (void)data;   // TODO
    }
    uint32_t base_;
};

#endif
