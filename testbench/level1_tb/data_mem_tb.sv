`timescale 1ns/1ps

module data_mem_tb();
    logic [31:0] addr;
	logic [31:0] data_in;
	logic [1:0] mem_size;
	logic clk;
	logic MemWrite;
	logic [31:0] rd_word;

    data_mem #(.INIT_FILE("")) dut(.*);

    // 10ns
    initial clk = 0;
    always #5 clk = ~clk;

    
    initial begin 
        addr = 0; data_in = 0; mem_size = 0; MemWrite = 0;
        @(posedge clk);
        #1;
        //1. Simple read and write for a word
        // WRITE: store the 32-bit word 0xDEADBEEF at address 0.
	    addr = 32'd0; data_in = 32'hDEADBEEF; mem_size = 2'd2; MemWrite = 1;
	    @(posedge clk); #1; MemWrite = 0;

        // CHECK: reading the whole word back gives the same value.
	    addr = 32'd0; mem_size = 2'd2; #1;
	    if (rd_word !== 32'hDEADBEEF) begin
	    	$display("FAIL word read: got=%h exp=DEADBEEF", rd_word); $finish;
	    end

        $display("TEST PASSED");
        $finish;
    end
endmodule

