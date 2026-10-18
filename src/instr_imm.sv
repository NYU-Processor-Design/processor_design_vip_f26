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
logic [6:0] opcode;
logic [2:0] funct3;

assign opcode = instr[6:0];
assign funct3 = instr[14:12];

always_comb begin
    imm = 32'b0;

    case (opcode)

        // I-type: OP-IMM
        7'b0010011: begin
            if ((funct3 == 3'b001) || (funct3 == 3'b101))
                imm = {27'b0, instr[24:20]};
            else
                imm = {{20{instr[31]}}, instr[31:20]};
        end

        // I-type: LOAD
        7'b0000011: begin
            imm = {{20{instr[31]}}, instr[31:20]};
        end

        // I-type: JALR
        7'b1100111: begin
            imm = {{20{instr[31]}}, instr[31:20]};
        end

        // S-type: STORE
        7'b0100011: begin
            imm = {{20{instr[31]}},
                   instr[31:25],
                   instr[11:7]};
        end

        // B-type: BRANCH
        7'b1100011: begin
            imm = {{19{instr[31]}},
                   instr[31],
                   instr[7],
                   instr[30:25],
                   instr[11:8],
                   1'b0};
        end

        // U-type: LUI
        7'b0110111: begin
            imm = {instr[31:12], 12'b0};
        end

        // U-type: AUIPC
        7'b0010111: begin
            imm = {instr[31:12], 12'b0};
        end

        // J-type: JAL
        7'b1101111: begin
            imm = {{11{instr[31]}},
                   instr[31],
                   instr[19:12],
                   instr[20],
                   instr[30:21],
                   1'b0};
        end

        default: begin
            imm = 32'b0;
        end

    endcase
end
endmodule
