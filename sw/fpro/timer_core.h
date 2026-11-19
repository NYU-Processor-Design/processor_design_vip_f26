// ============================================================================
// timer_core.h : C++ driver for the system timer (slot 0)        [ASSIGNMENT]
//
// HOW EVERY DRIVER WORKS: see gpio_core.h and the finished scratch_core.h.
//   io_read(base_, REG) / io_write(base_, REG, value) access register REG.
//
// THE HARDWARE (registers of fpro/fpro_timer.sv)
//   offset 0  R  counter bits [31:0]
//   offset 1  R  counter bits [47:32] (in bits 15:0)
//   offset 2  W  bit 0 = go (1 = count, 0 = pause), bit 1 = clear (one-shot)
//   The counter adds 1 every clock: SYS_CLK_FREQ (fpro_map.h, in MHz) ticks
//   = 1 microsecond.
//
// WHAT TO WRITE: the methods below. Test with
//   sw/run_soc_test.sh timer    (program: sw/tests/timer_test.cpp)
//
// EXAMPLE
//   TimerCore t(get_slot_addr(BRIDGE_BASE, S0_SYS_TIMER));
//   uint64_t t0 = t.read_tick();  t.sleep_us(500);  // ~12500 ticks later
//
// WATCH OUT: the 48-bit value is read in two halves. If the low half rolls
// over from 0xFFFFFFFF to 0 between your two reads, you get a value that is
// wrong by 2^32. Read high, low, high again and retry if the two highs differ.
// ======================== END OF SPECIFICATION ========================
#ifndef TIMER_CORE_H
#define TIMER_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class TimerCore {
public:
    enum { REG_LOW = 0, REG_HIGH = 1, REG_CTRL = 2 };
    enum { GO_MASK = 0x1, CLEAR_MASK = 0x2 };
    constexpr explicit TimerCore(uint32_t base) : base_(base) {}

    // Stop counting / continue counting.
    void pause()  { /* TODO */ }
    void resume() { /* TODO */ }

    // Set the counter to 0 AND keep it running (one write: both bits).
    void clear()  { /* TODO */ }

    // Current 48-bit tick count (see WATCH OUT above). Combine the halves as
    // ((uint64_t)hi << 32) | lo.
    uint64_t read_tick() const {
        return 0;   // TODO
    }

    // Microseconds since the last clear: ticks / SYS_CLK_FREQ.
    uint64_t read_time_us() const {
        return 0;   // TODO
    }

    // Busy-wait for `us` microseconds. Hint: compute the target tick count
    // once (now + us * SYS_CLK_FREQ, as uint64_t), then loop until
    // read_tick() reaches it. Don't divide inside the loop: it is slow on this
    // CPU (no hardware divider).
    void sleep_us(uint32_t us) const {
        (void)us;   // TODO
    }

private:
    uint32_t base_;
};

#endif
