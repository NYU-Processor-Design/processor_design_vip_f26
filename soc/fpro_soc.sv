// ============================================================================
// fpro_soc.sv : the complete microcontroller (everything except clock / pins)
//
//   risc_v core --io_* port--> fpro_bridge --FPro bus--> fpro_mmio_sys (slots)
//
// You do not need to edit this file for the peripheral assignment.
// ============================================================================
`include "fpro_map.svh"

module fpro_soc #(
    parameter int    N_SLOTS    = 16,
    parameter int    CLK_HZ     = `SYS_CLK_FREQ * 1_000_000,
    parameter int    IMEM_WORDS = 8192,       // 32 KB
    parameter int    DMEM_WORDS = 4096,       // 16 KB (must match sw/link.ld)
    parameter string IMEM_INIT  = "instr.mem",
    parameter string DMEM_INIT  = "data.mem"
)(
    input  logic                    clk,
    input  logic                    reset,    // synchronous, active high
    // board I/O
    input  logic [`N_SW-1:0]        sw,
    input  logic [`N_BTN-1:0]       btn,
    output logic [`N_LED-1:0]       led,
    input  logic                    uart_rx,
    output logic                    uart_tx,
    output logic                    spi_sclk,
    output logic                    spi_mosi,
    input  logic                    spi_miso,
    output logic [`N_SPI_SS-1:0]    spi_ss_n,
    output logic                    i2c_scl_o,
    output logic                    i2c_sda_o,
    input  logic                    i2c_scl_i,
    input  logic                    i2c_sda_i,
    output logic [`N_PWM-1:0]       pwm
);
    // ---- core ----
    logic [31:0] io_addr, io_wdata, io_rdata;
    logic        io_we, io_re;

    top #(
        .IMEM_WORDS(IMEM_WORDS), .DMEM_WORDS(DMEM_WORDS),
        .IMEM_INIT(IMEM_INIT),   .DMEM_INIT(DMEM_INIT),
        .IO_BASE(`BRIDGE_BASE)
    ) cpu (
        .clk(clk), .reset(reset),
        .io_addr(io_addr), .io_wdata(io_wdata),
        .io_we(io_we), .io_re(io_re), .io_rdata(io_rdata));

    // ---- FPro bridge ----
    logic        fp_mmio_cs, fp_video_cs, fp_wr, fp_rd;
    logic [20:0] fp_addr;
    logic [31:0] fp_wr_data, fp_rd_data, mmio_rd_data;

    fpro_bridge #(.BASE(`BRIDGE_BASE)) bridge (
        .io_addr(io_addr), .io_wdata(io_wdata), .io_we(io_we), .io_re(io_re),
        .io_rdata(io_rdata),
        .fp_mmio_cs(fp_mmio_cs), .fp_video_cs(fp_video_cs),
        .fp_wr(fp_wr), .fp_rd(fp_rd), .fp_addr(fp_addr),
        .fp_wr_data(fp_wr_data), .fp_rd_data(fp_rd_data));

    assign fp_rd_data = fp_video_cs ? 32'd0 : mmio_rd_data;   // no video subsystem

    // ---- MMIO subsystem ----
    fpro_mmio_sys #(.N_SLOTS(N_SLOTS), .CLK_HZ(CLK_HZ)) mmio (
        .clk(clk), .reset(reset),
        .mmio_cs(fp_mmio_cs), .mmio_wr(fp_wr), .mmio_rd(fp_rd),
        .mmio_addr(fp_addr), .mmio_wr_data(fp_wr_data),
        .mmio_rd_data(mmio_rd_data),
        .gpio_in({btn, sw}), .gpio_out(led),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_ss_n(spi_ss_n),
        .i2c_scl_o(i2c_scl_o), .i2c_sda_o(i2c_sda_o),
        .i2c_scl_i(i2c_scl_i), .i2c_sda_i(i2c_sda_i),
        .pwm(pwm));
endmodule
