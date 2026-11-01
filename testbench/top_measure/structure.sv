// preserve the top hierarchy for partial structural checks without an image
module top_structure(input wire clk);
    // unfinished child modules remain explicit blackboxes in the Yosys script
    top #(.INSTR_MEM_FILE("")) dut (.clk(clk));
endmodule
