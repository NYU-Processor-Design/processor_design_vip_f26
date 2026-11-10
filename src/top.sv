// single-cycle integration with a byte-addressed PC and halfword instruction memory
module top #(
    parameter IMEM_WORDS = 8192,             // 32 KB
    parameter DMEM_WORDS = 4096,             // 16 KB
    parameter IMEM_INIT  = "instr.mem",
    parameter DMEM_INIT  = "data.mem",
    parameter DMEM_BASE  = 32'h1000_0000,
    parameter IO_BASE    = 32'hC000_0000
) (
    input  logic clk,
    input  logic reset,
    // data bus signals
    output logic [31:0] io_addr,
    output logic [31:0] io_wdata,
    output logic        io_we,
    output logic        io_re,
    input  logic [31:0] io_rdata
);
    // mux encodings match docs/control_table.csv
    localparam logic [1:0] ALUA_RS1  = 2'd0;
    localparam logic [1:0] ALUA_ZERO = 2'd1;
    localparam logic [1:0] ALUA_PC   = 2'd2;
    localparam logic [1:0] WB_ALU    = 2'd0;
    localparam logic [1:0] WB_LINK   = 2'd1;
    localparam logic [1:0] WB_MEM    = 2'd2;

    localparam logic PC_W = $clog2(IMEM_WORDS) + 2; // sets how wide the pc will be
    localparam logic DAW  = $clog2(DMEM_WORDS) + 2; // sets how wide the data address bus will be

    logic [PC_W-1:0] pc;                            // BYTE address of the current instruction
    logic [31:0]     instr;

    // controls use the encodings in docs/control_table.csv
    logic branch_decoder_on;
    logic [2:0] funct3;
    logic mux_PC;
    logic [1:0] mux_reg;
    logic RegWrite;
    logic MemWrite;
    logic MemRead;
    logic [1:0] mux_ALUA;
    logic mux_ALUB;
    logic [3:0] ALU_funct;
    logic sign_val;
    logic [1:0] mem_size;

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

    logic is_io  = (ALU_out[31:24] == IO_BASE[31:24]); // address space is IO
    logic is_ram = (ALU_out[31:DAW] == DMEM_BASE[31:DAW]); // address space is RAM
    logic run    = ~reset; // run signal true as long as reset is false

    logic [31:0] pc32 = {{(32-PC_W){1'b0}}, pc};
    logic [31:0] ram_word; // output from data_mem
    logic [31:0] load_word = is_io ? io_rdata : is_ram ? ram_word : 32'b0; // input into load_align
    logic [31:0] data_mem_out; // output from load_align

    // reuse PC plus four for sequential execution and link writeback
    logic [31:0] pc_plus4    = pc32 + 32'd4;
    logic [31:0] pc_branch   = pc32 + imm;
    logic [PC_W-1:0] pc_sel  = mux_PC ? (branch_taken ? pc_branch[PC_W-1:0] : pc_plus4[PC_W-1:0]) : alu_out[PC_W-1:0];
    logic [PC_W-1:0] pc_next = reset ? {PC_W{1'b0}} : {pc_sel[PC_W-1:2], 2'b00}; // reset returns PC to addr 0

    // advance PC on the same rising edge as register and memory writes
    always @(posedge clk) begin
        pc <= pc_next;
    end

    // select rs1, zero for LUI, or PC for AUIPC and JAL
    always_comb begin
        case (mux_ALUA)
            ALUA_RS1:  alu_a   = rs1_data;
            ALUA_ZERO: alu_a   = 32'b0;
            ALUA_PC:   alu_a   = pc32;
            default:   alu_a   = 32'b0;
        endcase
    end

    // select the second register or decoded immediate
    assign alu_b = mux_ALUB ? imm : rs2_data;

    // select the ALU result, link address, or memory data
    always_comb begin
        case (mux_reg)
            WB_ALU:  writeback_data = alu_out;
            WB_LINK: writeback_data = pc_plus4;
            WB_MEM:  writeback_data = data_mem_out;
            default: writeback_data = 32'b0;
        endcase
    end

    // the simple fact pc_next is the word_addr passed into instr_mem makes its sequential reads possible (for purposes of inferred bram)
    instr_mem #(.WORDS(IMEM_WORDS), .INIT_FILE(IMEM_INIT)) INSTR_MEM(
        .clk(clk), .word_addr(pc_next[PC_W-1:2]), .instr(instr));

    // decode execution controls from the fetched instruction
    control_unit u_control_unit (
        .instr(instr),
        .branch_decoder_on(branch_decoder_on),
        .funct3(funct3),
        .mux_PC(mux_PC),
        .mux_reg(mux_reg),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .mux_ALUA(mux_ALUA),
        .mux_ALUB(mux_ALUB),
        .ALU_funct(ALU_funct),
        .sign_val(sign_val),
        .read_size(mem_size)
    );

    // read both source registers and write the selected result
    reg_file u_reg_file (
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .data_in(writeback_data),
        .RegWrite(RegWrite & run),
        .clk(clk),
        .rs1_out(rs1_data),
        .rs2_out(rs2_data)
    );

    // reconstruct the immediate without rescaling branch or jump offsets
    instr_imm u_instr_imm (
        .instr(instr),
        .imm(imm)
    );

    // execute arithmetic and comparisons, including JALR low-bit clearing
    alu u_alu (
        .inA(alu_a),
        .inB(alu_b),
        .ALU_funct(ALU_funct),
        .out(alu_out),
        .zflag(zflag)
    );

    // combine the branch condition with ALU comparison results
    branch_decoder u_branch_decoder (
        .branch_decoder_on(branch_decoder_on),
        .funct3(funct3),
        .zflag(zflag),
        .ALU_out_lsb(alu_out[0]),
        .branch_decision(branch_taken)
    );

    // stores always use rs2, independently of the ALU operand muxes
    data_mem u_data_mem #(
        parameter WORDS     = DMEM_WORDS,
        parameter INIT_FILE = DMEM_INIT
    )(
        .clk(clk),
        .addr(alu_out),
        .data_in(rs2_data),
        .read_size(mem_size),
        .MemWrite(MemWrite & is_ram & run),
        .rd_word(ram_word)
    );

    load_align LOAD_ALIGN(.word(load_word), .byte_off(ALU_out[1:0]),
        .mem_size(mem_size), .sign_val(sign_val), .data_out(data_mem_out));

    // FPro bus signals for addr and wdata are assigned combinationally regardless of whether RAM or IO load or store
    assign io_addr  = ALU_out;
    assign io_wdata = rs2_out;
    // io_we signal only on if WE, is_io, and run are asserted, and mem_size == WORD
    // is_io is asserted if addr range is for IO
    // run signal is only asserted if reset button isn't pressed
    assign io_we    = MemWrite & is_io & (mem_size == 2'd2) & run; // SW only
    // io_re signal only on if RE, is_io, and run are asserted
    assign io_re    = MemRead & is_io & run; // LW only
endmodule
