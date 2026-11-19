// ============================================================================
// arty_top.sv : Digilent Arty A7-100T top level
//
//   100 MHz oscillator -> MMCM -> 25 MHz system clock -> fpro_soc
//
// Pin use (see arty_a7_100t.xdc):
//   GPIO : sw[3:0] + btn[3:0] in, green LEDs LD4-LD7 out
//   UART : USB-UART bridge (uart_rx A9, uart_tx D10)
//   SPI  : Pmod JA  1 = ss_n[0], 2 = MOSI, 3 = MISO, 4 = SCLK, 7 = ss_n[1]
//   I2C  : shield header SCL / SDA, with the on-board pull-ups switched on
//   PWM  : ch0-2 = RGB LED LD0 (R,G,B), ch3-5 = RGB LED LD1 (R,G,B),
//          ch6-7 = Pmod JD pins 1-2 (motor driver, servo, oscilloscope)
//
// Add fpro/ to the Vivado include path so `include "fpro_map.svh"` resolves.
// You do not need to edit this file for the peripheral assignment.
// ============================================================================
`include "fpro_map.svh"

module arty_top (
    input  logic       clk100,      // E3
    input  logic       reset_n,     // C2, red RESET button, active low
    input  logic [3:0] sw,
    input  logic [3:0] btn,
    output logic [3:0] led,
    input  logic       uart_rx,     // FPGA input  (A9)
    output logic       uart_tx,     // FPGA output (D10)
    output logic       ja_ss0_n,    // Pmod JA pin 1  SPI slave select 0
    output logic       ja_mosi,     // Pmod JA pin 2  SPI MOSI
    input  logic       ja_miso,     // Pmod JA pin 3  SPI MISO
    output logic       ja_sclk,     // Pmod JA pin 4  SPI SCLK
    output logic       ja_ss1_n,    // Pmod JA pin 7  SPI slave select 1
    inout  wire        ck_scl,
    inout  wire        ck_sda,
    output logic       scl_pup,     // 1 = enable the on-board I2C pull-up resistors
    output logic       sda_pup,
    output logic       led0_r, led0_g, led0_b,
    output logic       led1_r, led1_g, led1_b,
    output logic [1:0] jd
);
    // ---- clock: 100 MHz * 8 / 32 = 25 MHz ----
    logic clk_fb, clk_mmcm, clk_sys, locked;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .CLKFBOUT_MULT_F(8.0), .DIVCLK_DIVIDE(1),
        .CLKOUT0_DIVIDE_F(32.0)                 // 800 MHz VCO / 32 = 25 MHz
    ) mmcm (
        .CLKIN1(clk100), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_mmcm), .LOCKED(locked), .PWRDWN(1'b0), .RST(1'b0));
    BUFG bufg_sys (.I(clk_mmcm), .O(clk_sys));

    // ---- reset: held until the MMCM is locked and the button is released ----
    logic [2:0] rst_sync = 3'b111;
    always_ff @(posedge clk_sys or negedge locked)
        if (!locked) rst_sync <= 3'b111;
        else         rst_sync <= {rst_sync[1:0], ~reset_n};
    logic reset_sys;
    assign reset_sys = rst_sync[2];

    // ---- SPI on Pmod JA ----
    logic [`N_SPI_SS-1:0] spi_ss_n;
    assign ja_ss0_n = spi_ss_n[0];
    assign ja_ss1_n = spi_ss_n[1];

    // ---- I2C: open-drain pins ----
    logic scl_o, sda_o;
    assign ck_scl  = scl_o ? 1'bz : 1'b0;      // never drive a 1: release, the pull-up does it
    assign ck_sda  = sda_o ? 1'bz : 1'b0;
    assign scl_pup = 1'b1;
    assign sda_pup = 1'b1;

    // ---- PWM ----
    logic [`N_PWM-1:0] pwm;
    assign {led0_b, led0_g, led0_r} = pwm[2:0];
    assign {led1_b, led1_g, led1_r} = pwm[5:3];
    assign jd = pwm[7:6];

    // ---- the microcontroller ----
    fpro_soc #(
        .N_SLOTS(16), .CLK_HZ(`SYS_CLK_FREQ * 1_000_000),
        .IMEM_INIT("instr.mem"), .DMEM_INIT("data.mem")
    ) soc (
        .clk(clk_sys), .reset(reset_sys),
        .sw(sw), .btn(btn), .led(led),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .spi_sclk(ja_sclk), .spi_mosi(ja_mosi), .spi_miso(ja_miso), .spi_ss_n(spi_ss_n),
        .i2c_scl_o(scl_o), .i2c_sda_o(sda_o), .i2c_scl_i(ck_scl), .i2c_sda_i(ck_sda),
        .pwm(pwm));
endmodule
