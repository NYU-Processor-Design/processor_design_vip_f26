// Checks every {opcode, funct3, instr[30]} combination against docs/control_table.csv,
// with the instruction bits the control unit should ignore randomized.
module control_unit_tb;
    `include "tb_utils.svh"
    `include "control_table.svh"

    localparam int RANDOM_FILLS = 4;

    logic [31:0] instr;
    logic        branch_decoder_on, mux_PC, RegWrite, MemWrite, mux_ALUB, sign_val;
    logic [1:0]  mux_reg, mux_ALUA, read_size;
    logic [2:0]  funct3;
    logic [3:0]  ALU_funct;
    ctrl_t       actual;

    control_unit dut (
        .instr(instr),
        .branch_decoder_on(branch_decoder_on),
        .funct3(funct3),
        .mux_PC(mux_PC),
        .mux_reg(mux_reg),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .mux_ALUA(mux_ALUA),
        .mux_ALUB(mux_ALUB),
        .ALU_funct(ALU_funct),
        .sign_val(sign_val),
        .read_size(read_size)
    );

    assign actual = {branch_decoder_on, mux_PC, mux_reg, RegWrite, MemWrite,
                     mux_ALUA, mux_ALUB, ALU_funct, sign_val, read_size};

    task automatic check(input logic [31:0] i);
        ctrl_t exp, mask;
        string name;
        exp = ctrl_expected(i[6:0], i[14:12], i[30]);
        mask = ctrl_mask(i[6:0], i[14:12], i[30]);
        name = ctrl_name(i[6:0], i[14:12], i[30]);
        instr = i;
        #1;
        `CHECK(((actual ^ exp) & mask) === '0,
               $sformatf("%s instr=%h: %s", name, i, ctrl_diff(actual, exp, mask)));
        `CHECK(!($isunknown(actual) || $isunknown(funct3)),
               $sformatf("%s instr=%h: output is X/Z (%b, funct3 %b)", name, i, actual, funct3));
        if (exp.branch_decoder_on)
            `CHECK_EQ(funct3, i[14:12], $sformatf("%s instr=%h: funct3", name, i));
    endtask

    // Real encodings, to catch a table row matched against the wrong instruction
    task automatic check_named(input logic [31:0] i, input string name);
        `CHECK(ctrl_name(i[6:0], i[14:12], i[30]) == name,
               $sformatf("instr=%h decodes as %s, expected %s",
                         i, ctrl_name(i[6:0], i[14:12], i[30]), name));
        check(i);
    endtask

    initial begin
        check_named(32'h1234_52B7, "LUI");   // lui   x5, 0x12345
        check_named(32'h00A3_0293, "ADDI");  // addi  x5, x6, 10
        check_named(32'h41F1_5093, "SRAI");  // srai  x1, x2, 31
        check_named(32'h0031_00B3, "ADD");   // add   x1, x2, x3
        check_named(32'h4031_00B3, "SUB");   // sub   x1, x2, x3
        check_named(32'h0231_00B3, "ADD");   // mul   x1, x2, x3 (only instr[30] is decoded)
        check_named(32'h00C1_4283, "LBU");   // lbu   x5, 12(x2)
        check_named(32'h0051_2A23, "SW");    // sw    x5, 20(x2)
        check_named(32'h0020_8863, "BEQ");   // beq   x1, x2, 16
        check_named(32'h0060_00EF, "JAL");   // jal   ra, 6
        check_named(32'hFFC1_00E7, "JALR");  // jalr  ra, -4(x2)
        check_named(32'h0000_0073, "NOP");   // ecall
        check_named(32'h0FF0_000F, "NOP");   // fence

        for (int key = 0; key < 2048; key++) begin
            repeat (RANDOM_FILLS) begin
                logic [31:0] i;
                i = $urandom;
                {i[6:0], i[14:12], i[30]} = key[10:0];
                check(i);
            end
        end

        `TB_FINISH;
    end
endmodule
