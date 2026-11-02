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

	always_comb begin
		case (ALU_funct)
			4'd0: out = inA + inB; // ADD: keep the low 32 bits of the sum.
			4'd1: out = inA - inB;
			4'd2: out = inA << inB[4:0];
			4'd3: out = {31'b0, ($signed(inA) < $signed(inB))};
			4'd4: out = {31'b0, (inA < inB)};
			4'd5: out = inA ^ inB;
			4'd6: out = inA >> inB[4:0];
			4'd7: out = $signed(inA) >>> inB[4:0];
			4'd8: out = inA | inB;
			4'd9: out = inA & inB;
			4'd10: out = (inA + inB) & 32'hFFFF_FFFE;
			// Undefined function codes produce a deterministic zero result.
			default: out = 32'b0;
		endcase
		zflag = (out == 32'b0);
	end
endmodule
