`timescale 1ns/1ps
// tb_uart.sv : unit test for fpro/fpro_uart.sv (see the register map there)
//   * a serial monitor decodes everything on tx (8N1) and checks the bit timing
//   * rx is either looped back from tx, or driven by the testbench
`define TEST_NAME "uart"
module tb_uart;
    `include "unit/slot_tb.svh"

    localparam int DVSR   = 9;                     // 25 MHz / (16 * 10) = 156250 baud
    localparam int BIT_NS = 16 * (DVSR + 1) * CLK_NS;

    logic tx, rx;
    logic loopback = 1'b1, tb_rx = 1'b1;
    assign rx = loopback ? tx : tb_rx;

    fpro_uart #(.CLK_HZ(25_000_000), .BAUD(9600)) dut (
        .clk(clk), .reset(reset), .cs(cs), .read(read), .write(write),
        .addr(addr), .wr_data(wr_data), .rd_data(rd_data), .rx(rx), .tx(tx));

    // ---- serial monitor on tx ----
    logic [7:0] mon [64];
    int n_mon = 0, mon_err = 0;
    bit mon_on = 0;
    initial begin : monitor
        logic [7:0] ch;
        forever begin
            @(negedge tx);
            if (!mon_on) continue;
            #(BIT_NS/2);
            if (tx !== 1'b0) begin mon_err++; $display("  FAIL  tx: start bit too short at %0t", $time); end
            for (int k = 0; k < 8; k++) begin #(BIT_NS); ch[k] = tx; end
            #(BIT_NS);
            if (tx !== 1'b1) begin mon_err++; $display("  FAIL  tx: stop bit is not 1 at %0t", $time); end
            if (n_mon < 64) mon[n_mon] = ch;
            n_mon++;
        end
    end

    task automatic tb_send(input logic [7:0] b, input bit good_stop);
        tb_rx = 1'b0; #(BIT_NS);
        for (int j = 0; j < 8; j++) begin tb_rx = b[j]; #(BIT_NS); end
        tb_rx = good_stop; #(BIT_NS);
        tb_rx = 1'b1; #(BIT_NS);
    endtask

    logic [31:0] d;
    int t0;
    initial begin
        do_reset();
        $display("-- reset values");
        check(tx === 1'b1, "tx idles high after reset");
        bus_read(1, d); check_eq(d, 162, "divisor after reset = round(25e6/(16*9600))-1");
        bus_read(0, d); check_eq(d & 32'h300, 32'h100, "status after reset: rx_empty=1, tx_full=0");

        $display("-- transmit (loopback)");
        bus_write(1, DVSR);
        bus_read(1, d); check_eq(d, DVSR, "divisor read-back");
        mon_on = 1;
        bus_write(2, 32'h55);
        bus_write(2, 32'hA3);
        bus_read(0, d); check_eq(d & 32'h100, 32'h100, "rx still empty right after queuing (nothing received yet)");
        #(25 * BIT_NS);
        check(n_mon == 2 && mon[0] == 8'h55 && mon[1] == 8'hA3, "tx line carried 0x55 then 0xA3 (8N1, LSB first, correct bit time)");

        $display("-- receive");
        bus_read(0, d); check_eq(d & 32'h3FF, 32'h055, "rx head = 0x55, rx_empty = 0");
        bus_read(0, d); check_eq(d & 32'h3FF, 32'h055, "reading does not remove the byte");
        bus_write(3, 0);
        bus_read(0, d); check_eq(d & 32'h3FF, 32'h0A3, "after remove: rx head = 0xA3");
        bus_write(3, 0);
        bus_read(0, d); check_eq(d & 32'h100, 32'h100, "after second remove: rx_empty = 1");
        bus_write(3, 0);
        bus_read(0, d); check_eq(d & 32'h100, 32'h100, "remove on an empty FIFO is harmless");

        $display("-- FIFOs full");
        for (int i = 0; i < 20; i++) bus_write(2, 32'h30 + i);
        bus_read(0, d); check_eq(d & 32'h200, 32'h200, "tx_full = 1 after queuing 20 bytes quickly");
        #(24 * 10 * BIT_NS);
        bus_read(0, d); check_eq(d & 32'h200, 0, "tx_full = 0 once everything is sent");
        for (int i = 0; i < 16; i++) begin
            bus_read(0, d);
            check_eq(d & 32'h1FF, 32'h30 + i, $sformatf("rx FIFO entry %0d in order", i));
            bus_write(3, 0);
        end
        bus_read(0, d); check_eq(d & 32'h100, 32'h100, "rx FIFO held 16 bytes; the extra bytes were dropped");

        $display("-- framing");
        loopback = 1'b0;
        tb_send(8'h3C, 1'b0);                        // stop bit = 0: must be discarded
        #(3 * 10 * BIT_NS);                          // let the receiver resynchronize
        begin
            bit seen = 0;
            for (int i = 0; i < 4; i++) begin       // whatever arrived, 0x3C must not be in it
                bus_read(0, d);
                if (!d[8] && d[7:0] == 8'h3C) seen = 1;
                if (!d[8]) bus_write(3, 0);
            end
            check(!seen, "byte with a 0 stop bit is discarded");
        end
        tb_send(8'hC3, 1'b1);
        bus_read(0, d); check_eq(d & 32'h1FF, 32'h0C3, "next good byte is received");
        bus_write(3, 0);

        bus_read(9, d); check_eq(d, 0, "unused offset reads 0");
        check(mon_err == 0, "no framing errors on tx");
        finish_test();
    end
    initial begin #20_000_000; $display("UNIT TEST uart: TIMEOUT"); $finish; end
endmodule
