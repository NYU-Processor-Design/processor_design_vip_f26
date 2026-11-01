`timescale 1ns/1ps

// shared architectural trace for behavioral and completed production dependencies
// production mode observes top signals and module ports, never private storage
module integration_tb;
    `include "cycles.svh"
    logic clk = 0;
    logic [287:0] trace [0:CYCLES - 1];
    logic [287:0] row;
    integer checks = 0;
`ifdef TOP_BEHAVIORAL_MODELS
    logic [1023:0] expected_regs [0:CYCLES - 1];
    logic [511:0] expected_data [0:CYCLES - 1];
`endif

    // the assembler smoke exercises the unchanged default image path
`ifdef TOP_DEFAULT_IMAGE
    top dut(.clk(clk));
`else
    top #(.INSTR_MEM_FILE("program.mem")) dut(.clk(clk));
`endif

    // compare four-state values so unknowns cannot silently pass
    task automatic check_word(input string label_text, input logic [31:0] actual, expected);
        if (actual !== expected) begin
            $fatal(1, "%s actual=%h expected=%h pc=%h", label_text, actual, expected, dut.pc);
        end
        checks++;
    endtask

    // inspect rejected addresses without executing their zero instruction marker
    task check_fetch(input logic [31:0] address, expected);
        force dut.pc = address;
        #1;
        check_word("fetch", dut.instr, expected);
        release dut.pc;
    endtask

    // fail clearly when generated files are missing
    task automatic require_image(input string filename);
        integer handle;
        handle = $fopen(filename, "r");
        if (handle == 0) begin
            $fatal(1, "integration: cannot open '%s'; run scripts/run_top_integration.py", filename);
        end
        $fclose(handle);
    endtask

    // check each instruction before commit and its next PC after commit
    initial begin
        require_image("trace.mem");
        $readmemh("trace.mem", trace);
`ifdef TOP_BEHAVIORAL_MODELS
        require_image("regs.mem");
        require_image("data.mem");
        $readmemh("regs.mem", expected_regs);
        $readmemh("data.mem", expected_data);
`endif
        #1;
        check_word("initial PC", dut.pc, 0);
        check_fetch(0, trace[0][63:32]);
        check_fetch(2, 0);
        check_fetch(32764, LAST_WORD);
        check_fetch(32766, 0);
        check_fetch(1, 0);
        check_fetch(32768, 0);
        check_fetch(32'h80000000, 0);
        check_fetch(32'hffffffff, 0);
        check_fetch(0, trace[0][63:32]);

        // fields are PC, instruction, next PC, flags, rs1, rs2, result, address, size
        for (integer cycle = 0; cycle < CYCLES; cycle++) begin
            row = trace[cycle];
            #1;
            check_word("PC before edge", dut.pc, row[31:0]);
            check_word("instruction", dut.instr, row[63:32]);
            check_word("store enable", {31'b0, dut.MemWrite}, {31'b0, row[97]});

            // x0 writes may be suppressed by a valid production decoder
            if (!row[96] || row[43:39] != 0) begin
                check_word("register write enable", {31'b0, dut.RegWrite}, {31'b0, row[96]});
            end
            if (row[98]) check_word("rs1", dut.rs1_data, row[159:128]);
            if (row[99]) check_word("rs2", dut.rs2_data, row[191:160]);

            // verify the result at the actual register-file input port
            if (row[96] && (row[43:39] != 0 || dut.RegWrite)) begin
                check_word("register destination", {27'b0, dut.u_reg_file.rd}, {27'b0, row[43:39]});
                check_word("register result", dut.u_reg_file.data_in, row[223:192]);
            end

            // verify memory addresses and width only for actual loads or stores
            if (row[97] || (row[100] && dut.RegWrite)) begin
                check_word("memory address", dut.u_data_mem.addr, row[255:224]);
                check_word("memory width", {30'b0, dut.u_data_mem.read_size}, row[287:256]);
            end
            if (row[97]) check_word("store data", dut.u_data_mem.data_in, row[191:160]);

            // the PC must hold throughout the low phase and at the falling edge
            #1;
            check_word("PC hold before edge", dut.pc, row[31:0]);
            clk = 1;
            #1;
            check_word("PC after edge", dut.pc, row[95:64]);

`ifdef TOP_BEHAVIORAL_MODELS
            // model mode also preserves exhaustive private-state comparisons
            for (integer register_number = 0; register_number < 32; register_number++) begin
                check_word("model register", dut.u_reg_file.regs[register_number], expected_regs[cycle][register_number * 32 +: 32]);
            end
            for (integer address = 0; address < 64; address++) begin
                check_word("model byte", {24'b0, dut.u_data_mem.bytes[address]}, {24'b0, expected_data[cycle][address * 8 +: 8]});
            end
`endif
            clk = 0;
            #1;
            check_word("PC hold after falling edge", dut.pc, row[95:64]);
        end
        $display("TEST PASSED: %0d executed cycles and %0d checks", CYCLES, checks);
        $finish;
    end
endmodule
