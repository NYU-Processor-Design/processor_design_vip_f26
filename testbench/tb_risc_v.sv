`timescale 1ns/1ps
// ============================================================================
// tb_risc_v.sv : self-checking testbench for the core alone (Verilator --timing)
//
// A write to I/O register 0 is the verdict: 1 = PASS, (n<<1)|1 = FAIL in test n.
//
// Memory images are chosen at RUN time, so one compiled model runs any program:
//     ./Vtb +IMEM=build/instr.mem +DMEM=build/data.mem
// (defaults: instr.mem / data.mem in the current directory). They are loaded
// into the core's memories 1 ps after time 0, i.e. after the memories' own
// initial blocks and before the first clock edge.
// ============================================================================
module tb;
    logic clk = 1'b0, reset = 1'b1;
    always #5 clk = ~clk;

    logic [31:0] io_addr, io_wdata, io_rdata;
    logic        io_we, io_re;
    logic [31:0] io_regs [16];
    initial for (int k = 0; k < 16; k++) io_regs[k] = '0;
    assign io_rdata = io_regs[io_addr[5:2]];

    // INIT files left empty: the images are loaded below from the plusargs
    top #(.IMEM_INIT(""), .DMEM_INIT("")) dut (
        .clk(clk), .reset(reset), .io_addr(io_addr), .io_wdata(io_wdata),
        .io_we(io_we), .io_re(io_re), .io_rdata(io_rdata));

    initial begin : load_images
        string imem_file, dmem_file;
        if (!$value$plusargs("IMEM=%s", imem_file)) imem_file = "instr.mem";
        if (!$value$plusargs("DMEM=%s", dmem_file)) dmem_file = "data.mem";
        #1ps;
        $readmemh(imem_file, dut.u_instr_mem.mem);
        $readmemh(dmem_file, dut.u_data_mem.mem);
    end

    // waveforms: build with  VFLAGS="--trace -DVCD"  (writes tb_risc_v.vcd in the current directory)
`ifdef VCD
    initial begin $dumpfile("tb_risc_v.vcd"); $dumpvars(0, tb); end
`endif

    int cycles = 0;
    always @(posedge clk) begin
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

    initial begin repeat (4) @(posedge clk); #1 reset = 1'b0; end
endmodule
