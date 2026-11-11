`timescale 1ns/1ps

// read checks moved from data_mem_tb when byte/halfword selection moved into load_align
module load_align_tb();
    logic [31:0] word;
    logic [1:0] byte_off;
    logic [1:0] mem_size;
    logic sign_val;
    logic [31:0] data_out;

    load_align dut(.*);

    initial begin
        // the word data_mem_tb stores at address 0
        word = 32'hDEADBEEF; byte_off = 0;

        //1. Byte reading
        //Lowest address holds the lowest byte, 0xEF
        mem_size = 2'd0; sign_val = 0; #1;
        if (data_out !== 32'h000000EF) begin
            $display("FAIL byte read: got=%h exp=000000EF", data_out); $finish;
        end

        //2. Signed byte read
        mem_size = 2'd0; sign_val = 1; #1;
        if (data_out !== 32'hFFFFFFEF) begin
            $display("FAIL signed byte read: got=%h exp=FFFFFFEF", data_out); $finish;
        end

        //3. Halfword read using 0xBEEF
        mem_size = 2'd1; sign_val = 0; #1;
        if (data_out !== 32'h0000BEEF) begin
            $display("FAIL half read: got=%h exp=0000BEEF", data_out); $finish;
        end

        //4. Signed halfword read
        mem_size = 2'd1; sign_val = 1; #1;
        if (data_out !== 32'hFFFFBEEF) begin
            $display("FAIL signed half read: got=%h exp=FFFFBEEF", data_out); $finish;
        end

        $display("TEST PASSED");
        $finish;
    end
endmodule
