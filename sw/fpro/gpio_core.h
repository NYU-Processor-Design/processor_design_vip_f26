// ============================================================================
// gpio_core.h : C++ driver for the GPIO core (slot 2)            [ASSIGNMENT]
//
// HOW EVERY DRIVER WORKS (see the finished example scratch_core.h)
//   * The object only stores the slot's base address (constexpr constructor,
//     so global objects need no startup code).
//   * Register r of the core is the 32-bit word at  base + 4*r. Use the two
//     helpers from fpro_io.h, never raw pointers:
//         io_read(base_, REG)            read a register
//         io_write(base_, REG, value)    write a register
//   * Bit helpers (fpro_io.h): bit_set(x, n), bit_clear(x, n), bit_read(x, n),
//     bit_write(x, n, v)  -- these modify / read the variable x.
//
// THE HARDWARE (registers of fpro/fpro_gpio.sv)
//   offset 0  DATA_OUT  W/R  bits [3:0] = LEDs
//   offset 1  DATA_IN   R    bits [3:0] = switches, bits [7:4] = buttons BTN0-3
//   offset 2  EDGE      R    bit i = input i went 0->1 since last cleared
//                       W    write 1s to clear those bits
//
// WHAT TO WRITE: the methods below. Each has its job and a hint; the bodies
// return dummy values so the project compiles. Test with
//   sw/run_soc_test.sh gpio     (program: sw/tests/gpio_test.cpp)
//
// EXAMPLE (what a user program can do with your driver)
//   GpioCore gpio(get_slot_addr(BRIDGE_BASE, S2_GPIO));
//   gpio.write(gpio.switches());           // LEDs follow the switches
//   if (gpio.pressed(0)) gpio.write(3, 1); // BTN0 pressed -> turn on LED 3
// ======================== END OF SPECIFICATION ========================
#ifndef GPIO_CORE_H
#define GPIO_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class GpioCore {
public:
    enum { REG_OUT = 0, REG_IN = 1, REG_EDGE = 2 };
    constexpr explicit GpioCore(uint32_t base) : base_(base), out_(0) {}

    // Set all output pins (LEDs) at once. Remember the value in out_, so that
    // write(bit, value) below can change one bit without touching the others.
    void write(uint32_t data) {
        out_ = data;
        io_write(base_, REG_OUT, out_);
    }

    // Set ONE output pin to 0 or 1 and leave the others unchanged.
    // Hint: update out_ with bit_write(out_, bit_pos, value), then write it out.
    void write(int bit_pos, int value) {
        bit_write(out_, bit_pos, value);
	io_write(base_, REG_OUT, out_);
    }

    // Read back the output register from the hardware (offset 0).
    uint32_t read_out() const {
        return io_read(base_, REG_OUT);
    }

    // Read all input pins (offset 1).
    uint32_t read() const {
        return io_read(base_, REG_IN);
    }

    // Read one input pin: 0 or 1. Hint: bit_read(read(), bit_pos)
    int read(int bit_pos) const {
        return bit_read(read(), bit_pos);
    }

    // The 4 switches (input bits 3:0) and the 4 buttons (input bits 7:4),
    // each returned in bits 3:0.
    uint32_t switches() const {
	return read() & 0xF;
    }
    uint32_t buttons() const  {
	return (read() >> 4) & 0xF;
    }

    // Read the EDGE register (offset 2), and clear the bits that are 1 in mask.
    uint32_t edges() const {
	return io_read(base_, REG_EDGE);
    }
    void clear_edges(uint32_t mask) {
        io_write(base_, REG_EDGE, mask);
    }

    // Has button `btn` (0..3) been pressed since the last call?
    // If its EDGE bit (bit 4 + btn) is set: clear that bit only and return true.
    // Otherwise return false. Each press is reported exactly once.
    bool pressed(int btn) {
        uint32_t mask = 1u << (4 + btn);

	if (edges() & mask) {
		clear_edges(mask);
		return true;
	}
        return false;
    }

private:
    uint32_t base_;
    uint32_t out_;          // copy of what was last written to the outputs
};

#endif
