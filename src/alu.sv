module alu(
	input logic [31:0] inA,
	input logic [31:0] inB,
	input logic [3:0] ALU_funct,
	output logic [31:0] out,
	output logic zflag
	);
	/*
	* ALU Module:
	* The ALU requires support for all of the following functions:
	* ADD     : 0
	* SUB     : 1
	* SLL     : 2
	* SLT     : 3
	* SLTU    : 4
	* XOR     : 5
	* SRL     : 6
	* SRA     : 7
	* OR      : 8
	* AND     : 9
	* JALR_ALU: 10
		* JALR_ALU is a normal addition, but the output's LSB is set
		* to zero. Therefore you may reuse logic within the ALU for
		* this goal.
	* The ALU also requires the additional output of the zero flag for the
	* purpose of its use in the Branch Decoder module.
	*/
endmodule
