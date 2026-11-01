
`timescale 1ns/1ps

module reg_file_tb;

    logic clk = 0;
    logic [4:0] rs1, rs2, rd;
    logic [31:0] data_in;
    logic RegWrite;
    logic [31:0] rs1_out, rs2_out;

    reg_file dut (
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .data_in(data_in),
        .RegWrite(RegWrite),
        .clk(clk),
        .rs1_out(rs1_out),
        .rs2_out(rs2_out)
    );

    always #5 clk = ~clk;

    initial begin
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        data_in = 0;
        RegWrite = 0;

        #1;
        if (rs1_out !== 0 || rs2_out !== 0)
            $fatal(1, "x0 read failed");

        // Write to x5
        @(negedge clk);
        rd = 5;
        data_in = 32'h12345678;
        RegWrite = 1;

        @(posedge clk);
        #1;
        rs1 = 5;
        #1;
        if (rs1_out !== 32'h12345678)
            $fatal(1, "Write/read x5 failed");

        // Write to x10
        @(negedge clk);
        rd = 10;
        data_in = 32'hABCDEF12;

        @(posedge clk);
        #1;
        rs1 = 5;
        rs2 = 10;
        #1;
        if (rs1_out !== 32'h12345678 ||
            rs2_out !== 32'hABCDEF12)
            $fatal(1, "Dual read failed");

        // Check that RegWrite disables writing
        @(negedge clk);
        RegWrite = 0;
        rd = 5;
        data_in = 32'hFFFFFFFF;

        @(posedge clk);
        #1;
        if (rs1_out !== 32'h12345678)
            $fatal(1, "Disabled write failed");

        // Attempt to overwrite x0
        @(negedge clk);
        RegWrite = 1;
        rd = 0;
        data_in = 32'hFFFFFFFF;

        @(posedge clk);
        #1;
        rs1 = 0;
        rs2 = 0;
        #1;
        if (rs1_out !== 0 || rs2_out !== 0)
            $fatal(1, "x0 protection failed");

        $display("PASS: Register file basic tests completed");
        $finish;
    end

endmodule
