// board_demo.cpp : everything together on the Arty A7 (run it once all six
// peripherals pass their tests).
//
// Build:  sw/build.sh sw/fpro/fpro_init.cpp sw/demo/board_demo.cpp
//         then rebuild the bitstream in Vivado with the new build/instr.mem
//         and build/data.mem (or use "Update memory" if you know how).
// Terminal: 9600 baud, 8N1 (the board's USB serial port).
//
// What you should see:
//   * a banner and an I2C bus scan ("i2c: device at 0x.." for each device
//     plugged into the shield header; nothing if none)
//   * green LEDs follow the switches
//   * RGB LED LD0 slowly cycles red -> green -> blue (PWM), LD1 "breathes"
//   * BTN0..BTN3 print "button n" once per press (GPIO edge capture)
//   * "up n s" every second (timer)
//   * every key you type is echoed back with its hex code (UART receive)
//   * an SPI byte is sent on Pmod JA every second (look at it with a scope)
#include "fpro/fpro_cores.h"

GpioCore gpio(get_slot_addr(BRIDGE_BASE, S2_GPIO));
SpiCore  spi(get_slot_addr(BRIDGE_BASE, S3_SPI));
I2cCore  i2c(get_slot_addr(BRIDGE_BASE, S4_I2C));
PwmCore  pwm(get_slot_addr(BRIDGE_BASE, S5_PWM));

static void i2c_scan() {
    for (uint8_t a = 0x08; a < 0x78; a++) {
        if (i2c.write_transaction(a, nullptr, 0) == 0) {
            uart.disp("i2c: device at 0x");
            uart.disp(a, 16, 2);
            uart.disp('\n');
        }
    }
}

int main() {
    uart.set_baud_rate(9600);
    uart.disp("\nArty A7 RISC-V microcontroller: peripheral demo\n");
    i2c.set_freq(100000);
    i2c_scan();
    spi.set_freq(1000000);
    spi.set_mode(0, 0);
    pwm.set_freq(1000);

    unsigned long last_sec = now_ms(), last_fade = now_ms(), seconds = 0;
    int step = 0;
    for (;;) {
        gpio.write(gpio.switches());                     // switches -> LEDs

        for (int b = 0; b < 4; b++)
            if (gpio.pressed(b)) { uart.disp("button "); uart.disp(b); uart.disp('\n'); }

        if (now_ms() - last_fade >= 10) {                // PWM animation, 100 steps / s
            last_fade += 10;
            step = (step + 1) % 300;
            int phase = step % 100, color = step / 100;
            for (int c = 0; c < 3; c++)                  // LD0: one colour at a time, 0..20 %
                pwm.set_duty(c, c == color ? (phase < 50 ? phase : 100 - phase) * 2 / 5 : 0);
            int breath = (step % 200 < 100) ? step % 100 : 100 - step % 100;
            pwm.set_duty(3, breath / 5); pwm.set_duty(4, breath / 5); pwm.set_duty(5, breath / 5);
            pwm.set_duty(6, 50); pwm.set_duty(7, 25);    // Pmod JD: fixed 50 % / 25 %
        }

        if (now_ms() - last_sec >= 1000) {               // once a second
            last_sec += 1000;
            seconds++;
            uart.disp("up "); uart.disp((int)seconds); uart.disp(" s\n");
            spi.select(0); spi.transfer(0xA5); spi.deselect(0);
        }

        int c = uart.rx_byte();                          // echo
        if (c >= 0) {
            uart.disp("rx '"); uart.disp((char)((c >= 32 && c < 127) ? c : '.'));
            uart.disp("' (0x"); uart.disp(c, 16, 2); uart.disp(")\n");
        }
    }
}
