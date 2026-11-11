module instr_mem #(
    parameter WORDS     = 8192,         // 32 KB
    parameter INIT_FILE = "instr.mem"
)(
    input                       clk,
    input  [$clog2(WORDS)-1:0]  word_addr, // $clog2(WORDS) gets address width for word addressing
    output reg [31:0]           instr
);
    reg [31:0] mem [0:WORDS-1];
    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0013;   // NOP
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
        instr = 32'h0000_0013; // instr reg starts at known value (NOP)
    end
    always @(posedge clk) instr <= mem[word_addr]; // sequential reads; maps to BRAM for FPGA
endmodule

