module alu_tb;
    `include "tb_utils.svh"
    logic [31:0] a, b, result;
    logic [3:0] operation;
    logic zero;
    int cases_run = 0;
    int unsigned rng = 32'h12345678;
    logic [31:0] values [0:11];
    logic [31:0] x, y;
    alu dut (.inA(a), .inB(b), .ALU_funct(operation), .out(result), .zflag(zero));

    // Independent reference: widened arithmetic, sign-bit comparison, and
    // repeated single-bit shifts rather than the DUT's variable shifts.
    function automatic logic [31:0] expected(input logic [3:0] op,
                                           input logic [31:0] lhs, rhs);
        logic [63:0] wide;
        logic [31:0] shifted;
        wide = 0;
        shifted = lhs;
        case (op)
            0, 10: begin
                wide = {32'b0, lhs} + {32'b0, rhs};
                if (op == 10) wide[0] = 0;
                expected = wide[31:0];
            end
            1: begin
                wide = {32'b0, lhs} + {32'b0, ~rhs} + 64'd1;
                expected = wide[31:0];
            end
            2, 6, 7: begin
                for (int k = 0; k < int'(rhs[4:0]); k++) begin
                    if (op == 2) shifted = {shifted[30:0], 1'b0};
                    else shifted = {(op == 7) & shifted[31], shifted[31:1]};
                end
                expected = shifted;
            end
            3: expected = {31'b0, ((lhs[31] != rhs[31]) ? lhs[31] : (lhs < rhs))};
            4: expected = {31'b0, lhs < rhs};
            5: expected = (lhs | rhs) & ~(lhs & rhs);
            8: expected = ~(~lhs & ~rhs);
            9: expected = ~(~lhs | ~rhs);
            default: expected = 0;
        endcase
    endfunction

    function automatic logic [31:0] next_random();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    task automatic check_case(input logic [3:0] op,
                              input logic [31:0] lhs, rhs, answer);
        operation = op; a = lhs; b = rhs;
        #1;
        `CHECK_EQ(result, answer, $sformatf("op=%0d a=%h b=%h", op, lhs, rhs));
        `CHECK_EQ(zero, (answer == 0), "zero flag matches result");
        cases_run++;
    endtask

    initial begin
        // Explicit anchors for operation encoding and signed/unsigned behavior.
        check_case(0, 2, 3, 5);
        check_case(0, 32'hFFFFFFFF, 1, 0);
        check_case(1, 0, 1, 32'hFFFFFFFF);
        check_case(2, 1, 31, 32'h80000000);
        check_case(2, 1, 32, 1);
        check_case(3, 32'h80000000, 1, 1);
        check_case(3, 1, 32'hFFFFFFFF, 0);
        check_case(4, 32'h80000000, 1, 0);
        check_case(5, 32'hAAAAAAAA, 32'h55555555, 32'hFFFFFFFF);
        check_case(6, 32'h80000000, 1, 32'h40000000);
        check_case(7, 32'h80000000, 1, 32'hC0000000);
        check_case(7, 32'h80000000, 31, 32'hFFFFFFFF);
        check_case(8, 32'hAAAA0000, 32'h55550000, 32'hFFFF0000);
        check_case(9, 32'hAAAA0000, 32'hFFFF5555, 32'hAAAA0000);
        check_case(10, 2, 3, 4);
        check_case(10, 32'hFFFFFFFF, 2, 0);
        values[0]=0; values[1]=1; values[2]=32'hFFFFFFFF;
        values[3]=32'h80000000; values[4]=32'h7FFFFFFF;
        values[5]=31; values[6]=32; values[7]=33;
        values[8]=32'hAAAAAAAA; values[9]=32'h55555555;
        values[10]=32'hFFFF0000; values[11]=32'h0000FFFF;
        // All codes, including undefined 11..15; every pair of boundary values.
        for (int op=0; op<16; op++) begin
            for (int i=0; i<12; i++)
                for (int j=0; j<12; j++)
                    check_case(4'(op), values[i], values[j], expected(4'(op),values[i],values[j]));
            // Every shift amount, with high bits also set in the shift operand.
            for (int shift=0; shift<32; shift++)
                check_case(4'(op), 32'h81234567, 32'hFFFF_FFE0 | 32'(shift),
                           expected(4'(op),32'h81234567,32'hFFFF_FFE0 | 32'(shift)));
            for (int i=0; i<256; i++) begin
                x=next_random(); y=next_random();
                check_case(4'(op), x, y, expected(4'(op),x,y));
            end
        end
        $display("ALU: %0d vectors, result and zero flag checked", cases_run);
        `TB_FINISH;
    end
endmodule
