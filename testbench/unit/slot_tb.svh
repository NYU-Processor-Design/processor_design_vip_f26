// ============================================================================
// slot_tb.svh : shared code for the unit testbenches in tb/unit/
// `include it INSIDE a testbench module. It provides:
//
//   clk (25 MHz), reset                      the system clock and reset
//   cs, read, write, addr, wr_data, rd_data  the FPro slot bus, to connect to the core
//   do_reset()                               reset for a few clocks
//   bus_write(a, d)                          one-clock write to register a
//   bus_read(a, d)                           one-clock read of register a (like the CPU)
//   bus_write_no_cs(a, d)                    a write with cs = 0 (core must ignore it)
//   check(cond, msg)                         count a check; print msg if it failed
//   check_eq(got, exp, msg)                  same, printing both values
//   wait_clocks(n)                           wait n clock cycles
//   finish_test()                            print the verdict line and stop
//
// It needs `define TEST_NAME "xxx" before the include (used in the verdict).
// ============================================================================
localparam int CLK_NS = 40;                    // 25 MHz, the SoC clock

logic        clk = 1'b0, reset = 1'b1;
always #(CLK_NS/2) clk = ~clk;

logic        cs = 1'b0, read = 1'b0, write = 1'b0;
logic [4:0]  addr = '0;
logic [31:0] wr_data = '0;
logic [31:0] rd_data;

int errors = 0, checks = 0;

task automatic wait_clocks(input int n);
    repeat (n) @(posedge clk);
endtask

task automatic do_reset();
    @(negedge clk) reset = 1'b1;
    repeat (3) @(posedge clk);
    @(negedge clk) reset = 1'b0;
endtask

// The CPU drives the bus for exactly one clock per access. Signals change on
// the falling edge, so the core sees them stable at the next rising edge.
task automatic bus_write(input logic [4:0] a, input logic [31:0] d);
    @(negedge clk);
    cs = 1'b1; write = 1'b1; addr = a; wr_data = d;
    @(negedge clk);
    cs = 1'b0; write = 1'b0; wr_data = '0;
endtask

task automatic bus_write_no_cs(input logic [4:0] a, input logic [31:0] d);
    @(negedge clk);
    cs = 1'b0; write = 1'b1; addr = a; wr_data = d;
    @(negedge clk);
    write = 1'b0; wr_data = '0;
endtask

// rd_data must be combinational from addr: it is sampled just before the
// rising edge that ends the read cycle.
task automatic bus_read(input logic [4:0] a, output logic [31:0] d);
    @(negedge clk);
    cs = 1'b1; read = 1'b1; addr = a;
    #(CLK_NS/2 - 2);
    d = rd_data;
    @(negedge clk);
    cs = 1'b0; read = 1'b0;
endtask

task automatic check(input bit cond, input string msg);
    checks++;
    if (!cond) begin
        errors++;
        $display("  FAIL  %s   (t = %0t)", msg, $time);
    end
endtask

task automatic check_eq(input logic [31:0] got, input logic [31:0] exp, input string msg);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("  FAIL  %s : got 0x%08h, expected 0x%08h   (t = %0t)", msg, got, exp, $time);
    end
endtask

task automatic finish_test();
    if (errors == 0) $display("UNIT TEST %s: PASS (%0d checks)", `TEST_NAME, checks);
    else             $display("UNIT TEST %s: FAIL (%0d of %0d checks failed)", `TEST_NAME, errors, checks);
    $finish;
endtask

`ifdef VCD
initial begin $dumpfile({`TEST_NAME, ".vcd"}); $dumpvars(0); end
`endif
