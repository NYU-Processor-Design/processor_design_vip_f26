module instr_imm_tb;

    `include "tb_utils.svh"

    logic [31:0] instr;
    logic [31:0] imm;

    instr_imm dut (
        .instr(instr),
        .imm(imm)
    );

    initial begin

        // OP-IMM (I)
        instr = 32'h00A3_0293;
        #1;
        `CHECK_EQ(imm, 32'h0000_000A, "ADDI positive immediate");


        instr = 32'hFF83_0293;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFF8, "ADDI negative immediate");


        instr = 32'hFFF3_7293;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFFF, "ANDI negative immediate");

        instr = 32'h0051_1093;
        #1;
        `CHECK_EQ(imm, 32'h0000_0005, "SLLI shamt 5");

        instr = 32'h0071_5093;
        #1;
        `CHECK_EQ(imm, 32'h0000_0007, "SRLI shamt 7");

        instr = 32'h41F1_5093;
        #1;
        `CHECK_EQ(imm, 32'h0000_001F, "SRAI shamt 31");

        // LOAD (I)
        instr = 32'h00C1_2283;
        #1;
        `CHECK_EQ(imm, 32'h0000_000C, "LW positive offset");


        instr = 32'hFF01_0283;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFF0, "LB negative offset");

        // JALR (I)
        instr = 32'hFFC1_00E7;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFFC, "JALR negative immediate");

        // STORE (S)
        instr = 32'h0051_2A23;
        #1;
        `CHECK_EQ(imm, 32'h0000_0014, "SW positive offset");

        instr = 32'hFE51_2823;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFF0, "SW negative offset");

        // BRANCH (B)
        instr = 32'h0020_8863;
        #1;
        `CHECK_EQ(imm, 32'h0000_0010, "BEQ positive offset");

        instr = 32'hFE20_9CE3;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFF8, "BNE negative offset");

        // LUI (U)
        instr = 32'h1234_52B7;
        #1;
        `CHECK_EQ(imm, 32'h1234_5000, "LUI upper immediate");

        // AUIPC (U)
        instr = 32'hABCD_E297;
        #1;
        `CHECK_EQ(imm, 32'hABCD_E000, "AUIPC upper immediate");

        // JAL (J)
        instr = 32'h1000_00EF;
        #1;
        `CHECK_EQ(imm, 32'h0000_0100, "JAL positive offset");

        instr = 32'hFE1F_F0EF;
        #1;
        `CHECK_EQ(imm, 32'hFFFF_FFE0, "JAL negative offset");


        instr = 32'h0031_00B3;
        #1;
        `CHECK_EQ(imm, 32'h0000_0000, "ADD has no immediate");

        instr = 32'hFFFF_FFFF;
        #1;
        `CHECK_EQ(imm, 32'h0000_0000, "Unsupported opcode defaults to zero");

        `TB_FINISH;

    end

endmodule