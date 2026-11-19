// pwm_test.cpp : PWM core + PwmCore driver, on the whole SoC.
// At phase 1 the testbench measures every channel's duty cycle on the pins.
#include "fpro/pwm_core.h"
#include "test_util.h"

PwmCore pwm(get_slot_addr(BRIDGE_BASE, S5_PWM));

int main() {
    uint32_t f = 0;
    pwm.set_freq(10000);                          // 10 kHz -> dvsr = 9
    if (io_read(get_slot_addr(BRIDGE_BASE, S5_PWM), 0) != 9) f |= 1u << 0;

    pwm.set_duty_raw(0, 0);
    pwm.set_duty_raw(1, 1);
    pwm.set_duty_raw(2, 64);
    pwm.set_duty_raw(3, 128);
    pwm.set_duty_raw(4, 255);
    pwm.set_duty_raw(5, 256);
    pwm.set_duty(6, 100);                         // 100 % -> 256
    pwm.set_duty(7, 25);                          // 25 %  -> 64

    if (pwm.duty_raw(6) != 256) f |= 1u << 1;
    if (pwm.duty_raw(7) != 64)  f |= 1u << 2;
    pwm.set_duty_raw(0, 1000);                    // too big: the driver clamps to 256
    if (pwm.duty_raw(0) != 256) f |= 1u << 3;
    pwm.set_duty(0, -5);                          // negative percent clamps to 0
    if (pwm.duty_raw(0) != 0)   f |= 1u << 4;

    test_phase(1);                                // testbench measures the pins
    test_done(f);
}
