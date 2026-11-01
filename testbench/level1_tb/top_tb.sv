`timescale 1ns/1ps

// isolate unfinished modules while exercising the top wiring and real decoders
module top_tb;
    `include "tb_utils.svh"

    // clock and controllable child outputs
    logic clk = 1'b0;
    logic drive_branch = 1'b0;
    logic [2:0] drive_funct3 = 3'b0;
    logic drive_mux_pc = 1'b1;
    logic [1:0] drive_mux_reg = 2'b0;
    logic drive_reg_write = 1'b0;
    logic drive_mem_write = 1'b0;
    logic [1:0] drive_mux_a = 2'b0;
    logic drive_mux_b = 1'b0;
    logic [3:0] drive_alu_funct = 4'b0;
    logic drive_sign = 1'b0;
    logic [1:0] drive_size = 2'b0;
    logic [31:0] drive_rs1 = 32'h89abcdef;
    logic [31:0] drive_rs2 = 32'h76543210;
    logic [31:0] drive_alu = 32'h13579bde;
    logic drive_zero = 1'b0;
    logic [31:0] drive_mem = 32'hfedcba98;
    logic [31:0] probe_pc = 32'b0;
    logic [31:0] random_state = 32'h4d595df4;

    // sparse fixture checks loading and addressing, not whole-program execution
    // untouched gaps remain unknown in four-state simulation
    top #(.INSTR_MEM_FILE("testbench/level1_tb/top_instr.mem")) dut (.clk(clk));

    // write one instruction in the assembler's low-halfword-first order
    task automatic put_instruction(input int address, input logic [31:0] instruction);
        dut.instr_mem[address / 2] = instruction[15:0];
        dut.instr_mem[address / 2 + 1] = instruction[31:16];
    endtask

    // restore legal controls before clocking a scenario
    task automatic idle_controls;
        drive_branch = 1'b0;
        drive_funct3 = 3'b000;
        drive_mux_pc = 1'b1;
        drive_mux_reg = 2'd0;
        drive_reg_write = 1'b0;
        drive_mem_write = 1'b0;
        drive_mux_a = 2'd0;
        drive_mux_b = 1'b0;
        drive_alu_funct = 4'd0;
        drive_sign = 1'b0;
        drive_size = 2'd0;
    endtask

    // verify pre-edge stability, shared clocks, and the rising-edge PC update
    task automatic tick(input logic [31:0] expected_pc);
        logic [31:0] held_pc;
        held_pc = dut.pc;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "PC holds before rising edge")
        clk = 1'b1;
        #1;
        `CHECK_EQ(dut.u_reg_file.clk, 1'b1, "register clock high")
        `CHECK_EQ(dut.u_data_mem.clk, 1'b1, "memory clock high")
        `CHECK_EQ(dut.pc, expected_pc, "rising-edge PC")
        clk = 1'b0;
        #1;
        `CHECK_EQ(dut.u_reg_file.clk, 1'b0, "register clock low")
        `CHECK_EQ(dut.u_data_mem.clk, 1'b0, "memory clock low")
        `CHECK_EQ(dut.pc, expected_pc, "falling edge holds PC")
    endtask

    // reach each scenario through the jump path without forcing PC
    task automatic jump_to(input logic [31:0] address);
        logic [31:0] held_pc;
        held_pc = dut.pc;
        idle_controls();
        drive_mux_pc = 1'b0;
        drive_alu = address;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "jump selection holds PC before edge")
        tick(address);
    endtask

    // reproducible xorshift32 patterns vary every datapath independently
    function automatic logic [31:0] next_pattern(input logic [31:0] value);
        logic [31:0] state;
        state = value ^ (value << 13);
        state = state ^ (state >> 17);
        next_pattern = state ^ (state << 5);
    endfunction

    // observe child inputs with changing sources and independent mux selections
    task automatic check_data_paths(
        input logic [31:0] rs1_value,
        input logic [31:0] rs2_value,
        input logic [31:0] alu_value,
        input logic [31:0] mem_value
    );
        logic [31:0] expected_a;
        logic [31:0] expected_writeback;
        logic [31:0] held_pc;
        held_pc = dut.pc;
        drive_rs1 = rs1_value;
        drive_rs2 = rs2_value;
        drive_alu = alu_value;
        drive_mem = mem_value;
        #1;
        `CHECK_EQ(dut.u_data_mem.data_in, rs2_value, "changing store data")
        `CHECK_EQ(dut.u_data_mem.addr, alu_value, "changing memory address")

        // cross every operand selector, including the reserved zero fallback
        for (int select_a = 0; select_a < 4; select_a++) begin
            drive_mux_a = 2'(select_a);
            expected_a = select_a == 0 ? rs1_value :
                         select_a == 2 ? held_pc : 32'b0;
            // immediate selection must not alter the store operand
            for (int select_b = 0; select_b < 2; select_b++) begin
                drive_mux_b = 1'(select_b);
                #1;
                `CHECK_EQ(dut.u_alu.inA, expected_a, "changing ALU A data")
                `CHECK_EQ(dut.u_alu.inB, select_b == 0 ? rs2_value : dut.imm,
                          "changing ALU B data")
                `CHECK_EQ(dut.u_data_mem.data_in, rs2_value, "independent store operand")
            end
        end

        // compare each writeback source directly with its driven value
        for (int select_reg = 0; select_reg < 4; select_reg++) begin
            drive_mux_reg = 2'(select_reg);
            expected_writeback = select_reg == 0 ? alu_value :
                                 select_reg == 1 ? held_pc + 32'd4 :
                                 select_reg == 2 ? mem_value : 32'b0;
            #1;
            `CHECK_EQ(dut.u_reg_file.data_in, expected_writeback, "changing writeback data")
        end
        `CHECK_EQ(dut.pc, held_pc, "data and mux changes hold PC")
    endtask

    // reject asynchronous PC updates at either clock level
    task automatic check_pc_hold;
        logic [31:0] held_pc;
        idle_controls();
        held_pc = dut.pc;
        #1;
        drive_alu = 32'h600;
        drive_mux_pc = 1'b0;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "low clock jump selection holds PC")
        drive_alu = 32'h604;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "low clock target change holds PC")
        drive_mux_pc = 1'b1;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "low clock sequential selection holds PC")
        clk = 1'b1;
        #1;
        held_pc = held_pc + 32'd4;
        `CHECK_EQ(dut.pc, held_pc, "hold test rising-edge PC")

        // change the target and selection while the clock stays high
        drive_alu = 32'h700;
        drive_mux_pc = 1'b0;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "high clock jump selection holds PC")
        drive_alu = 32'h704;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "high clock target change holds PC")
        drive_mux_pc = 1'b1;
        drive_branch = 1'b1;
        drive_zero = 1'b1;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "high clock branch selection holds PC")
        clk = 1'b0;
        #1;
        `CHECK_EQ(dut.pc, held_pc, "hold test falling-edge PC")
        idle_controls();
    endtask

    // encode branch offsets independently of the immediate decoder
    function automatic logic [31:0] branch_instruction(
        input logic [2:0] branch_funct3,
        input logic [12:0] offset
    );
        assert (offset[0] == 1'b0)
            else $fatal(1, "top_tb: branch offset must be even");
        branch_instruction = {offset[12], offset[10:5], 5'd9, 5'd17,
                              branch_funct3, offset[4:1], offset[11], 7'b1100011};
    endfunction

    // check a real branch decode, target, and committed PC
    task automatic check_branch(
        input logic [2:0] branch_funct3,
        input logic zero_flag,
        input logic less_than,
        input logic expected_taken,
        input logic [12:0] offset
    );
        logic [31:0] expected_imm;
        logic [31:0] expected_pc;
        expected_imm = {{19{offset[12]}}, offset};
        expected_pc = expected_taken ? 32'h100 + expected_imm : 32'h104;
        put_instruction('h100, branch_instruction(branch_funct3, offset));
        jump_to(32'h100);
        drive_mux_pc = 1'b1;
        drive_branch = 1'b1;
        drive_funct3 = branch_funct3;
        drive_zero = zero_flag;
        drive_alu = {31'b0, less_than};
        #1;
        `CHECK_EQ(dut.imm, expected_imm, "branch immediate")
        `CHECK_EQ(dut.branch_taken, expected_taken, "branch decision")
        `CHECK_EQ(dut.pc_branch, 32'h100 + expected_imm, "branch target")
        `CHECK_EQ(dut.pc_next, expected_pc, "branch next PC")
        // reserved conditions are checked combinationally without committing them
        if (branch_funct3 != 3'b010 && branch_funct3 != 3'b011) begin
            tick(expected_pc);
        end
    endtask

    // cross both flags independently for every branch condition and offset
    task automatic branch_cases(input logic [12:0] offset);
        logic expected_taken;
        // reserved encodings exercise the decoder's safe fallback without a clock
        for (int condition = 0; condition < 8; condition++) begin
            // each flag varies without depending on the other flag
            for (int flags = 0; flags < 4; flags++) begin
                // derive the expected branch decision from the selected condition
                case (condition)
                    0: expected_taken = flags[0];
                    1: expected_taken = !flags[0];
                    4, 6: expected_taken = flags[1];
                    5, 7: expected_taken = !flags[1];
                    default: expected_taken = 1'b0;
                endcase
                check_branch(3'(condition), flags[0], flags[1], expected_taken, offset);
            end
        end
    endtask

    // force unfinished child outputs so disconnected top wiring remains detectable
    initial begin
        force dut.u_control_unit.branch_decoder_on = drive_branch;
        force dut.u_control_unit.funct3 = drive_funct3;
        force dut.u_control_unit.mux_PC = drive_mux_pc;
        force dut.u_control_unit.mux_reg = drive_mux_reg;
        force dut.u_control_unit.RegWrite = drive_reg_write;
        force dut.u_control_unit.MemWrite = drive_mem_write;
        force dut.u_control_unit.mux_ALUA = drive_mux_a;
        force dut.u_control_unit.mux_ALUB = drive_mux_b;
        force dut.u_control_unit.ALU_funct = drive_alu_funct;
        force dut.u_control_unit.sign_val = drive_sign;
        force dut.u_control_unit.read_size = drive_size;
        force dut.u_reg_file.rs1_out = drive_rs1;
        force dut.u_reg_file.rs2_out = drive_rs2;
        force dut.u_alu.out = drive_alu;
        force dut.u_alu.zflag = drive_zero;
        force dut.u_data_mem.data_out = drive_mem;
        #1;

        // check power-on state, image loading, and instruction field routing
        `CHECK_EQ($size(dut.instr_mem), 16384, "instruction memory depth")
        `CHECK_EQ($bits(dut.instr_mem[0]), 16, "instruction memory width")
        `CHECK_EQ(dut.pc, 32'b0, "PC starts at zero")
        `CHECK_EQ(dut.instr, 32'hff088293, "first little-endian instruction")
        `CHECK_EQ(dut.u_control_unit.instr, 32'hff088293, "control instruction")
        `CHECK_EQ(dut.u_instr_imm.instr, 32'hff088293, "immediate instruction")
        `CHECK_EQ(dut.u_reg_file.rs1, 5'd17, "rs1 field")
        `CHECK_EQ(dut.u_reg_file.rs2, 5'd16, "rs2 field")
        `CHECK_EQ(dut.u_reg_file.rd, 5'd5, "rd field")
        `CHECK_EQ(dut.imm, 32'hfffffff0, "signed I immediate")

`ifndef VERILATOR
        // a sparse gap is not an implicit NOP or initialized zero
        `CHECK($isunknown(dut.instr_mem[8]), "sparse fixture leaves gaps unknown")
`endif

        // independently cross enables, sign, and size for each ALU control value
        // reserved encodings are routing probes and are never clocked
        for (int function_code = 0; function_code < 16; function_code++) begin
            drive_alu_funct = 4'(function_code);
            // every combination separates enable wiring from size and sign bits
            for (int controls = 0; controls < 32; controls++) begin
                drive_reg_write = controls[4];
                drive_mem_write = controls[3];
                drive_sign = controls[2];
                drive_size = controls[1:0];
                #1;
                `CHECK_EQ(dut.u_alu.ALU_funct, 4'(function_code), "ALU function forwarding")
                `CHECK_EQ(dut.u_data_mem.read_size, controls[1:0], "memory size forwarding")
                `CHECK_EQ(dut.u_data_mem.sign_val, controls[2], "load sign forwarding")
                `CHECK_EQ(dut.u_reg_file.RegWrite, controls[4], "register write forwarding")
                `CHECK_EQ(dut.u_data_mem.MemWrite, controls[3], "memory write forwarding")
            end
        end
        idle_controls();

        // exercise every ALU operand selection including the reserved encoding
        drive_mux_a = 2'd0;
        drive_mux_b = 1'b0;
        #1;
        `CHECK_EQ(dut.u_alu.inA, drive_rs1, "ALU rs1 input")
        `CHECK_EQ(dut.u_alu.inB, drive_rs2, "ALU rs2 input")
        drive_mux_a = 2'd1;
        drive_mux_b = 1'b1;
        #1;
        `CHECK_EQ(dut.u_alu.inA, 32'b0, "LUI zero input")
        `CHECK_EQ(dut.u_alu.inB, 32'hfffffff0, "ALU immediate input")
        `CHECK_EQ(dut.u_data_mem.data_in, drive_rs2, "store retains rs2")
        `CHECK_EQ(dut.u_data_mem.addr, drive_alu, "memory ALU address")
        drive_mux_a = 2'd3;
        #1;
        `CHECK_EQ(dut.u_alu.inA, 32'b0, "reserved ALU A selection")

        // check all writeback choices at the register file input
        drive_mux_reg = 2'd0;
        #1;
        `CHECK_EQ(dut.u_reg_file.data_in, drive_alu, "ALU writeback")
        drive_mux_reg = 2'd1;
        #1;
        `CHECK_EQ(dut.u_reg_file.data_in, 32'd4, "link writeback")
        drive_mux_reg = 2'd2;
        #1;
        `CHECK_EQ(dut.u_reg_file.data_in, drive_mem, "load writeback")
        drive_mux_reg = 2'd3;
        #1;
        `CHECK_EQ(dut.u_reg_file.data_in, 32'b0, "reserved writeback selection")
        `CHECK_EQ(dut.pc, 32'b0, "combinational changes hold PC")

`ifndef VERILATOR
        // unknown selectors exercise defaults without claiming two-state coverage
        drive_mux_a = 2'bxx;
        drive_mux_reg = 2'bxx;
        #1;
        `CHECK_EQ(dut.u_alu.inA, 32'b0, "unknown ALU A selection")
        `CHECK_EQ(dut.u_reg_file.data_in, 32'b0, "unknown writeback selection")
        drive_mux_a = 2'bz0;
        drive_mux_reg = 2'b0z;
        #1;
        `CHECK_EQ(dut.u_alu.inA, 32'b0, "high-impedance ALU A selection")
        `CHECK_EQ(dut.u_reg_file.data_in, 32'b0, "high-impedance writeback selection")
`endif

        // walk each bit through every input and its complement
        for (int bit_index = 0; bit_index < 32; bit_index++) begin
            check_data_paths(32'b1 << bit_index, ~(32'b1 << bit_index),
                             32'b1 << ((bit_index + 7) % 32),
                             ~(32'b1 << ((bit_index + 19) % 32)));
            check_data_paths(~(32'b1 << bit_index), 32'b1 << bit_index,
                             ~(32'b1 << ((bit_index + 7) % 32)),
                             32'b1 << ((bit_index + 19) % 32));
        end
        check_data_paths(32'b0, 32'hffffffff, 32'h55555555, 32'haaaaaaaa);
        check_data_paths(32'hffffffff, 32'b0, 32'haaaaaaaa, 32'h55555555);

        // independently step deterministic patterns for each data source
        for (int sample = 0; sample < 64; sample++) begin
            random_state = next_pattern(random_state);
            drive_rs1 = random_state;
            random_state = next_pattern(random_state);
            drive_rs2 = random_state;
            random_state = next_pattern(random_state);
            drive_alu = random_state;
            random_state = next_pattern(random_state);
            check_data_paths(drive_rs1, drive_rs2, drive_alu, random_state);
        end

        // advance sequentially and use a nonzero PC as the ALU source
        idle_controls();
        tick(32'd4);
        drive_mux_a = 2'd2;
        #1;
        `CHECK_EQ(dut.instr, 32'h123453b7, "second little-endian instruction")
        `CHECK_EQ(dut.u_alu.inA, 32'd4, "ALU PC input")
        `CHECK_EQ(dut.imm, 32'h12345000, "U immediate")
        tick(32'd8);

        // keep a stable PC while instruction memory and decoded fields change
        put_instruction(8, 32'hffba2623); // sw x27, -20(x20)
        #1;
        `CHECK_EQ(dut.instr, 32'hffba2623, "combinational memory update")
        `CHECK_EQ(dut.u_reg_file.rs1, 5'd20, "changed rs1 field")
        `CHECK_EQ(dut.u_reg_file.rs2, 5'd27, "changed rs2 field")
        `CHECK_EQ(dut.u_reg_file.rd, 5'd12, "changed rd field")
        `CHECK_EQ(dut.imm, 32'hffffffec, "signed S immediate")
        `CHECK_EQ(dut.pc, 32'd8, "memory change holds PC")

        // cover forward and backward conditional control flow
        branch_cases(13'd12);
        branch_cases(13'h1ff0); // -16 in the branch immediate width

        // disable a true branch condition and keep sequential execution
        put_instruction('h100, branch_instruction(3'b000, 13'd12));
        jump_to(32'h100);
        drive_mux_pc = 1'b1;
        drive_branch = 1'b0;
        drive_funct3 = 3'b000;
        drive_zero = 1'b1;
        #1;
        `CHECK_EQ(dut.branch_taken, 1'b0, "disabled branch")
        tick(32'h104);

        // verify JAL operands and link writeback with conflicting branch control
        put_instruction('h200, 32'h010000ef); // jal x1, 16
        jump_to(32'h200);
        drive_mux_a = 2'd2;
        drive_mux_b = 1'b1;
        drive_mux_reg = 2'd1;
        drive_reg_write = 1'b1;
        drive_alu_funct = 4'd10;
        drive_alu = 32'h240; // distinct from PC plus immediate to expose mux priority
        drive_branch = 1'b1;
        drive_zero = 1'b1;
        #1;
        `CHECK_EQ(dut.u_alu.inA, 32'h200, "JAL PC operand")
        `CHECK_EQ(dut.u_alu.inB, 32'd16, "JAL immediate operand")
        `CHECK_EQ(dut.u_reg_file.data_in, 32'h204, "JAL link")
        `CHECK_EQ(dut.branch_taken, 1'b1, "simultaneous branch condition")
        `CHECK_EQ(dut.pc_next, 32'h240, "jump PC selection")
        tick(32'h240);

        // use the ALU's aligned JALR target without replacing it with PC arithmetic
        put_instruction('h300, 32'hffd888e7); // jalr x17, -3(x17)
        jump_to(32'h300);
        drive_mux_a = 2'd0;
        drive_mux_b = 1'b1;
        drive_mux_reg = 2'd1;
        drive_reg_write = 1'b1;
        drive_alu_funct = 4'd10;
        drive_rs1 = 32'h404;
        drive_alu = 32'h400;
        #1;
        `CHECK_EQ(dut.u_alu.inA, 32'h404, "JALR register operand")
        `CHECK_EQ(dut.u_alu.inB, 32'hfffffffd, "JALR signed immediate")
        `CHECK_EQ(dut.u_reg_file.data_in, 32'h304, "JALR link")
        tick(32'h400);

        // mux and data changes must not commit PC at either clock level
        check_pc_hold();

        // force PC only for fetch addressing; no invalid instruction is executed
        force dut.pc = probe_pc;
        probe_pc = 32'h7ffc;
        #1;
        `CHECK_EQ(dut.instr, 32'h1234abcd, "last complete instruction")
        probe_pc = 32'h7ffe;
        #1;
        `CHECK_EQ(dut.instr, 32'b0, "end-overrun fetch")
        probe_pc = 32'h8000;
        #1;
        `CHECK_EQ(dut.instr, 32'b0, "first out-of-range fetch")
        probe_pc = 32'h10000;
        #1;
        `CHECK_EQ(dut.instr, 32'b0, "high address cannot alias memory")
        probe_pc = 32'hfffffffc;
        #1;
        `CHECK_EQ(dut.instr, 32'b0, "highest aligned address")
        `CHECK_EQ(dut.pc_plus4, 32'b0, "PC increment wraps at 32 bits")

        // isolate every rejected high bit against a known nonzero word at address zero
        for (int bit_index = 15; bit_index < 32; bit_index++) begin
            probe_pc = 32'b1 << bit_index;
            #1;
            `CHECK_EQ(dut.instr, 32'b0, "isolated upper address cannot alias memory")
        end

        // distinguish valid address lines with unique words before probing each line
        for (int bit_index = 2; bit_index < 15; bit_index++) begin
            put_instruction(1 << bit_index, 32'ha5005a00 ^ (32'h00010001 * 32'(bit_index)));
            put_instruction('h7ffc ^ (1 << bit_index),
                            32'h5a00a500 ^ (32'h00010001 * 32'(bit_index)));
        end

        // walking ones and zeros expose missing, swapped, or aliased address bits
        for (int bit_index = 2; bit_index < 15; bit_index++) begin
            probe_pc = 32'b1 << bit_index;
            #1;
            `CHECK_EQ(dut.instr, 32'ha5005a00 ^ (32'h00010001 * 32'(bit_index)),
                      "isolated valid address bit")
            probe_pc = 32'h7ffc ^ (32'b1 << bit_index);
            #1;
            `CHECK_EQ(dut.instr, 32'h5a00a500 ^ (32'h00010001 * 32'(bit_index)),
                      "isolated cleared address bit")
        end

        // reject every nonzero low-bit alignment pattern in RV32I
        for (int address = 1; address < 4; address++) begin
            probe_pc = 32'(address);
            #1;
            `CHECK_EQ(dut.instr, 32'b0, "misaligned fetch")
        end
        probe_pc = 32'b0;
        #1;
        `CHECK_EQ(dut.instr, 32'hff088293, "fetch recovers at first address")
        release dut.pc;
        `TB_FINISH
    end
endmodule
