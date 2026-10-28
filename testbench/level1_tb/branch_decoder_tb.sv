module branch_decoder_tb;
  `include "tb_utils.svh"

  logic       branch_decoder_on;
  logic [2:0] funct3;
  logic       zflag;
  logic       ALU_out_lsb;
  logic       branch_decision;

  // RV32I branch funct3 encodings, taken from the spec (not the DUT)
  localparam logic [2:0] FUNCT3_BEQ  = 3'b000;
  localparam logic [2:0] FUNCT3_BNE  = 3'b001;
  localparam logic [2:0] FUNCT3_BLT  = 3'b100;
  localparam logic [2:0] FUNCT3_BGE  = 3'b101;
  localparam logic [2:0] FUNCT3_BLTU = 3'b110;
  localparam logic [2:0] FUNCT3_BGEU = 3'b111;

  branch_decoder dut (
    .branch_decoder_on(branch_decoder_on),
    .funct3(funct3),
    .zflag(zflag),
    .ALU_out_lsb(ALU_out_lsb),
    .branch_decision(branch_decision)
  );

  // apply inputs, wait for comb logic to settle, compare against expected
  task automatic check(input logic on, input logic [2:0] f3, input logic z, input logic lsb,
                       input logic expected, input string name);
    branch_decoder_on = on;
    funct3 = f3;
    zflag = z;
    ALU_out_lsb = lsb;
    #10;
    `CHECK_EQ(branch_decision, expected, $sformatf(
              "%s (on=%b funct3=%b z=%b lsb=%b)", name, on, f3, z, lsb));
  endtask

  function automatic logic expected_branch(input logic on, input logic [2:0] f3, input logic z,
                                           input logic lsb);
    if (!on) return 1'b0;

    case (f3)
      FUNCT3_BEQ:  return z;
      FUNCT3_BNE:  return ~z;
      FUNCT3_BLT:  return lsb;
      FUNCT3_BGE:  return ~lsb;
      FUNCT3_BLTU: return lsb;
      FUNCT3_BGEU: return ~lsb;
      default:     return 1'b0;
    endcase
  endfunction

  initial begin
    // ============================
    // BEQ: Branch if Equal
    // ============================
    check(1, FUNCT3_BEQ, 1, 0, 1, "BEQ");
    check(1, FUNCT3_BEQ, 0, 0, 0, "BEQ not taken");
    check(1, FUNCT3_BEQ, 1, 1, 1, "BEQ lsb=1");
    check(1, FUNCT3_BEQ, 0, 1, 0, "BEQ lsb=1");

    // ============================
    // BNE: Branch if Not Equal
    // ============================
    check(1, FUNCT3_BNE, 0, 0, 1, "BNE taken");
    check(1, FUNCT3_BNE, 1, 0, 0, "BNE not taken");
    check(1, FUNCT3_BNE, 0, 1, 1, "BNE lsb=1");
    check(1, FUNCT3_BNE, 1, 1, 0, "BNE lsb=1");

    // ============================
    // BLT: Signed Less Than
    // ============================
    check(1, FUNCT3_BLT, 0, 1, 1, "BLT taken");
    check(1, FUNCT3_BLT, 0, 0, 0, "BLT not taken");
    check(1, FUNCT3_BLT, 1, 1, 1, "BLT z=1");
    check(1, FUNCT3_BLT, 1, 0, 0, "BLT z=1");

    // ============================
    // BGE: Signed Greater or Equal
    // ============================
    check(1, FUNCT3_BGE, 0, 0, 1, "BGE taken");
    check(1, FUNCT3_BGE, 0, 1, 0, "BGE not taken");
    check(1, FUNCT3_BGE, 1, 0, 1, "BGE z=1");
    check(1, FUNCT3_BGE, 1, 1, 0, "BGE z=1");

    // ============================
    // BLTU: Unsigned Less Than
    // ============================
    check(1, FUNCT3_BLTU, 0, 1, 1, "BLTU taken");
    check(1, FUNCT3_BLTU, 0, 0, 0, "BLTU not taken");
    check(1, FUNCT3_BLTU, 1, 1, 1, "BLTU z=1");
    check(1, FUNCT3_BLTU, 1, 0, 0, "BLTU z=1");

    // ============================
    // BGEU: Unsigned Greater or Equal
    // ============================
    check(1, FUNCT3_BGEU, 0, 0, 1, "BGEU taken");
    check(1, FUNCT3_BGEU, 0, 1, 0, "BGEU not taken");
    check(1, FUNCT3_BGEU, 1, 0, 1, "BGEU z=1");
    check(1, FUNCT3_BGEU, 1, 1, 0, "BGEU z=1");

    // ============================
    // Decoder disabled
    // Must never branch when off
    // ============================
    check(0, FUNCT3_BEQ, 1, 0, 0, "Disabled BEQ");
    check(0, FUNCT3_BNE, 0, 0, 0, "Disabled BNE");
    check(0, FUNCT3_BLT, 0, 1, 0, "Disabled BLT");
    check(0, FUNCT3_BGE, 0, 0, 0, "Disabled BGE");
    check(0, FUNCT3_BLTU, 0, 1, 0, "Disabled BLTU");
    check(0, FUNCT3_BGEU, 0, 0, 0, "Disabled BGEU");

    // ============================
    // Invalid funct3 encodings
    // ============================
    check(1, 3'b010, 0, 0, 0, "Invalid 010");
    check(1, 3'b010, 1, 1, 0, "Invalid 010");
    check(1, 3'b011, 0, 0, 0, "Invalid 011");
    check(1, 3'b011, 1, 1, 0, "Invalid 011");

    // ============================
    // Enable switching
    // ============================
    check(1, FUNCT3_BEQ, 1, 0, 1, "Enable ON");
    check(0, FUNCT3_BEQ, 1, 0, 0, "Enable OFF");
    check(1, FUNCT3_BEQ, 1, 0, 1, "Enable ON again");

    // ============================
    // Instruction switching
    // ============================
    check(1, FUNCT3_BEQ, 1, 0, 1, "Switch BEQ");
    check(1, FUNCT3_BNE, 1, 0, 0, "Switch BNE");
    check(1, FUNCT3_BGE, 1, 0, 1, "Switch BGE");
    check(1, FUNCT3_BLT, 1, 0, 0, "Switch BLT");

    // ============================
    // Exhaustive testing
    // Test all 64 binary input combinations
    // ============================
    for (int i = 0; i < 64; i++) begin
      check(i[5],  // enable
            i[4:2],  // funct3
            i[1],  // zflag
            i[0],  // ALU_out_lsb
            expected_branch(i[5], i[4:2], i[1], i[0]), "Exhaustive");
    end

    `TB_FINISH;
  end
endmodule
