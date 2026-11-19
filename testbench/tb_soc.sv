`timescale 1ns/1ps
// ============================================================================
// tb_soc.sv : whole-SoC testbench (CPU + bus + your cores + your drivers)
//
// The CPU runs a C++ test program from sw/tests/ (built by sw/run_soc_test.sh).
// Around the SoC sit models of the outside world:
//   switches / buttons, a serial terminal (UART), two SPI slaves,
//   an I2C memory at address 0x50, and a PWM measurement unit.
//
// The program reports through the finished scratch core (see sw/tests/test_util.h):
//   scratch register 3 = verdict (1 = PASS)   scratch register 2 = phase number
// The testbench adds its own checks on the pins for each test.
//
// run:  ./Vtb_soc +TEST=uart +IMEM=build/instr.mem +DMEM=build/data.mem
// ============================================================================
`include "fpro_map.svh"

module tb_soc;
    localparam int CLK_NS = 40;                   // 25 MHz
    logic clk = 1'b0, reset = 1'b1;
    always #(CLK_NS/2) clk = ~clk;

    // ---- board pins ----
    logic [3:0] sw  = 4'b0110;
    logic [3:0] btn = 4'b0000;
    logic [3:0] led;
    logic       uart_rx = 1'b1, uart_tx;
    logic       spi_sclk, spi_mosi, spi_miso;
    logic [1:0] spi_ss_n;
    logic       scl_o, sda_o, slave_sda, scl, sda;
    logic [7:0] pwm;

    assign scl = scl_o;                           // open-drain I2C bus
    assign sda = sda_o & slave_sda;

    fpro_soc #(.IMEM_INIT(""), .DMEM_INIT("")) dut (
        .clk(clk), .reset(reset),
        .sw(sw), .btn(btn), .led(led),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_ss_n(spi_ss_n),
        .i2c_scl_o(scl_o), .i2c_sda_o(sda_o), .i2c_scl_i(scl), .i2c_sda_i(sda),
        .pwm(pwm));

    // ---- program images and reset ----
    string test = "none";
    initial begin : load_images
        string imem_file, dmem_file;
        void'($value$plusargs("TEST=%s", test));
        if (!$value$plusargs("IMEM=%s", imem_file)) imem_file = "instr.mem";
        if (!$value$plusargs("DMEM=%s", dmem_file)) dmem_file = "data.mem";
        #1ps;
        $readmemh(imem_file, dut.cpu.u_instr_mem.mem);
        $readmemh(dmem_file, dut.cpu.u_data_mem.mem);
    end
    initial begin repeat (4) @(posedge clk); #1 reset = 1'b0; end

