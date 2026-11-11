// level 1 clocked simulation of top, with a RAM range check
module top_tb;
    // local timing keeps the clock independent of other modules
    timeunit 1ns;
    timeprecision 1ps;

    // one extra instruction covers the fetch after the final PC update
    localparam int SMOKE_CYCLES = 8;
    localparam int FIXTURE_INSTRUCTIONS = SMOKE_CYCLES + 1;
    localparam logic [31:0] NOP_INSTRUCTION = 32'h00000013;

    // clock stimulus and optional waveform path
    logic clk;
    logic reset;
    logic [31:0] io_addr, io_wdata;
    logic io_we, io_re;
    string wave_file;

    // instr_mem starts as all NOPs when no image is given
    top #(
        .IMEM_INIT(""),
        .DMEM_INIT("")
    ) dut (
        .clk(clk),
        .reset(reset),
        .io_addr(io_addr),
        .io_wdata(io_wdata),
        .io_we(io_we),
        .io_re(io_re),
        .io_rdata(32'h0)
    );

    // generate a waveform without replacing unfinished production modules
    initial begin
        clk = 1'b0;
        reset = 1'b1;

        // accept the existing level 1 runner's waveform destination
        if (!$value$plusargs("wave=%s", wave_file)) begin
            wave_file = "top_tb.vcd";
        end
        $dumpfile(wave_file);
        $dumpvars(0, top_tb);
        $display("top: unfinished dependencies may propagate unknown values");

        // store to the first RAM word, then load it back and load one word past the end of RAM
        #1;
        dut.INSTR_MEM.mem[0] = 32'h100000b7; // lui  x1, 0x10000
        dut.INSTR_MEM.mem[1] = 32'h05a00113; // addi x2, x0, 0x5A
        dut.INSTR_MEM.mem[2] = 32'h0020a023; // sw   x2, 0(x1)
        dut.INSTR_MEM.mem[3] = 32'h0000a203; // lw   x4, 0(x1)
        dut.INSTR_MEM.mem[4] = 32'h100041b7; // lui  x3, 0x10004
        dut.INSTR_MEM.mem[5] = 32'h0001a283; // lw   x5, 0(x3)

        // use the same cycle count for fixture sizing and clock stimulus
        #5 clk = 1'b1;
        #5 clk = 1'b0;
        reset = 1'b0;
        repeat (SMOKE_CYCLES) begin
            #5 clk = 1'b1; // 10 ns clock period
            #5 clk = 1'b0;
        end

        if (dut.u_reg_file.registers[4] !== 32'h5A) begin
            $display("FAIL RAM read: got=%h exp=0000005A", dut.u_reg_file.registers[4]); $finish;
        end

        // moved from data_mem_tb: data_mem wraps the address, top's decode must return 0 instead
        if (dut.u_reg_file.registers[5] !== 32'h0) begin
            $display("FAIL out of range read: got=%h exp=0", dut.u_reg_file.registers[5]); $finish;
        end

        $display("TEST PASSED: top compiled and completed %0d clock cycles", SMOKE_CYCLES);
        $finish;
    end
endmodule
