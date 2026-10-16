module instr_imm(
	input logic [31:0] instr,
	output logic [31:0] imm
	);
	/*
	* Instruction Immediate Module:
	* This module is in charge of decoding instructions in parallel to the
	* control unit's decoding, reconstructing the appropriate immediate
	* value given the instruction, and outputting it using combinational
	* logic.
	* 
	* Be mindful of resources and reusing decoding logic when applicable
	* (e.g. instructions that don't require immediate values don't need
	* their own decoding logic).
	*/
endmodule
