module data_mem_tb;
    timeunit 1ns;
    timeprecision 1ps;

    `include "tb_utils.svh"

    logic clk = 0;
    logic [31:0] addr, data_in, rd_word, data_out;
    logic [1:0] mem_size;
    logic sign_val, MemWrite;

    data_mem #(.WORDS(4), .INIT_FILE("")) dut (
        .clk(clk), .addr(addr), .data_in(data_in),
        .MemWrite(MemWrite), .mem_size(mem_size), .rd_word(rd_word)
    );
    load_align align_load (
        .word(rd_word), .byte_off(addr[1:0]), .mem_size(mem_size),
        .sign_val(sign_val), .data_out(data_out)
    );

    always #5 clk = ~clk;

    task automatic store(input logic [31:0] address, value,
                         input logic [1:0] size);
        // Set inputs away from the write edge, then wait for the NBA update.
        @(negedge clk);
        addr = address;
        data_in = value;
        mem_size = size;
        MemWrite = 1;
        @(posedge clk);
        #1;
        MemWrite = 0;
    endtask

    task automatic check_load(input logic [31:0] address,
                              input logic [1:0] size,
                              input logic signed_load,
                              input logic [31:0] expected,
                              input string description);
        addr = address;
        mem_size = size;
        sign_val = signed_load;
        #1;
        `CHECK_EQ(data_out, expected, description);
    endtask

    initial begin
        addr = 0;
        data_in = 0;
        mem_size = 2'd2;
        sign_val = 0;
        MemWrite = 0;

        check_load(12, 2'd2, 0, 32'h00000000, "memory starts at zero");
        store(0, 32'hDEADBEEF, 2'd2);
        store(4, 32'h12345678, 2'd2);
        store(12, 32'hCAFE8001, 2'd2);

        // Switching words must update the address without overwriting neighbors.
        check_load(0, 2'd2, 0, 32'hDEADBEEF, "first word");
        check_load(4, 2'd2, 0, 32'h12345678, "second word");
        check_load(12, 2'd2, 0, 32'hCAFE8001, "last word");
        check_load(0, 2'd2, 0, 32'hDEADBEEF, "return to first word");

        // Little-endian byte lanes and signed/unsigned load extension.
        check_load(0, 2'd0, 0, 32'h000000EF, "unsigned low byte");
        check_load(0, 2'd0, 1, 32'hFFFFFFEF, "signed negative byte");
        check_load(1, 2'd0, 0, 32'h000000BE, "byte lane one");
        check_load(2, 2'd0, 0, 32'h000000AD, "byte lane two");
        check_load(3, 2'd0, 0, 32'h000000DE, "byte lane three");
        check_load(7, 2'd0, 1, 32'h00000012, "signed positive byte");
        check_load(0, 2'd1, 0, 32'h0000BEEF, "unsigned low halfword");
        check_load(0, 2'd1, 1, 32'hFFFFBEEF, "signed low halfword");
        check_load(2, 2'd1, 0, 32'h0000DEAD, "unsigned high halfword");
        check_load(2, 2'd1, 1, 32'hFFFFDEAD, "signed high halfword");
        check_load(4, 2'd1, 1, 32'h00005678, "signed positive halfword");

        // Subword stores replace only the selected bytes.
        store(1, 32'hABCDEF11, 2'd0);
        check_load(0, 2'd2, 0, 32'hDEAD11EF, "byte store preserves other lanes");
        store(3, 32'h123456A5, 2'd0);
        check_load(0, 2'd2, 0, 32'hA5AD11EF, "high byte store");
        store(0, 32'h123480F0, 2'd1);
        check_load(0, 2'd2, 0, 32'hA5AD80F0, "low halfword store");
        store(2, 32'hABCD7ABC, 2'd1);
        check_load(0, 2'd2, 0, 32'h7ABC80F0, "high halfword store");
        check_load(0, 2'd1, 1, 32'hFFFF80F0, "signed load after halfword store");
        check_load(4, 2'd2, 0, 32'h12345678, "neighbor survives subword stores");

        @(negedge clk);
        addr = 4;
        data_in = 32'hFFFFFFFF;
        mem_size = 2'd2;
        MemWrite = 0;
        @(posedge clk);
        #1;
        check_load(4, 2'd2, 0, 32'h12345678, "write enable blocks stores");

        if (tb_errors != 0) $fatal(1, "TEST FAILED (%0d errors)", tb_errors);
        `TB_FINISH;
    end
endmodule
