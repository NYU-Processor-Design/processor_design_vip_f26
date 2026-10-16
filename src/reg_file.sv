module reg_file(
	input logic [4:0] rs1,
	input logic [4:0] rs2,
	input logic [4:0] rd,
	input logic [31:0] data_in,
	input logic RegWrite, // 0: write disabled, 1: write enabled
	input logic clk,
	output logic [31:0] rs1_out,
	output logic [31:0] rs2_out
	);
	/*
	* Register File Module:
	* The requirements for the register file are to support reads of rs1
	* and rs2 in parallel, as well as supporting sequential writes to rd
	* with data from data_in. RegWrite is a control signal that determines
	* whether we want to write on a given clock edge (posedge), and clk is
	* our clock signal which is shared across the core.
	* Also recall that there are 32, 32-bit registers, one of which
	* (register x0) is hard-wired to 32'b0.
	*/
endmodule
