// Copy to <module>_tb.sv, rename the module to <module>_tb, and replace the
// stand-in logic with your DUT.
module tb_template;
    `include "tb_utils.svh"

    logic [31:0] a, b, sum;

    // alu dut (.inA(a), .inB(b), .ALU_funct(4'd0), .out(sum), .zflag());
    assign sum = a + b;

    initial begin
        a = 32'd2;
        b = 32'd3;
        #1;
        `CHECK_EQ(sum, 32'd5, "2 + 3");

        a = 32'hFFFF_FFFF;
        b = 32'd1;
        #1;
        `CHECK_EQ(sum, 32'd0, "wraps on overflow");
        `CHECK(sum == 0, "sum is zero");

        `TB_FINISH;
    end
endmodule
