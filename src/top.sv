// Single-cycle RV32I top. Ports and instance names follow
// NYU-Processor-Design/processor_design_vip_f26 src/*.sv.
// The PC register is 32 bits wide. Its value is the assembler's halfword
// index: assembler.py advances two halfwords per instruction, and
// instr.mem stores the low halfword first. Sequential PC and the JAL/JALR
// link are therefore PC+2. Jumps use the ALU result (mux_PC = 0).
module top #(
    parameter INSTR_MEM_FILE = "assembler/out/instr.mem",
    parameter LOAD_INSTR_MEM = 1
) (
    input logic clk
);
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] imm;
    logic [31:0] rs1_out;
    logic [31:0] rs2_out;
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [31:0] alu_out;
    logic        zflag;
    logic        branch_decision;
    logic [31:0] pc_plus_2;
    logic [31:0] pc_adder_b;
    logic [31:0] pc_adder_out;
    logic [31:0] next_pc;
    logic [31:0] dmem_out;
    logic [31:0] wb_data;

    logic        branch_decoder_on;
    logic [2:0]  funct3;
    logic        mux_PC;
    logic [1:0]  mux_reg;
    logic        RegWrite;
    logic        MemWrite;
    logic [1:0]  mux_ALUA;
    logic        mux_ALUB;
    logic [3:0]  ALU_funct;
    logic        sign_val;
    logic [1:0]  read_size;

    // 16,384 halfwords, little-endian. One instruction is mem[idx] then mem[idx+1].
    logic [15:0] imem [0:16383];
    logic [13:0] imem_idx;

    initial begin
        pc = 32'b0;
        if (LOAD_INSTR_MEM)
            $readmemh(INSTR_MEM_FILE, imem);
    end

    always @(posedge clk)
        pc <= next_pc;

    assign imem_idx = pc[13:0];
    assign instr    = {imem[imem_idx + 14'd1], imem[imem_idx]};

    control_unit u_control (
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

    instr_imm u_imm (
        .instr(instr),
        .imm(imm)
    );

    reg_file u_rf (
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .data_in(wb_data),
        .RegWrite(RegWrite),
        .clk(clk),
        .rs1_out(rs1_out),
        .rs2_out(rs2_out)
    );

    // mux_ALUA: 0 = rs1, 1 = 0 (LUI), 2 = PC (AUIPC, JAL).
    assign alu_a = (mux_ALUA == 2'd1) ? 32'b0 :
                   (mux_ALUA == 2'd2) ? pc    : rs1_out;
    // mux_ALUB: 0 = rs2, 1 = immediate. Store data stays on rs2, not this mux.
    assign alu_b = mux_ALUB ? imm : rs2_out;

    alu u_alu (
        .inA(alu_a),
        .inB(alu_b),
        .ALU_funct(ALU_funct),
        .out(alu_out),
        .zflag(zflag)
    );

    // The published ALU has no LSB port. SLT/SLTU put the compare in out[0].
    branch_decoder u_branch (
        .branch_decoder_on(branch_decoder_on),
        .funct3(funct3),
        .zflag(zflag),
        .ALU_out_lsb(alu_out[0]),
        .branch_decision(branch_decision)
    );

    assign pc_plus_2    = pc + 32'd2;
    assign pc_adder_b   = branch_decision ? imm : 32'd2;
    assign pc_adder_out = pc + pc_adder_b;
    // mux_PC: 0 = ALU jump target (JAL/JALR), 1 = PC adder (sequential or branch).
    assign next_pc      = mux_PC ? pc_adder_out : alu_out;

    data_mem u_dmem (
        .addr(alu_out),
        .data_in(rs2_out),
        .sign_val(sign_val),
        .read_size(read_size),
        .clk(clk),
        .MemWrite(MemWrite),
        .data_out(dmem_out)
    );

    // mux_reg: 0 = ALU, 1 = PC+2 (JAL/JALR link), 2 = load data.
    assign wb_data = (mux_reg == 2'd1) ? pc_plus_2 :
                     (mux_reg == 2'd2) ? dmem_out  : alu_out;
endmodule
