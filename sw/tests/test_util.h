// test_util.h : how the SoC test programs talk to the testbench.
//
// The verdict does NOT go through your UART (it may not work yet): it is
// written to the finished scratch core, which tb/tb_soc.sv watches.
//   scratch register 3 : verdict   1 = PASS, anything else = FAIL code
//   scratch register 2 : phase     tells the testbench "I reached step n"
#ifndef TEST_UTIL_H
#define TEST_UTIL_H

#include <stdint.h>
#include "fpro/fpro_map.h"
#include "fpro/fpro_io.h"

static inline uint32_t scratch_base() { return get_slot_addr(BRIDGE_BASE, S6_SCRATCH); }

static inline void test_phase(uint32_t n) { io_write(scratch_base(), 2, n); }

// report and stop. `fails` has one bit per failed check (0 = all passed)
static inline void test_done(uint32_t fails) {
    io_write(scratch_base(), 3, fails == 0 ? 1u : (0x80000000u | fails));   // bit 31 = failed
    for (;;) { }
}

// busy-wait for about n loop iterations (does not need the timer)
static inline void spin(uint32_t n) { for (volatile uint32_t i = 0; i < n; i++) { } }

#endif
