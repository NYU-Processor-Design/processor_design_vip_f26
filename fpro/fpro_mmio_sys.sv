// ============================================================================
// fpro_mmio_sys.sv : the MMIO subsystem = slot controller + one core per slot
//
// YOUR JOB IN THIS FILE: in each section marked TODO below, instantiate your
// core and delete the placeholder lines. Every core is connected the same way
// (see the finished scratch core in slot 6 at the bottom of this file):
//
//     fpro_xxx #(...) xxx_slotN (
//         .clk(clk), .reset(reset),
//         .cs(slot_cs[`Sn_NAME]), .read(mmio_rd), .write(mmio_wr),
//         .addr(slot_addr), .wr_data(mmio_wr_data),
//         .rd_data(slot_rd[`Sn_NAME]),
//         ... the core's external pins ...
//     );
//
// Everything outside the TODO sections is finished: leave it as it is.
// The slot numbers (`S0_SYS_TIMER ...) come from fpro_map.svh.
// ============================================================================
`include "fpro_map.svh"

module fpro_mmio_sys #(
    parameter int N_SLOTS = 16,                       // 1..64, must exceed the highest slot used
    parameter int CLK_HZ  = `SYS_CLK_FREQ * 1_000_000
)(
    input  logic                       clk,
    input  logic                       reset,
    // FPro bus (from fpro_bridge)
    input  logic                       mmio_cs,
    input  logic                       mmio_wr,
    input  logic                       mmio_rd,
    input  logic [20:0]                mmio_addr,
    input  logic [31:0]                mmio_wr_data,
    output logic [31:0]                mmio_rd_data,
    // GPIO pins: gpio_in = {buttons, switches}, gpio_out = green LEDs
    input  logic [`N_BTN+`N_SW-1:0]    gpio_in,
    output logic [`N_LED-1:0]          gpio_out,
    // UART pins
    input  logic                       uart_rx,
    output logic                       uart_tx,
    // SPI pins
    output logic                       spi_sclk,
    output logic                       spi_mosi,
    input  logic                       spi_miso,
    output logic [`N_SPI_SS-1:0]       spi_ss_n,
    // I2C pins (open drain: *_o = 0 pulls the line low, *_i = actual line level)
    output logic                       i2c_scl_o,
    output logic                       i2c_sda_o,
    input  logic                       i2c_scl_i,
    input  logic                       i2c_sda_i,
    // PWM outputs
    output logic [`N_PWM-1:0]          pwm
);
    // ---- slot plumbing ----
    logic [N_SLOTS-1:0]       slot_cs;
    logic [4:0]               slot_addr;
    logic [N_SLOTS-1:0][31:0] slot_rd;   // slot n drives slot_rd[n]

    localparam logic [63:0] USED_SLOTS = `FPRO_USED_SLOTS;

    // slots with no core attached are never read; tie their read data off
    for (genvar n = 0; n < N_SLOTS; n++) begin : g_unused
        if (!USED_SLOTS[n]) begin : g_tie
            assign slot_rd[n] = '0;
        end
    end

    fpro_mmio_ctrl #(
        .N_SLOTS(N_SLOTS), .USED(USED_SLOTS), .UNUSED_RD(`FPRO_UNUSED_RD)
    ) ctrl (
        .mmio_cs(mmio_cs), .mmio_addr(mmio_addr),
        .slot_cs(slot_cs), .slot_addr(slot_addr),
        .slot_rd_data(slot_rd), .mmio_rd_data(mmio_rd_data));

    // >>> SLOT 0 TIMER
    // TODO (fpro_timer): instantiate your fpro_timer here. Connect the slot interface
    //   exactly like scratch_slot6 at the bottom of this file, using slot
    //   number `S0_SYS_TIMER for cs and rd_data. Suggested instance name: timer_slot0
    //   parameters : none
    //   pins       : none
    // Then DELETE the placeholder lines below (they only keep the design
    // compiling while the core is missing).
    assign slot_rd[`S0_SYS_TIMER] = `FPRO_UNUSED_RD;   // placeholder
    // <<< SLOT 0 TIMER

    // >>> SLOT 1 UART
    // TODO (fpro_uart): instantiate your fpro_uart here. Connect the slot interface
    //   exactly like scratch_slot6 at the bottom of this file, using slot
    //   number `S1_UART for cs and rd_data. Suggested instance name: uart_slot1
    //   parameters : .CLK_HZ(CLK_HZ), .BAUD(9600)
    //   pins       :
    //       .rx         -> uart_rx
    //       .tx         -> uart_tx
    // Then DELETE the placeholder lines below (they only keep the design
    // compiling while the core is missing).
    assign slot_rd[`S1_UART] = `FPRO_UNUSED_RD;   // placeholder
    assign uart_tx = 1'b1;                    // placeholder
    // <<< SLOT 1 UART

    // >>> SLOT 2 GPIO
    fpro_gpio #(
        .N_IN(`N_BTN+`N_SW),
        .N_OUT(`N_LED)
    ) gpio_slot2 (
        .clk(clk),
        .reset(reset),
        .cs(slot_cs[`S2_GPIO]),
        .read(mmio_rd),
        .write(mmio_wr),
        .addr(slot_addr),
        .wr_data(mmio_wr_data),
        .rd_data(slot_rd[`S2_GPIO]),
        .din(gpio_in),
        .dout(gpio_out)
    );
    // <<< SLOT 2 GPIO

    // >>> SLOT 3 SPI
    // TODO (fpro_spi): instantiate your fpro_spi here. Connect the slot interface
    //   exactly like scratch_slot6 at the bottom of this file, using slot
    //   number `S3_SPI for cs and rd_data. Suggested instance name: spi_slot3
    //   parameters : .N_SS(`N_SPI_SS)
    //   pins       :
    //       .spi_sclk   -> spi_sclk
    //       .spi_mosi   -> spi_mosi
    //       .spi_miso   -> spi_miso
    //       .spi_ss_n   -> spi_ss_n
    // Then DELETE the placeholder lines below (they only keep the design
    // compiling while the core is missing).
    assign slot_rd[`S3_SPI] = `FPRO_UNUSED_RD;   // placeholder
    assign spi_sclk = 1'b0;                   // placeholder
    assign spi_mosi = 1'b1;                   // placeholder
    assign spi_ss_n = '1;                     // placeholder
    // <<< SLOT 3 SPI

    // >>> SLOT 4 I2C
    // TODO (fpro_i2c): instantiate your fpro_i2c here. Connect the slot interface
    //   exactly like scratch_slot6 at the bottom of this file, using slot
    //   number `S4_I2C for cs and rd_data. Suggested instance name: i2c_slot4
    //   parameters : none
    //   pins       :
    //       .i2c_scl_o  -> i2c_scl_o
    //       .i2c_sda_o  -> i2c_sda_o
    //       .i2c_scl_i  -> i2c_scl_i
    //       .i2c_sda_i  -> i2c_sda_i
    // Then DELETE the placeholder lines below (they only keep the design
    // compiling while the core is missing).
    assign slot_rd[`S4_I2C] = `FPRO_UNUSED_RD;   // placeholder
    assign i2c_scl_o = 1'b1;                  // placeholder
    assign i2c_sda_o = 1'b1;                  // placeholder
    // <<< SLOT 4 I2C

    // >>> SLOT 5 PWM
    // TODO (fpro_pwm): instantiate your fpro_pwm here. Connect the slot interface
    //   exactly like scratch_slot6 at the bottom of this file, using slot
    //   number `S5_PWM for cs and rd_data. Suggested instance name: pwm_slot5
    //   parameters : .N(`N_PWM), .CLK_HZ(CLK_HZ)
    //   pins       :
    //       .pwm        -> pwm
    // Then DELETE the placeholder lines below (they only keep the design
    // compiling while the core is missing).
    assign slot_rd[`S5_PWM] = `FPRO_UNUSED_RD;   // placeholder
    assign pwm = '0;                          // placeholder
    // <<< SLOT 5 PWM

    // ---- slot 6 : scratch registers (finished worked example; do not change) ----
    fpro_scratch scratch_slot6 (
        .clk(clk), .reset(reset),
        .cs(slot_cs[`S6_SCRATCH]), .read(mmio_rd), .write(mmio_wr),
        .addr(slot_addr), .wr_data(mmio_wr_data),
        .rd_data(slot_rd[`S6_SCRATCH]));
endmodule
