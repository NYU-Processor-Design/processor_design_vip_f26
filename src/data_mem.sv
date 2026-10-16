module data_mem(
	input logic [31:0] addr,
	input logic [31:0] data_in,
	input logic sign_val, // 0: unsigned, 1: signed
	input logic [1:0] read_size, // 0: byte, 1: halfword, 2: word
	input logic clk,
	input logic MemWrite, // 0: write disabled, 1: write enabled
	output logic [31:0] data_out
	);
	/*
	* Data Memory Module:
	* The requirements for the data memory module are to support
	* combinational reads of different sizes, either unsigned or signed,
	* and sequential writes of differing sizes as well. Recall the
	* appropriate size of our data memory which was 8,192 memory locations,
	* all byte-addressable (8 bits), little-endian.
	*/
endmodule
