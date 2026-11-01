// test-only dependencies, excluded entirely by the runner's --production mode
// these models validate top integration, not the unfinished production CPU
module reg_file(
    input logic [4:0] rs1, rs2, rd,
    input logic [31:0] data_in,
    input logic RegWrite, clk,
    output logic [31:0] rs1_out, rs2_out
);
    logic [31:0] regs [0:31];

    // deterministic model storage; the program initializes production state explicitly
    initial begin
        for (int i = 0; i < 32; i++) regs[i] = 0;
    end
    // x0 remains constant regardless of writes
    assign rs1_out = rs1 == 0 ? 32'b0 : regs[rs1];
    assign rs2_out = rs2 == 0 ? 32'b0 : regs[rs2];
    // commit register writes on the shared edge
    always @(posedge clk) begin
        if (RegWrite && rd != 0) regs[rd] <= data_in;
    end
endmodule

// byte memory models all load and store widths
module data_mem(
    input logic [31:0] addr, data_in,
    input logic sign_val,
    input logic [1:0] read_size,
    input logic clk, MemWrite,
    output logic [31:0] data_out
);
    logic [7:0] bytes [0:8191];

    // initialize only this test model's storage
    initial begin
        for (int i = 0; i < 8192; i++) bytes[i] = 0;
    end
    // bound each width independently; invalid sizes return zero
    always @* begin
        data_out = 0;
        case (read_size)
            0: if (addr < 8192) data_out = {{24{sign_val && bytes[addr][7]}}, bytes[addr]};
            1: if (addr < 8191) data_out = {{16{sign_val && bytes[addr + 1][7]}}, bytes[addr + 1], bytes[addr]};
            2: if (addr < 8189) data_out = {bytes[addr + 3], bytes[addr + 2], bytes[addr + 1], bytes[addr]};
            default: data_out = 0;
        endcase
    end

    // reject invalid sizes and accesses crossing the model's upper boundary
    always @(posedge clk) begin
        if (MemWrite && ((read_size == 0 && addr < 8192) ||
                        (read_size == 1 && addr < 8191) ||
                        (read_size == 2 && addr < 8189))) begin
            bytes[addr] <= data_in[7:0];
            if (read_size != 0) bytes[addr + 1] <= data_in[15:8];
            // a word commits all four little-endian bytes
            if (read_size == 2) begin
                bytes[addr + 2] <= data_in[23:16];
                bytes[addr + 3] <= data_in[31:24];
            end
        end
    end
endmodule

// independent arithmetic model uses the documented ALU operation numbers
module alu(
    input logic [31:0] inA, inB,
    input logic [3:0] ALU_funct,
    output logic [31:0] out,
    output logic zflag
);
    // calculate the documented operations without reusing production RTL
    always @* begin
        case (ALU_funct)
            0: out = inA + inB;
            1: out = inA - inB;
            2: out = inA << inB[4:0];
            3: out = {31'b0, $signed(inA) < $signed(inB)};
            4: out = {31'b0, inA < inB};
            5: out = inA ^ inB;
            6: out = inA >> inB[4:0];
            7: out = $signed(inA) >>> inB[4:0];
            8: out = inA | inB;
            9: out = inA & inB;
            10: out = (inA + inB) & 32'hffff_fffe;
            default: out = 0;
        endcase
    end
    // comparisons feed the production branch decoder
    assign zflag = out == 0;
endmodule

// decode only the legal instructions emitted by this independent test
module control_unit(
    input logic [31:0] instr,
    output logic branch_decoder_on,
    output logic [2:0] funct3,
    output logic mux_PC,
    output logic [1:0] mux_reg,
    output logic RegWrite, MemWrite,
    output logic [1:0] mux_ALUA,
    output logic mux_ALUB,
    output logic [3:0] ALU_funct,
    output logic sign_val,
    output logic [1:0] read_size
);
    // safe defaults disable architectural writes for unrecognized opcodes
    always @* begin
        funct3 = instr[14:12];
        branch_decoder_on = 0;
        mux_PC = 1;
        mux_reg = 0;
        RegWrite = 0;
        MemWrite = 0;
        mux_ALUA = 0;
        mux_ALUB = 0;
        ALU_funct = 0;
        sign_val = !instr[14];
        read_size = instr[13:12];
        case (instr[6:0])
            7'h37: begin
                RegWrite = 1;
                mux_ALUA = 1;
                mux_ALUB = 1;
            end
            7'h17: begin
                RegWrite = 1;
                mux_ALUA = 2;
                mux_ALUB = 1;
            end
            7'h6f, 7'h67: begin
                RegWrite = 1;
                mux_PC = 0;
                mux_reg = 1;
                mux_ALUA = instr[6:0] == 7'h6f ? 2 : 0;
                mux_ALUB = 1;
                ALU_funct = 10;
            end
            7'h63: begin
                branch_decoder_on = 1;
                case (funct3)
                    0, 1: ALU_funct = 1;
                    4, 5: ALU_funct = 3;
                    6, 7: ALU_funct = 4;
                    default: ALU_funct = 0;
                endcase
            end
            7'h03: begin
                RegWrite = 1;
                mux_reg = 2;
                mux_ALUB = 1;
            end
            7'h23: begin
                MemWrite = 1;
                mux_ALUB = 1;
            end
            7'h13, 7'h33: begin
                RegWrite = 1;
                mux_ALUB = instr[6:0] == 7'h13;
                case (funct3)
                    0: ALU_funct = (instr[6:0] == 7'h33 && instr[30]) ? 1 : 0;
                    1: ALU_funct = 2;
                    2: ALU_funct = 3;
                    3: ALU_funct = 4;
                    4: ALU_funct = 5;
                    5: ALU_funct = instr[30] ? 7 : 6;
                    6: ALU_funct = 8;
                    7: ALU_funct = 9;
                endcase
            end
            default: begin end
        endcase
    end
endmodule
