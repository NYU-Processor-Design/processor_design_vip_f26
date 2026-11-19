// timer_test.cpp : timer core + TimerCore driver, on the whole SoC (25 MHz).
#include "fpro/timer_core.h"
#include "test_util.h"

TimerCore timer(get_slot_addr(BRIDGE_BASE, S0_SYS_TIMER));

int main() {
    uint32_t f = 0;

    uint64_t t0 = timer.read_tick();
    spin(100);
    if (timer.read_tick() <= t0) f |= 1u << 0;    // counting from reset

    t0 = timer.read_tick();
    timer.sleep_us(200);                          // 200 us = 5000 clocks
    uint64_t dt = timer.read_tick() - t0;
    if (dt < 5000 || dt > 5600) f |= 1u << 1;

    timer.pause();                                // pause freezes the count
    uint64_t a = timer.read_tick();
    spin(100);
    uint64_t b = timer.read_tick();
    if (a != b) f |= 1u << 2;
    timer.resume();
    spin(100);
    if (timer.read_tick() <= b) f |= 1u << 3;

    timer.clear();                                // clear zeroes it, keeps running
    if (timer.read_tick() > 200) f |= 1u << 4;

    timer.clear();
    timer.sleep_us(40);
    uint64_t us = timer.read_time_us();
    if (us < 40 || us > 50) f |= 1u << 5;         // microseconds since clear

    test_phase(1);                                // testbench times this sleep
    timer.sleep_us(100);
    test_phase(2);
    test_done(f);
}
