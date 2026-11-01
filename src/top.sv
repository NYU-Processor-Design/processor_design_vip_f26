// single-cycle core with byte-addressed PC and halfword instruction storage
module top #(
    parameter INSTR_MEM_FILE = "assembler/out/instr.mem"
) (
    input logic clk
);
    // instruction memory and PC paths
    logic [15:0] instr_mem [0:16383];
    logic [13:0] instr_index;
    logic [31:0] instr;
    logic [31:0] pc;
    logic [31:0] pc_next;
    logic [31:0] pc_plus4;
    logic [31:0] pc_branch;

    // decoded controls
    logic branch_decoder_on;
    logic [2:0] funct3;
    logic mux_PC;
    logic [1:0] mux_reg;
    logic RegWrite;
    logic MemWrite;
    logic [1:0] mux_ALUA;
    logic mux_ALUB;
    logic [3:0] ALU_funct;
    logic sign_val;
    logic [1:0] read_size;

    // register, immediate, execution, and writeback paths
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] imm;
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [31:0] alu_out;
    logic zflag;
    logic branch_taken;
    logic [31:0] mem_data;
    logic [31:0] writeback_data;

`ifndef SYNTHESIS
    // simulation-only image handle
    integer image_file;
`endif

    // power-on state and assembler image, relative to the simulation directory
    initial begin
        pc = 32'b0;
        // an empty filename lets a testbench supply the memory image
        if (INSTR_MEM_FILE != "") begin
`ifndef SYNTHESIS
            image_file = $fopen(INSTR_MEM_FILE, "r");
            // missing images must fail before execution starts
            if (image_file == 0) begin
                $fatal(1, "top: cannot open instruction image '%s'", INSTR_MEM_FILE);
            end
            $fclose(image_file);
`endif
            $readmemh(INSTR_MEM_FILE, instr_mem, 0, 16383);
        end
    end

    // reject misaligned or out-of-range RV32I fetches before address truncation
    // zero marks an invalid fetch; it is not a NOP or an architectural trap
    // trap reporting and suppression of faulting writes require a core interface change
    assign instr_index = pc[14:1]; // convert byte addresses to halfword indices
    assign instr = (pc[31:15] == 17'b0 && pc[1:0] == 2'b0)
                 ? {instr_mem[{instr_index[13:1], 1'b1}], instr_mem[instr_index]}
                 : 32'b0;

    // share PC arithmetic across control flow and link writeback
    assign pc_plus4 = pc + 32'd4;
    assign pc_branch = pc + imm;
    assign pc_next = mux_PC ? (branch_taken ? pc_branch : pc_plus4) : alu_out;

    // commit the next instruction address on the shared rising edge
    always @(posedge clk) begin
        pc <= pc_next;
    end

`ifndef SYNTHESIS
    // check only controls consumed at the execution edge, preserving table don't-cares
    always @(posedge clk) begin
        // these controls always determine architectural side effects or the next PC
        assert (!$isunknown(RegWrite) && !$isunknown(MemWrite) &&
                !$isunknown(mux_PC) && !$isunknown(branch_decoder_on))
            else $fatal(1, "top: unknown execution control");

        // unused writeback selectors may remain unknown
        if (RegWrite) begin
            assert (!$isunknown(mux_reg) && mux_reg != 2'd3)
                else $fatal(1, "top: invalid writeback selector");
        end

        // jumps, branches, stores, and ALU or load writeback consume the ALU result
        if (!mux_PC || branch_decoder_on || MemWrite ||
            (RegWrite && (mux_reg == 2'd0 || mux_reg == 2'd2))) begin
            assert (!$isunknown(mux_ALUA) && mux_ALUA != 2'd3)
                else $fatal(1, "top: invalid ALU A selector");
            assert (!$isunknown(mux_ALUB))
                else $fatal(1, "top: unknown ALU B selector");
            assert (!$isunknown(ALU_funct) && ALU_funct <= 4'd10)
                else $fatal(1, "top: invalid ALU function");
        end

        // sizes matter only for stores and selected load results
        if (MemWrite || (RegWrite && mux_reg == 2'd2)) begin
            assert (!$isunknown(read_size) && read_size != 2'd3)
                else $fatal(1, "top: invalid memory access size");
        end

        // word loads and stores do not consume the sign control
        if (RegWrite && mux_reg == 2'd2 && read_size != 2'd2) begin
            assert (!$isunknown(sign_val))
                else $fatal(1, "top: unknown subword load sign");
        end

        // reserved funct3 values are invalid only when branch decoding is enabled
        if (branch_decoder_on) begin
            assert (!$isunknown(funct3) && funct3 != 3'b010 && funct3 != 3'b011)
                else $fatal(1, "top: invalid branch condition");
        end
    end
`endif

    // decode controls using the encodings in docs/control_table.csv
    control_unit u_control_unit (
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

    // read operands in parallel and write the selected result
    reg_file u_reg_file (
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .data_in(writeback_data),
        .RegWrite(RegWrite),
        .clk(clk),
        .rs1_out(rs1_data),
        .rs2_out(rs2_data)
    );

    // reconstruct the immediate without changing its byte offset
    instr_imm u_instr_imm (
        .instr(instr),
        .imm(imm)
    );

    // select rs1, zero for LUI, or PC for AUIPC and JAL
    always_comb begin
        case (mux_ALUA)
            2'd0: alu_a = rs1_data;
            2'd1: alu_a = 32'b0;
            2'd2: alu_a = pc;
            default: alu_a = 32'b0;
        endcase
    end

    // select the register or immediate operand
    assign alu_b = mux_ALUB ? imm : rs2_data;

    // execute arithmetic, comparisons, and JALR low-bit clearing
    alu u_alu (
        .inA(alu_a),
        .inB(alu_b),
        .ALU_funct(ALU_funct),
        .out(alu_out),
        .zflag(zflag)
    );

    // combine comparison flags with the conditional branch control
    branch_decoder u_branch_decoder (
        .branch_decoder_on(branch_decoder_on),
        .funct3(funct3),
        .zflag(zflag),
        .ALU_out_lsb(alu_out[0]),
        .branch_decision(branch_taken)
    );

    // stores always use rs2, independent of the ALU immediate selection
    data_mem u_data_mem (
        .addr(alu_out),
        .data_in(rs2_data),
        .sign_val(sign_val),
        .read_size(read_size),
        .clk(clk),
        .MemWrite(MemWrite),
        .data_out(mem_data)
    );

    // select the ALU result, return address, or loaded data
    always_comb begin
        case (mux_reg)
            2'd0: writeback_data = alu_out;
            2'd1: writeback_data = pc_plus4;
            2'd2: writeback_data = mem_data;
            default: writeback_data = 32'b0;
        endcase
    end
endmodule
