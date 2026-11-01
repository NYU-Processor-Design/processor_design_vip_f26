`timescale 1ns/1ps

// isolate control diagnostics from unfinished dependencies
module top_checks_tb #(
    parameter IMAGE = ""
);
    // idle controls leave every unused selector unknown
    logic clk = 1'b0;
    logic reg_write = 1'b0;
    logic mem_write = 1'b0;
    logic jump_select = 1'b1;
    logic branch_on = 1'b0;
    logic [1:0] writeback = 2'bxx;
    logic [1:0] source_a = 2'bxx;
    logic source_b = 1'bx;
    logic [3:0] operation = 4'bxxxx;
    logic [1:0] size = 2'bxx;
    logic load_sign = 1'bx;
    logic [2:0] condition = 3'bxxx;
    integer test_case;

    // an empty image exercises the explicit testbench initialization path
    top #(.INSTR_MEM_FILE(IMAGE)) dut (.clk(clk));

    // enable a valid arithmetic result before injecting one control fault
    task automatic arithmetic_controls;
        reg_write = 1'b1;
        writeback = 2'd0;
        source_a = 2'd0;
        source_b = 1'b0;
        operation = 4'd0;
    endtask

    // sample each scenario once after all forced controls settle
    initial begin
        force dut.u_control_unit.RegWrite = reg_write;
        force dut.u_control_unit.MemWrite = mem_write;
        force dut.u_control_unit.mux_PC = jump_select;
        force dut.u_control_unit.branch_decoder_on = branch_on;
        force dut.u_control_unit.mux_reg = writeback;
        force dut.u_control_unit.mux_ALUA = source_a;
        force dut.u_control_unit.mux_ALUB = source_b;
        force dut.u_control_unit.ALU_funct = operation;
        force dut.u_control_unit.read_size = size;
        force dut.u_control_unit.sign_val = load_sign;
        force dut.u_control_unit.funct3 = condition;
        force dut.u_alu.out = 32'd4;
        force dut.u_alu.zflag = 1'b1;
        force dut.u_reg_file.rs1_out = 32'b0;
        force dut.u_reg_file.rs2_out = 32'b0;
        force dut.u_data_mem.data_out = 32'b0;
        dut.instr_mem[0] = 16'h0013; // ADDI x0, x0, 0
        dut.instr_mem[1] = 16'h0000;

        // the runner selects either an allowed don't-care or an expected fatal error
        if (!$value$plusargs("case=%d", test_case)) begin
            $fatal(1, "top_checks: missing case selection");
        end
        case (test_case)
            0: ; // idle selectors are all irrelevant
            1: reg_write = 1'bx;
            2: mem_write = 1'bx;
            3: jump_select = 1'bx;
            4: branch_on = 1'bx;
            // enabled writeback requires a known, supported selector
            5: begin
                reg_write = 1'b1;
                writeback = 2'd3;
            end
            // arithmetic consumers require a valid source selection
            6: begin
                arithmetic_controls();
                source_a = 2'd3;
            end
            // binary ALU B selection cannot be unknown when consumed
            7: begin
                arithmetic_controls();
                source_b = 1'bx;
            end
            // operation codes above JALR_ALU are invalid
            8: begin
                arithmetic_controls();
                operation = 4'd11;
            end
            // stores consume the access size independently of writeback
            9: begin
                arithmetic_controls();
                reg_write = 1'b0;
                writeback = 2'bxx;
                mem_write = 1'b1;
                size = 2'd3;
            end
            // subword loads require the signedness control
            10: begin
                arithmetic_controls();
                writeback = 2'd2;
                size = 2'd0;
            end
            // word loads do not consume signedness
            11: begin
                arithmetic_controls();
                writeback = 2'd2;
                size = 2'd2;
            end
            // stores ignore signedness and writeback selection
            12: begin
                arithmetic_controls();
                reg_write = 1'b0;
                writeback = 2'bxx;
                mem_write = 1'b1;
                size = 2'd0;
            end
            // active branches reject reserved conditions
            13: begin
                arithmetic_controls();
                reg_write = 1'b0;
                writeback = 2'bxx;
                branch_on = 1'b1;
                condition = 3'b010;
            end
            // jumps consume the ALU even without a register write
            14: begin
                arithmetic_controls();
                reg_write = 1'b0;
                writeback = 2'bxx;
                jump_select = 1'b0;
                source_a = 2'bxx;
            end
            // selected load data still consumes the ALU address
            15: begin
                arithmetic_controls();
                writeback = 2'd2;
                size = 2'd2;
                operation = 4'bxxxx;
            end
            // enabled writeback rejects unknown selection
            16: reg_write = 1'b1;
            // unused memory controls remain irrelevant to arithmetic
            17: arithmetic_controls();
            // active branches reject unknown conditions
            18: begin
                arithmetic_controls();
                reg_write = 1'b0;
                writeback = 2'bxx;
                branch_on = 1'b1;
            end
            // an enabled load rejects an unknown size
            19: begin
                arithmetic_controls();
                writeback = 2'd2;
            end
            // a disabled branch ignores its condition
            20: condition = 3'b010;
            // link-only writeback does not consume the ALU result
            21: begin
                reg_write = 1'b1;
                writeback = 2'd1;
            end
            // unsupported scenarios are runner errors
            default: $fatal(1, "top_checks: unknown case %0d", test_case);
        endcase
        #1 clk = 1'b1;
        #1;
        $display("TEST PASSED: control case %0d", test_case);
        $finish;
    end
endmodule
