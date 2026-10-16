module control_unit(
	input logic [31:0] instr,
	output logic branch_decoder_on,
	output logic [2:0] funct3, // funct3 output is specifically for the branch decoder
	output logic mux_PC,
	output logic [1:0] mux_reg,
	output logic RegWrite,
	output logic MemWrite,
	output logic [1:0] mux_ALUA,
	output logic mux_ALUB,
	output logic [3:0] ALU_funct,
	output logic sign_val,
	output logic [1:0] read_size
	);
	/*
	* Control Unit Module:
	* The control unit's requirements are to decode the given instruction
	* combinationally and to output the appropriate control signals given
	* a specific type of instruction. The logic can get a bit cumbersome,
	* so refer heavily to "MICRO-ARCHITECTURE/RV32I_INSTRUCTIONS.pdf" in
	* the shared google drive to group instructions together for simpler
	* decoding. Make sure to avoid inferred latching when using
	* combinational logic here (e.g. always @(*) must be handled with
	* care), and to distribute the work fairly in order to meet our goals.
	*/
endmodule