`ifdef VCD
    initial begin $dumpfile({"soc_", test, ".vcd"}); $dumpvars(0, tb_soc); end
`endif

    // ---- program -> testbench: verdict and phase via the scratch core ----
    localparam logic [31:0] SCRATCH = `BRIDGE_BASE + `S6_SCRATCH * 128;
    logic [31:0] verdict = 0;
    int          phase = 0;
    longint      phase_time [16];                 // clock count when each phase started
    longint      cycle = 0;
    always @(posedge clk) begin
        cycle <= cycle + 1;
        if (dut.io_we && dut.io_addr == SCRATCH + 12) verdict <= dut.io_wdata;
        if (dut.io_we && dut.io_addr == SCRATCH + 8) begin
            phase <= int'(dut.io_wdata);
            if (dut.io_wdata < 16) phase_time[dut.io_wdata[3:0]] <= cycle;
        end
    end

    int errors = 0;
    task automatic check(input bit cond, input string msg);
        if (!cond) begin errors++; $display("  FAIL  %s", msg); end
    endtask

    // ---- UART terminal at 156250 baud (dvsr = 9: 160 clocks per bit) ----
    localparam int BIT_NS = 160 * CLK_NS;
    logic [7:0] term [128];
    int n_term = 0, n_lines = 0;
    initial begin : uart_monitor
        logic [7:0] ch;
        #5000;
        forever begin
            @(negedge uart_tx);
            #(BIT_NS/2);
            if (uart_tx !== 1'b0) $display("  TB: UART bad start bit at %0t", $time);
            for (int k = 0; k < 8; k++) begin #(BIT_NS); ch[k] = uart_tx; end
            #(BIT_NS);
            if (uart_tx !== 1'b1) $display("  TB: UART framing error (stop bit 0) at %0t", $time);
            if (n_term < 128) term[n_term] = ch;
            n_term++;
            if (ch == 8'h0A) n_lines++;
        end
    end
    task automatic uart_send(input logic [7:0] b);
        uart_rx = 1'b0; #(BIT_NS);
        for (int j = 0; j < 8; j++) begin uart_rx = b[j]; #(BIT_NS); end
        uart_rx = 1'b1; #(BIT_NS);
    endtask

    // ---- SPI: slave 0 in mode 0, slave 1 in mode 3 ----
    logic s0_miso, s1_miso;
    spi_slave_model #(.CPOL(0), .CPHA(0), .RESP(64'h1122_3300_0000_0000)) spi0 (
        .ss_n(spi_ss_n[0]), .sclk(spi_sclk), .mosi(spi_mosi), .miso(s0_miso));
    spi_slave_model #(.CPOL(1), .CPHA(1), .RESP(64'hA55A_0000_0000_0000)) spi1 (
        .ss_n(spi_ss_n[1]), .sclk(spi_sclk), .mosi(spi_mosi), .miso(s1_miso));
    assign spi_miso = !spi_ss_n[0] ? s0_miso : !spi_ss_n[1] ? s1_miso : 1'b1;

    // ---- I2C memory at 0x50 ----
    i2c_slave_model #(.ADDR(7'h50), .START_NS(400)) i2c_mem (.scl(scl), .sda(sda), .sda_drive(slave_sda));

    // ---- PWM measurement: high clocks per channel over n clocks ----
    int pwm_high [8];
    task automatic pwm_measure(input int n);
        for (int c = 0; c < 8; c++) pwm_high[c] = 0;
        repeat (n) begin
            @(posedge clk);
            for (int c = 0; c < 8; c++) if (pwm[c]) pwm_high[c]++;
        end
    endtask

    // ---- per-test stimulus and pin checks ----
    bit tb_done = 0;
    initial begin : per_test
        wait (!reset);
        case (test)
            "gpio": begin
                wait (phase == 1);  #2000; btn[2] = 1'b1;     // press BTN2
                wait (phase == 2);  #2000; btn[2] = 1'b0;     // release it
                wait (verdict != 0);
                #2000;
                check(led == sw, $sformatf("LEDs show the switches at the end (led=%b sw=%b)", led, sw));
            end
            "timer": begin
                wait (verdict != 0);
                check(phase_time[2] - phase_time[1] >= 2500 && phase_time[2] - phase_time[1] <= 3200,
                      $sformatf("sleep_us(100) took %0d clocks; 100 us = 2500 clocks (+ a little overhead)",
                                phase_time[2] - phase_time[1]));
            end
            "uart": begin
                string exp1, exp2;
                wait (n_lines >= 1);
                #(20 * BIT_NS);
                uart_send("A");
                uart_send("C");
                wait (verdict != 0 && n_lines >= 2);
                exp1 = "hi 1234 0xBEEF -42 00000101\n";
                exp2 = "BD\n";
                begin
                    string got = "";
                    for (int i = 0; i < n_term && i < 128; i++) got = {got, string'(term[i])};
                    check(got == {exp1, exp2}, $sformatf("terminal text: expected \"hi 1234 0xBEEF -42 00000101\\nBD\\n\""));
                    $write("  terminal: ");
                    for (int i = 0; i < n_term && i < 128; i++)
                        if (term[i] == 8'h0A) $write("\\n"); else $write("%c", term[i]);
                    $write("\n");
                end
            end
            "spi": begin
                wait (verdict != 0);
                #2000;
                check(spi0.n_rx == 3 && spi0.rx[0] == 8'h5A && spi0.rx[1] == 8'hC3 && spi0.rx[2] == 8'h81,
                      "slave 0 (mode 0) received 5A C3 81");
                check(spi1.n_rx == 2 && spi1.rx[0] == 8'h3C && spi1.rx[1] == 8'h96,
                      "slave 1 (mode 3) received 3C 96");
                check(spi_ss_n == 2'b11, "both slaves deselected at the end");
                check(spi_sclk == 1'b1, "SCLK idles high (CPOL = 1) after the mode-3 transfer");
            end
            "i2c": begin
                wait (verdict != 0);
                #2000;
                check(i2c_mem.mem[2] == 8'h11 && i2c_mem.mem[3] == 8'h22 && i2c_mem.mem[4] == 8'h33,
                      "I2C memory holds 11 22 33 at 2..4");
                check(i2c_mem.n_start == 6, $sformatf("6 START conditions incl. repeated (saw %0d)", i2c_mem.n_start));
                check(i2c_mem.n_stop == 4,  $sformatf("4 STOP conditions (saw %0d)", i2c_mem.n_stop));
                check(scl === 1'b1 && sda === 1'b1, "bus released at the end");
            end
            "pwm": begin
                // program: set_freq(10000) -> dvsr = 9 -> period = 2560 clocks
                int exp_duty [8] = '{0, 1, 64, 128, 255, 256, 256, 64};
                wait (phase == 1);
                repeat (2 * 2560) @(posedge clk);
                pwm_measure(2 * 2560);
                for (int c = 0; c < 8; c++)
                    check(pwm_high[c] == exp_duty[c] * 10 * 2,
                          $sformatf("PWM channel %0d: high %0d of 5120 clocks, expected %0d (duty %0d/256 at 10 kHz)",
                                    c, pwm_high[c], exp_duty[c] * 20, exp_duty[c]));
                wait (verdict != 0);
            end
            default: begin
                $display("SOC TEST: unknown +TEST=%s", test);
                $finish;
            end
        endcase
        tb_done = 1;
    end

    // ---- verdict ----
    initial begin
        wait (tb_done);
        if (verdict != 1)
            $display("  FAIL  program reported failure code 0x%08h (bits = which checks failed; see sw/tests/%s_test.cpp)",
                     verdict & 32'h7FFF_FFFF, test);
        if (verdict == 1 && errors == 0) $display("SOC TEST %s: PASS", test);
        else                             $display("SOC TEST %s: FAIL", test);
        $finish;
    end

    initial begin
        #40_000_000;                              // 40 ms = 1 M clocks
        $display("SOC TEST %s: TIMEOUT (phase %0d, verdict 0x%08h)", test, phase, verdict);
        $finish;
    end
endmodule
