`timescale 1ns/1ps
// tb_spi.sv : unit test for fpro/fpro_spi.sv (see the register map there)
// Four slave models, one per SPI mode; slave k is on ss_n[k] and uses mode k.
`define TEST_NAME "spi"
module tb_spi;
    `include "unit/slot_tb.svh"

    logic       sclk, mosi, miso;
    logic [3:0] ss_n;
    logic [3:0] s_miso;
    fpro_spi #(.N_SS(4)) dut (
        .clk(clk), .reset(reset), .cs(cs), .read(read), .write(write),
        .addr(addr), .wr_data(wr_data), .rd_data(rd_data),
        .spi_sclk(sclk), .spi_mosi(mosi), .spi_miso(miso), .spi_ss_n(ss_n));

    spi_slave_model #(.CPOL(0), .CPHA(0), .RESP(64'h1122_3300_0000_0000)) s0 (.ss_n(ss_n[0]), .sclk(sclk), .mosi(mosi), .miso(s_miso[0]));
    spi_slave_model #(.CPOL(0), .CPHA(1), .RESP(64'h4455_6600_0000_0000)) s1 (.ss_n(ss_n[1]), .sclk(sclk), .mosi(mosi), .miso(s_miso[1]));
    spi_slave_model #(.CPOL(1), .CPHA(0), .RESP(64'h7788_9900_0000_0000)) s2 (.ss_n(ss_n[2]), .sclk(sclk), .mosi(mosi), .miso(s_miso[2]));
    spi_slave_model #(.CPOL(1), .CPHA(1), .RESP(64'hAABB_CC00_0000_0000)) s3 (.ss_n(ss_n[3]), .sclk(sclk), .mosi(mosi), .miso(s_miso[3]));
    assign miso = !ss_n[0] ? s_miso[0] : !ss_n[1] ? s_miso[1] :
                  !ss_n[2] ? s_miso[2] : !ss_n[3] ? s_miso[3] : 1'b1;

    // SCLK edge timing monitor: inside a byte, consecutive SCLK edges must be
    // exactly (dvsr+1) clocks apart. The first edge of each byte is skipped
    // (it follows the idle gap between bytes).
    realtime last_edge = 0;
    int      bad_half = 0, n_half = 0, exp_half_clocks = 0, edge_idx = 0;
    int      sel_edges = 0;                 // SCLK edges while some slave is selected
    always @(ss_n) edge_idx = 0;
    always @(sclk) begin
        if (exp_half_clocks != 0 && ss_n != 4'hF) begin
            if (edge_idx % 16 != 0) begin
                n_half++;
                if ($realtime - last_edge != exp_half_clocks * CLK_NS) bad_half++;
            end
            edge_idx++;
        end
        if (ss_n != 4'hF) sel_edges++;
        last_edge = $realtime;
    end

    logic [31:0] d;
    logic [7:0]  got;
    task automatic xfer(input logic [7:0] out, output logic [7:0] in);
        logic [31:0] st;
        bus_write(2, 32'(out));
        bus_read(0, st);
        check(st[8] == 1'b0, "READY = 0 while a transfer is running");
        do bus_read(0, st); while (!st[8]);
        in = st[7:0];
    endtask

    initial begin
        do_reset();
        $display("-- reset values");
        bus_read(0, d); check_eq(d & 32'h100, 32'h100, "READY = 1 after reset");
        bus_read(1, d); check_eq(d, 32'hF, "all slave selects high (inactive) after reset");
        bus_read(3, d); check_eq(d, 12, "CTRL after reset: dvsr = 12, CPOL = CPHA = 0");
        check(sclk === 1'b0 && ss_n === 4'hF, "pins after reset: SCLK = 0, ss_n = all 1");

        for (int m = 0; m < 4; m++) begin
            logic [7:0] exp0, exp1;
            $display("-- mode %0d (CPOL=%0d CPHA=%0d)", m, m >> 1, m & 1);
            bus_write(3, {14'd0, 1'(m & 1), 1'(m >> 1), 16'd3});
            bus_read(3, d); check_eq(d, {14'd0, 1'(m & 1), 1'(m >> 1), 16'd3}, "CTRL read-back");
            wait_clocks(2);
            check(sclk === 1'(m >> 1), "SCLK idles at CPOL");
            bus_write(1, 32'hF & ~(32'd1 << m));
            bus_read(1, d); check_eq(d, 32'hF & ~(32'd1 << m), "ss register read-back");
            check(ss_n === 4'(32'hF & ~(32'd1 << m)), "ss_n pins follow the register");
            exp_half_clocks = 4; n_half = 0; bad_half = 0; sel_edges = 0;
            xfer(8'h5A + 8'(m), got);
            exp0 = (m == 0) ? 8'h11 : (m == 1) ? 8'h44 : (m == 2) ? 8'h77 : 8'hAA;
            check_eq(32'(got), 32'(exp0), "1st byte received from the slave");
            bus_write(2, 32'hEE);                    // starts byte 2
            bus_write(2, 32'hFF);                    // busy: must be ignored
            do bus_read(0, d); while (!d[8]);
            exp1 = (m == 0) ? 8'h22 : (m == 1) ? 8'h55 : (m == 2) ? 8'h88 : 8'hBB;
            check_eq(d & 32'hFF, 32'(exp1), "2nd byte received from the slave");
            wait_clocks(2);
            check(sclk === 1'(m >> 1), "SCLK back at CPOL after the transfer");
            exp_half_clocks = 0;
            check(sel_edges == 32, $sformatf("16 SCLK edges per byte (saw %0d for 2 bytes)", sel_edges));
            bus_write(1, 32'hF);
            check(bad_half == 0, $sformatf("every SCLK half period = dvsr+1 = 4 clocks (%0d wrong of %0d)", bad_half, n_half));
        end
        wait_clocks(5);
        check(s0.n_rx == 2 && s0.rx[0] == 8'h5A && s0.rx[1] == 8'hEE, "mode-0 slave received 5A EE (and not the ignored FF)");
        check(s1.n_rx == 2 && s1.rx[0] == 8'h5B && s1.rx[1] == 8'hEE, "mode-1 slave received 5B EE");
        check(s2.n_rx == 2 && s2.rx[0] == 8'h5C && s2.rx[1] == 8'hEE, "mode-2 slave received 5C EE");
        check(s3.n_rx == 2 && s3.rx[0] == 8'h5D && s3.rx[1] == 8'hEE, "mode-3 slave received 5D EE");

        $display("-- divisor");
        bus_write(3, 32'd9);
        bus_write(1, 32'hE);
        exp_half_clocks = 10; n_half = 0; bad_half = 0;
        xfer(8'h00, got);
        exp_half_clocks = 0;
        bus_write(1, 32'hF);
        check(bad_half == 0 && n_half >= 15, "dvsr = 9 gives 10-clock half periods");
        bus_read(6, d); check_eq(d, 0, "unused offset reads 0");
        finish_test();
    end
    initial begin #5_000_000; $display("UNIT TEST spi: TIMEOUT"); $finish; end
endmodule
