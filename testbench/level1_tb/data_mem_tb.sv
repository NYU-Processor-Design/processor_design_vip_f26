`timescale 1ns/1ps

module data_mem_tb();
    logic [31:0] addr;
	logic [31:0] data_in;
	logic sign_val;
	logic [1:0] mem_size;
	logic clk;
	logic MemWrite;
	logic [31:0] rd_word;

    data_mem #(.INIT_FILE("")) dut(.*);

    // 10ns
    initial clk = 0;
    always #5 clk = ~clk;

    
    initial begin 
        addr = 0; data_in = 0; sign_val = 0; mem_size = 0; MemWrite = 0;
        @(posedge clk);
        #1;
        //1. Simple read and write for a word
        // WRITE: store the 32-bit word 0xDEADBEEF at address 0.
	    addr = 32'd0; data_in = 32'hDEADBEEF; mem_size = 2'd2; MemWrite = 1;
	    @(posedge clk); #1; MemWrite = 0;

        // CHECK: reading the whole word back gives the same value.
	    addr = 32'd0; mem_size = 2'd2; sign_val = 0; #1;
	    if (rd_word !== 32'hDEADBEEF) begin
	    	$display("FAIL word read: got=%h exp=DEADBEEF", rd_word); $finish;
	    end

        //2. Byte reading
        //Lowest address holds the lowest byte, 0xEF
	    addr = 32'd0; mem_size = 2'd0; sign_val = 0; #1;
	    if (rd_word !== 32'h000000EF) begin
	    	$display("FAIL byte read: got=%h exp=000000EF", rd_word); $finish;
	    end

        //3.  Signed byte read
        addr = 32'd0; mem_size = 2'd0; sign_val = 1; #1;
	    	if (rd_word !== 32'hFFFFFFEF) begin
	    		$display("FAIL signed byte read: got=%h exp=FFFFFFEF", rd_word); $finish;
	    	end

        //4. Halfword read using 0xBEEF
        addr = 32'd0; mem_size = 2'd1; sign_val = 0; #1;
	    if (rd_word !== 32'h0000BEEF) begin
	    	$display("FAIL half read: got=%h exp=0000BEEF", rd_word); $finish;
	    end

        //5. Signed halfword read
        addr = 32'd0; mem_size = 2'd1; sign_val = 1; #1;
	    if (rd_word !== 32'hFFFFBEEF) begin
	    	$display("FAIL signed half read: got=%h exp=FFFFBEEF", rd_word); $finish;
	    end

        //6. Out of range check  
        addr = 32'd8192; mem_size = 2'd0; sign_val = 0; #1;
	    if (rd_word !== 32'h0) begin
	    	$display("FAIL out of range read: got=%h exp=0", rd_word); $finish;
	    end
        $display("ALL TESTS PASSED");
        $finish;
    end
endmodule

