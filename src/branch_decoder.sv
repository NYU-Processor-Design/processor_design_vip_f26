module branch_decoder (
    input logic branch_decoder_on,
    input logic [2:0] funct3,  // funct3 bits are enough to determine the type of branch instr
    input logic zflag,
    input logic ALU_out_lsb,
    output logic branch_decision  // 0: don't branch, 1: branch
);

  int errors=0;
  int tests_run = 0;
  localparam logic [2:0] FUNCT3_BEQ = 3'b000;
  localparam logic [2:0] FUNCT3_BNE = 3'b001;
  localparam logic [2:0] FUNCT3_BLT = 3'b100;
  localparam logic [2:0] FUNCT3_BGE = 3'b101;
  localparam logic [2:0] FUNCT3_BLTU = 3'b110;
  localparam logic [2:0] FUNCT3_BGEU = 3'b111;

  /*
	* Branch Decoder Module:
	* The requirements for the branch decoder are to make the correct
	* decision based on all input signals. If the decoder is off, we don't branch.
	* If it is on:
		* if logic for specific branch instr (e.g. beq) is true,
		* branch.
		* else, don't branch.
	* For the branch decoder, the funct3 bits are the following:
	* BEQ : 000
	* BNE : 001
	* BLT : 100
	* BGE : 101
	* BLTU: 110
	* BGEU: 111
	*/
  always_comb begin
    branch_decision = 1'b0;
    if (branch_decoder_on) begin
      case (funct3)
        FUNCT3_BEQ: branch_decision = zflag;
        FUNCT3_BNE: branch_decision = ~zflag;
        FUNCT3_BLT, FUNCT3_BLTU: branch_decision = ALU_out_lsb;
        FUNCT3_BGE, FUNCT3_BGEU: branch_decision = ~ALU_out_lsb;
        default: ;  // bad input
      endcase
    end
  end
endmodule
