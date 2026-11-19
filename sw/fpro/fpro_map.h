// fpro_map.h : slot assignment as seen by software.
// MUST match fpro/fpro_map.svh (same names, same numbers).
#ifndef FPRO_MAP_H
#define FPRO_MAP_H

#define SYS_CLK_FREQ   25               // MHz; the clock the SoC actually runs at
#define BRIDGE_BASE    0xC0000000u      // start of the FPro I/O window

#define S0_SYS_TIMER   0
#define S1_UART        1
#define S2_GPIO        2
#define S3_SPI         3
#define S4_I2C         4
#define S5_PWM         5
#define S6_SCRATCH     6

#endif
