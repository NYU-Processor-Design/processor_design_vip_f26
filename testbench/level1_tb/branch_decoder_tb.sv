module branch_decoder_tb;
  logic       branch_decoder_on;
  logic [2:0] funct3;
  logic       zflag;
  logic       ALU_out_lsb;
  logic       branch_decision;

  int errors = 0;

  // RV32I branch funct3 encodings, taken from the spec (not the DUT)
  localparam logic [2:0] FUNCT3_BEQ = 3'b000;
  localparam logic [2:0] FUNCT3_BNE = 3'b001;
  localparam logic [2:0] FUNCT3_BLT = 3'b100;
  localparam logic [2:0] FUNCT3_BGE = 3'b101;
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
  task automatic check(input logic on, input logic [2:0] f3, input logic z,
                       input logic lsb, input logic expected, input string name);
    branch_decoder_on = on;
    funct3 = f3;
    zflag = z;
    ALU_out_lsb = lsb;
    #10;
    if (branch_decision !== expected) begin
      $display("FAIL %-5s on=%b funct3=%b z=%b lsb=%b : got %b, expected %b",
               name, on, f3, z, lsb, branch_decision, expected);
      errors++;
    end else begin
      $display("PASS %-5s on=%b funct3=%b z=%b lsb=%b : %b",
               name, on, f3, z, lsb, branch_decision);
    end
  endtask

  initial begin
    $dumpfile("branch_decoder_tb.vcd");
    $dumpvars(0, branch_decoder_tb);

    // BEQ: branch when operands equal (SUB result zero)
    check(1, FUNCT3_BEQ, 1, 0, 1, "BEQ");
    // add more tests

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TEST(S) FAILED", errors);
    $finish;
  end
endmodule
