// Level 1 reset and instruction-fetch smoke test using the current core interface.
module top_tb;
    timeunit 1ns;
    timeprecision 1ps;

    `include "tb_utils.svh"

    localparam int SMOKE_CYCLES = 4;
    localparam logic [31:0] NOP_INSTRUCTION = 32'h00000013;

    logic clk;
    logic reset;
    logic [31:0] io_addr;
    logic [31:0] io_wdata;
    logic io_we;
    logic io_re;

    // Empty image names select the memories' built-in NOP/zero initialization.
    top #(
        .IMEM_WORDS(16),
        .DMEM_WORDS(16),
        .IMEM_INIT(""),
        .DMEM_INIT("")
    ) dut (
        .clk(clk),
        .reset(reset),
        .io_addr(io_addr),
        .io_wdata(io_wdata),
        .io_we(io_we),
        .io_re(io_re),
        .io_rdata(32'b0)
    );

    initial begin
        clk = 1'b0;
        reset = 1'b1;

        repeat (2) begin
            #5 clk = 1'b1;
            #5 clk = 1'b0;
        end
        `CHECK_EQ(dut.pc, 0, "reset returns PC to zero")
        `CHECK_EQ(dut.instr, NOP_INSTRUCTION, "reset fetches a NOP")
        `CHECK_EQ(io_we, 1'b0, "reset disables IO writes")
        `CHECK_EQ(io_re, 1'b0, "reset disables IO reads")

        reset = 1'b0;
        for (int cycle = 0; cycle < SMOKE_CYCLES; cycle++) begin
            #5 clk = 1'b1;
            #1;
            `CHECK_EQ(dut.pc, (cycle + 1) * 4, "NOP advances PC by four")
            `CHECK_EQ(dut.instr, NOP_INSTRUCTION, "instruction memory supplies NOPs")
            `CHECK_EQ(io_we, 1'b0, "NOP does not write IO")
            `CHECK_EQ(io_re, 1'b0, "NOP does not read IO")
            #4 clk = 1'b0;
        end

        `TB_FINISH
    end
endmodule
