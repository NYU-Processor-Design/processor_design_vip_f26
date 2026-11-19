// ============================================================================
// pwm_core.h : C++ driver for the PWM core (slot 5)              [ASSIGNMENT]
//
// HOW EVERY DRIVER WORKS: see gpio_core.h and the finished scratch_core.h.
//   io_read(base_, REG) / io_write(base_, REG, value) access register REG.
//
// THE HARDWARE (registers of fpro/fpro_pwm.sv)
//   offset 0       W/R  dvsr:  f_pwm = f_clk / (256 * (dvsr + 1))
//   offset 16 + n  W/R  duty of channel n: 0 (always off) .. 256 (always on)
//   Channels: 0-2 = RGB LED LD0 (R,G,B), 3-5 = RGB LED LD1, 6-7 = Pmod JD 1-2
//
// WHAT TO WRITE: the methods below. Test with
//   sw/run_soc_test.sh pwm      (program: sw/tests/pwm_test.cpp)
//
// EXAMPLE: a dim orange on LD0 at 1 kHz
//   PwmCore pwm(get_slot_addr(BRIDGE_BASE, S5_PWM));
//   pwm.set_freq(1000);
//   pwm.set_duty(0, 20);     // red   20 %
//   pwm.set_duty(1, 5);      // green  5 %
//   pwm.set_duty(2, 0);      // blue  off
// (The Arty's RGB LEDs are very bright: low duty cycles look best.)
// ======================== END OF SPECIFICATION ========================
#ifndef PWM_CORE_H
#define PWM_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class PwmCore {
public:
    enum { REG_DVSR = 0, REG_DUTY_BASE = 16 };
    enum { RESOLUTION = 256 };          // steps per period
    constexpr explicit PwmCore(uint32_t base) : base_(base) {}

    // PWM frequency for all channels:
    //   dvsr = round(f_clk / (256 * hz)) - 1,  f_clk = SYS_CLK_FREQ * 1000000
    //   (10 kHz -> 9, 1 kHz -> 97). Use integer math: round(a / b) = (a + b/2) / b
    void set_freq(uint32_t hz) {
        (void)hz;   // TODO
    }

    // Raw duty 0..256 for one channel. Values above 256 are clamped to 256.
    void set_duty_raw(int channel, uint32_t value) {
        (void)channel; (void)value;   // TODO
    }

    // Duty in percent. Clamp to 0..100 first, then convert with rounding:
    //   raw = round(percent * 256 / 100)      (25 % -> 64, 100 % -> 256)
    void set_duty(int channel, int percent) {
        (void)channel; (void)percent; // TODO
    }

    // Read back the duty register of a channel.
    uint32_t duty_raw(int channel) const {
        (void)channel;
        return 0;   // TODO
    }

private:
    uint32_t base_;
};

#endif
