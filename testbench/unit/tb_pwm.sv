`timescale 1ns/1ps
// tb_pwm.sv : unit test for fpro/fpro_pwm.sv (see the register map there)
`define TEST_NAME "pwm"
module tb_pwm;
    `include "unit/slot_tb.svh"

    logic [7:0] pwm;
    fpro_pwm #(.N(8), .CLK_HZ(25_000_000)) dut (
        .clk(clk), .reset(reset), .cs(cs), .read(read), .write(write),
        .addr(addr), .wr_data(wr_data), .rd_data(rd_data), .pwm(pwm));

    // count, for each channel, the clocks its output is high during `n` clocks
    int high [8];
    task automatic measure(input int n);
        for (int c = 0; c < 8; c++) high[c] = 0;
        repeat (n) begin
            @(posedge clk);
            for (int c = 0; c < 8; c++) if (pwm[c]) high[c]++;
        end
    endtask

    localparam int DUTY [8] = '{0, 1, 64, 128, 255, 256, 300, 200};
    logic [31:0] d;
    realtime t_rise;
    int period, hi_now, hi_next;
    initial begin
        do_reset();
        $display("-- reset values");
        bus_read(0, d); check_eq(d, 97, "divisor after reset = round(25e6/(256*1000))-1 (~1 kHz)");
        for (int c = 0; c < 8; c++) begin
            bus_read(5'(16 + c), d); check_eq(d, 0, $sformatf("duty[%0d] after reset", c));
        end
        measure(100);
        check(pwm === 8'h00, "all outputs low after reset");

        $display("-- registers");
        bus_write(0, 1);                                    // 2 clocks per step: period = 512 clocks
        bus_read(0, d); check_eq(d, 1, "divisor read-back");
        for (int c = 0; c < 8; c++) bus_write(5'(16 + c), DUTY[c]);
        for (int c = 0; c < 8; c++) begin
            bus_read(5'(16 + c), d); check_eq(d, DUTY[c], $sformatf("duty[%0d] read-back", c));
        end
        bus_read(5, d);  check_eq(d, 0, "unused offset 5 reads 0");
        bus_read(31, d); check_eq(d, 0, "unused offset 31 reads 0");

        $display("-- duty cycles (period = 256 * (dvsr+1) = 512 clocks)");
        wait_clocks(2 * 512);
        measure(2 * 512);
        for (int c = 0; c < 8; c++) begin
            int exp_h = (DUTY[c] > 256 ? 256 : DUTY[c]) * 2 * 2;
            check(high[c] == exp_h, $sformatf("channel %0d, duty %0d: high %0d of 1024 clocks, expected %0d", c, DUTY[c], high[c], exp_h));
        end

        $display("-- glitch-free update: a new duty starts at the next period");
        @(posedge pwm[2]); t_rise = $realtime;              // start of a period (duty 64)
        wait_clocks(10);
        bus_write(18, 200);                                 // change channel 2 mid-pulse
        @(negedge pwm[2]); hi_now = int'(($realtime - t_rise) / CLK_NS);
        check(hi_now == 64 * 2, $sformatf("current period keeps the old duty (high %0d clocks, expected 128)", hi_now));
        @(posedge pwm[2]); period = int'(($realtime - t_rise) / CLK_NS); t_rise = $realtime;
        check(period == 512, $sformatf("period = 512 clocks (got %0d)", period));
        @(negedge pwm[2]); hi_next = int'(($realtime - t_rise) / CLK_NS);
        check(hi_next == 200 * 2, $sformatf("next period uses the new duty (high %0d clocks, expected 400)", hi_next));

        $display("-- divisor change");
        bus_write(0, 3);                                    // 4 clocks per step: period = 1024
        wait_clocks(2 * 1024);
        measure(2 * 1024);
        check(high[3] == 128 * 4 * 2, $sformatf("dvsr = 3: channel 3 high %0d of 2048 clocks, expected 1024", high[3]));
        check(high[0] == 0 && high[5] == 2048, "0% stays low, 100% stays high");
        finish_test();
    end
    initial begin #5_000_000; $display("UNIT TEST pwm: TIMEOUT"); $finish; end
endmodule
