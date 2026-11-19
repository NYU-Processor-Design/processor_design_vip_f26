`timescale 1ns/1ps
// tb_timer.sv : unit test for fpro/fpro_timer.sv (see the register map there)
`define TEST_NAME "timer"
module tb_timer;
    `include "unit/slot_tb.svh"

    fpro_timer dut (
        .clk(clk), .reset(reset), .cs(cs), .read(read), .write(write),
        .addr(addr), .wr_data(wr_data), .rd_data(rd_data));

    logic [31:0] a, b, d;
    initial begin
        do_reset();
        $display("-- counts from reset");
        bus_read(2, d); check_eq(d, 1, "CTRL.go = 1 after reset");
        bus_read(0, a);
        wait_clocks(99);
        bus_read(0, b);
        check(b - a >= 99 && b - a <= 102, $sformatf("counter advances once per clock (diff %0d, expected ~100)", b - a));
        bus_read(1, d); check_eq(d, 0, "high word is 0 early on");

        $display("-- pause / resume");
        bus_write(2, 0);
        bus_read(2, d); check_eq(d, 0, "CTRL.go reads back 0");
        bus_read(0, a); wait_clocks(50); bus_read(0, b);
        check_eq(b, a, "paused counter does not move");
        bus_write(2, 1);
        wait_clocks(20);
        bus_read(0, d); check(d > b, "resumed counter moves again");

        $display("-- clear");
        wait_clocks(500);
        bus_write(2, 3);                              // clear + keep going
        bus_read(0, d); check(d < 5, $sformatf("counter near 0 right after clear (got %0d)", d));
        bus_read(2, d); check_eq(d, 1, "CTRL.go still 1 after clear (clear bit is not stored)");
        bus_write(2, 2);                              // clear while pausing
        bus_read(0, a); wait_clocks(20); bus_read(0, b);
        check(a == 0 && b == 0, "clear + pause leaves the counter at 0");
        bus_write(2, 1);

        $display("-- bus rules");
        bus_read(0, a);
        bus_write_no_cs(2, 0);
        wait_clocks(10);
        bus_read(0, b); check(b > a, "write with cs=0 does not pause");
        bus_write(0, 0); bus_write(1, 0);
        bus_read(0, d); check(d > b, "writes to the count registers are ignored");
        bus_read(7, d); check_eq(d, 0, "unused offset reads 0");
        finish_test();
    end
    initial begin #2_000_000; $display("UNIT TEST timer: TIMEOUT"); $finish; end
endmodule
