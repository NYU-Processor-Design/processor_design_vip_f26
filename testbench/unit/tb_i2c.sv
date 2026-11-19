`timescale 1ns/1ps
// tb_i2c.sv : unit test for fpro/fpro_i2c.sv (see the register map there)
// An I2C slave model (16-byte memory at address 0x50) sits on an open-drain
// bus: each line is the wired-AND of everybody's output.
`define TEST_NAME "i2c"
module tb_i2c;
    `include "unit/slot_tb.svh"

    localparam int CMD_START = 0, CMD_WR = 1, CMD_RD = 2, CMD_STOP = 3, CMD_RESTART = 4;

    logic scl_o, sda_o, slave_sda;
    logic scl, sda;
    assign scl = scl_o;                       // nobody else drives SCL (no clock stretching)
    assign sda = sda_o & slave_sda;           // open drain: anybody can pull low

    fpro_i2c dut (
        .clk(clk), .reset(reset), .cs(cs), .read(read), .write(write),
        .addr(addr), .wr_data(wr_data), .rd_data(rd_data),
        .i2c_scl_o(scl_o), .i2c_sda_o(sda_o), .i2c_scl_i(scl), .i2c_sda_i(sda));

    i2c_slave_model #(.ADDR(7'h50)) slave (.scl(scl), .sda(sda), .sda_drive(slave_sda));

    // SCL monitor: every data/ACK bit is one SCL high pulse of exactly
    // 2*(dvsr+1) clocks. Longer high times only occur around START/RESTART/STOP.
    realtime t_rise = 0;
    int      n_bitpulse = 0, bad_pulse = 0, exp_high = 0;
    always @(posedge scl) t_rise = $realtime;
    always @(negedge scl) if (exp_high != 0) begin
        realtime w = $realtime - t_rise;
        if (w == exp_high * CLK_NS) n_bitpulse++;
        else if (w < 2 * exp_high * CLK_NS) bad_pulse++;
    end

    logic [31:0] d;
    task automatic cmd(input int c, input logic [7:0] data);
        logic [31:0] st;
        do bus_read(0, st); while (!st[9]);
        bus_write(2, {21'd0, 3'(c), data});
        do bus_read(0, st); while (!st[9]);
    endtask

    initial begin
        do_reset();
        $display("-- reset values");
        bus_read(0, d); check_eq(d & 32'h200, 32'h200, "READY = 1 after reset");
        bus_read(1, d); check_eq(d, 62, "divisor after reset = 62 (~100 kHz)");
        check(scl_o === 1'b1 && sda_o === 1'b1, "SCL and SDA released after reset");
        wait_clocks(30);                        // let the slave model arm

        bus_write(1, 4);                        // quarter period = 5 clocks, SCL period = 20 clocks
        bus_read(1, d); check_eq(d, 4, "divisor read-back");
        exp_high = 10;                          // SCL high for 2 quarters = 10 clocks

        $display("-- write: START, 0xA0, ptr 3, DE, AD, STOP");
        bus_write(2, {21'd0, 3'(CMD_START), 8'h00});
        bus_read(0, d); check(d[9] == 1'b0, "READY = 0 while a command runs");
        do bus_read(0, d); while (!d[9]);
        check(scl === 1'b0, "SCL held low after START");
        cmd(CMD_WR, 8'hA0); bus_read(0, d); check(d[8], "address 0x50 + W is ACKed");
        cmd(CMD_WR, 8'h03); bus_read(0, d); check(d[8], "pointer byte ACKed");
        cmd(CMD_WR, 8'hDE); bus_read(0, d); check(d[8], "data byte ACKed");
        cmd(CMD_WR, 8'hAD); bus_read(0, d); check(d[8], "data byte ACKed");
        cmd(CMD_STOP, 0);
        wait_clocks(5);
        check(scl === 1'b1 && sda === 1'b1, "bus released after STOP");
        check(slave.mem[3] == 8'hDE && slave.mem[4] == 8'hAD, "slave memory now holds DE AD at 3,4");

        $display("-- read: START, 0xA0, ptr 3, RESTART, 0xA1, read, read(last), STOP");
        cmd(CMD_START, 0);
        cmd(CMD_WR, 8'hA0);
        cmd(CMD_WR, 8'h03);
        cmd(CMD_RESTART, 0);
        cmd(CMD_WR, 8'hA1); bus_read(0, d); check(d[8], "address 0x50 + R is ACKed");
        cmd(CMD_RD, 8'h00); bus_read(0, d); check_eq(d & 32'hFF, 32'hDE, "1st byte read");
        cmd(CMD_RD, 8'h01); bus_read(0, d); check_eq(d & 32'hFF, 32'hAD, "2nd byte read (master NACKs: last)");
        bus_read(0, d); check_eq(d & 32'hFF, 32'hAD, "reading the data register twice gives the same byte");
        cmd(CMD_STOP, 0);
        check(slave.n_rd == 2, "slave sent exactly 2 bytes (NACK stopped it)");

        $display("-- no device at 0x51");
        cmd(CMD_START, 0);
        cmd(CMD_WR, 8'hA2); bus_read(0, d); check(!d[8], "address 0x51 is NOT acknowledged");
        cmd(CMD_STOP, 0);

        $display("-- read the preset memory: 0x0A, 0x0B");
        cmd(CMD_START, 0);
        cmd(CMD_WR, 8'hA0);
        cmd(CMD_WR, 8'h0A);
        cmd(CMD_RESTART, 0);
        cmd(CMD_WR, 8'hA1);
        cmd(CMD_RD, 8'h00); bus_read(0, d); check_eq(d & 32'hFF, 32'hCA, "mem[0x0A]");
        cmd(CMD_RD, 8'h01); bus_read(0, d); check_eq(d & 32'hFF, 32'hCB, "mem[0x0B]");
        cmd(CMD_STOP, 0);
        wait_clocks(5);

        $display("-- protocol checks");
        check(slave.n_start == 6, $sformatf("6 START conditions on the bus, incl. repeated (saw %0d)", slave.n_start));
        check(slave.n_stop  == 4, $sformatf("4 STOP conditions on the bus (saw %0d)", slave.n_stop));
        check(bad_pulse == 0, $sformatf("every SCL bit pulse is high for 2*(dvsr+1) = 10 clocks (%0d wrong)", bad_pulse));
        check(n_bitpulse == 15 * 9, $sformatf("15 bytes x 9 clocks = 135 SCL bit pulses (saw %0d)", n_bitpulse));
        bus_read(5, d); check_eq(d, 0, "unused offset reads 0");
        finish_test();
    end
    initial begin #5_000_000; $display("UNIT TEST i2c: TIMEOUT"); $finish; end
endmodule
