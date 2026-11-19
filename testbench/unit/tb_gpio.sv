`timescale 1ns/1ps
// tb_gpio.sv : unit test for fpro/fpro_gpio.sv (see the register map there)
`define TEST_NAME "gpio"
module tb_gpio;
    `include "unit/slot_tb.svh"

    logic [7:0] din = '0;
    logic [3:0] dout;
    fpro_gpio #(.N_IN(8), .N_OUT(4)) dut (
        .clk(clk), .reset(reset), .cs(cs), .read(read), .write(write),
        .addr(addr), .wr_data(wr_data), .rd_data(rd_data), .din(din), .dout(dout));

    logic [31:0] d;
    initial begin
        do_reset();
        $display("-- reset values");
        bus_read(0, d); check_eq(d, 0, "DATA_OUT after reset");
        check_eq(32'(dout), 0, "dout pins after reset");
        bus_read(2, d); check_eq(d, 0, "EDGE after reset");

        $display("-- output register");
        bus_write(0, 32'h5);
        check_eq(32'(dout), 32'h5, "dout pins after writing 0x5");
        bus_read(0, d); check_eq(d, 32'h5, "DATA_OUT read-back");
        bus_write(0, 32'hFFFF_FFF7);
        check_eq(32'(dout), 32'h7, "dout keeps only N_OUT bits");
        bus_read(0, d); check_eq(d, 32'h7, "DATA_OUT upper bits read as 0");
        bus_write_no_cs(0, 32'h0);
        check_eq(32'(dout), 32'h7, "write with cs=0 is ignored");
        bus_write(1, 32'h0);
        bus_write(2, 32'h0);
        check_eq(32'(dout), 32'h7, "writes to offsets 1 and 2 do not touch DATA_OUT");

        $display("-- input synchronizer");
        @(negedge clk) din = 8'hA5;
        bus_read(1, d); check_eq(d, 0, "DATA_IN must not change 1 clock after the pin (2-FF synchronizer)");
        wait_clocks(3);
        bus_read(1, d); check_eq(d, 32'hA5, "DATA_IN shows the pins after synchronizing");
        bus_write(1, 32'hFF);
        bus_read(1, d); check_eq(d, 32'hA5, "DATA_IN is read-only");

        $display("-- rising-edge capture");
        bus_read(2, d); check_eq(d, 32'hA5, "EDGE: bits that went 0->1 are set");
        bus_read(2, d); check_eq(d, 32'hA5, "EDGE: reading does not clear (no side effects)");
        bus_write(2, 32'h05);
        bus_read(2, d); check_eq(d, 32'hA0, "EDGE: writing 1s clears exactly those bits");
        @(negedge clk) din = 8'hA7;                   // bit 1 rises
        wait_clocks(4);
        bus_read(2, d); check_eq(d, 32'hA2, "EDGE: new rising edge on bit 1");
        @(negedge clk) din = 8'h07;                   // bits 7 and 5 fall
        wait_clocks(4);
        bus_read(2, d); check_eq(d, 32'hA2, "EDGE: falling edges are not captured");
        @(negedge clk) din = 8'h00;
        wait_clocks(4);
        @(negedge clk) din = 8'h01;                   // bit 0 rises, held high
        wait_clocks(10);
        bus_read(2, d); check_eq(d, 32'hA3, "EDGE: a held-high input sets its flag once");
        bus_write(2, 32'hFF);
        bus_read(2, d); check_eq(d, 0, "EDGE: all cleared");
        wait_clocks(10);
        bus_read(2, d); check_eq(d, 0, "EDGE: a held-high input does not set the flag again");

        $display("-- other offsets");
        bus_read(5, d);  check_eq(d, 0, "unused offset 5 reads 0");
        bus_read(31, d); check_eq(d, 0, "unused offset 31 reads 0");

        $display("-- reset clears");
        do_reset();
        check_eq(32'(dout), 0, "dout cleared by reset");
        bus_read(2, d); check_eq(d, 0, "EDGE cleared by reset");
        finish_test();
    end
    initial begin #2_000_000; $display("UNIT TEST gpio: TIMEOUT"); $finish; end
endmodule
