
module reg_file(
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] data_in,
    input  logic        RegWrite,
    input  logic        clk,
    output logic [31:0] rs1_out,
    output logic [31:0] rs2_out
);

    // 32 registers, each 32 bits wide
    logic [31:0] registers [0:31];

    // Two asynchronous read ports
    assign rs1_out = (rs1 == 5'd0) ? 32'b0 : registers[rs1];
    assign rs2_out = (rs2 == 5'd0) ? 32'b0 : registers[rs2];

    // Synchronous write on rising clock edge
    always_ff @(posedge clk) begin
        if (RegWrite && (rd != 5'd0)) begin
            registers[rd] <= data_in;
        end
    end

endmodule
