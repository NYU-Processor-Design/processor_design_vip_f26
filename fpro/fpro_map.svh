// ============================================================================
// fpro_map.svh : the ONE place where the hardware slot assignment lives.
// Keep sw/fpro/fpro_map.h in sync with this file (same names, same numbers).
// ============================================================================
`ifndef FPRO_MAP_SVH
`define FPRO_MAP_SVH

// system clock in MHz (the clock the SoC actually runs at)
`define SYS_CLK_FREQ   25

// base address of the FPro I/O window as seen by the processor
`define BRIDGE_BASE    32'hC000_0000

// ---- slot assignment (slot n owns word offsets n*32 .. n*32+31) ----
`define S0_SYS_TIMER   0
`define S1_UART        1
`define S2_GPIO        2
`define S3_SPI         3
`define S4_I2C         4
`define S5_PWM         5
`define S6_SCRATCH     6

// bit n set = slot n has a core attached (other slots read back FPRO_UNUSED_RD)
`define FPRO_USED_SLOTS ( (64'd1 << `S0_SYS_TIMER) | (64'd1 << `S1_UART) | \
                          (64'd1 << `S2_GPIO)      | (64'd1 << `S3_SPI)  | \
                          (64'd1 << `S4_I2C)       | (64'd1 << `S5_PWM)  | \
                          (64'd1 << `S6_SCRATCH) )

// value returned when software reads a slot with nothing attached
`define FPRO_UNUSED_RD 32'hFFFF_FFFF

// ---- board I/O widths ----
`define N_SW           4      // slide switches
`define N_BTN          4      // push buttons
`define N_LED          4      // green LEDs
`define N_SPI_SS       2      // SPI slave-select lines
`define N_PWM          8      // PWM channels

`endif
