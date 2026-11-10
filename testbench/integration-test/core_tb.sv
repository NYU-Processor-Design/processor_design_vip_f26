`timescale 1ns/1ps
// Self-checking testbench. A write to I/O register 0 is the verdict:
// 1 = PASS, (n<<1)|1 = FAIL in test n. Compile with -DIMEM_FILE=\"..\" -DDMEM_FILE=\"..\"
`ifndef IMEM_FILE
 `define IMEM_FILE "instr.mem"
`endif
`ifndef DMEM_FILE
 `define DMEM_FILE "data.mem"
`endif
module tb;
    logic        clk = 1'b0, reset = 1'b1;
    always #5 clk = ~clk;

    logic [31:0] io_addr, io_wdata;
    logic        io_we, io_re;
    logic [31:0] io_rdata;
    logic [31:0] io_regs [16] = '{default: '0};     // initialized at declaration

    always_comb io_rdata = io_regs[io_addr[5:2]];

    top #(.IMEM_INIT(`IMEM_FILE), .DMEM_INIT(`DMEM_FILE)) dut (
        .clk(clk), .reset(reset), .io_addr(io_addr), .io_wdata(io_wdata),
        .io_we(io_we), .io_re(io_re), .io_rdata(io_rdata));

    int unsigned cycles = 0;
    always_ff @(posedge clk) begin
        cycles <= cycles + 1;
        if (io_we) begin
            io_regs[io_addr[5:2]] <= io_wdata;
            if (io_addr[5:2] == 0) begin
                if (io_wdata == 32'd1) $display("PASS (%0d cycles)", cycles);
                else $display("FAIL: verdict=0x%08h (test #%0d)", io_wdata, io_wdata >> 1);
                $finish;
            end
        end
        if (cycles > 200000) begin $display("TIMEOUT"); $finish; end
    end

    initial begin repeat (4) @(posedge clk); #1 reset = 0; end
endmodule