// ============================================================================
// i2c_slave_model.sv : behavioural I2C slave for the testbenches (not hardware)
//
// A 16-byte register memory at 7-bit address ADDR, like a small EEPROM:
//   write: START, ADDR+W, pointer, data, data, ... STOP   (stores at pointer++)
//   read : START, ADDR+W, pointer, RESTART, ADDR+R, read, read, ... (NACK) STOP
// Memory starts as mem[i] = 0xC0 + i. It ACKs its own address and every
// written byte, and does not respond to other addresses.
//
// Open-drain bus: `sda` is the actual line level (wired-AND of everybody);
// the model pulls the line low by setting sda_drive = 0.
// It also counts START (including repeated START) and STOP conditions and
// any SDA change while SCL is high that is neither (protocol errors).
// ============================================================================
module i2c_slave_model #(
    parameter logic [6:0] ADDR     = 7'h50,
    parameter int         START_NS = 1000      // ignore the bus before this (reset)
)(
    input  logic scl,
    input  logic sda,
    output logic sda_drive
);
    logic [7:0] mem [16];
    int n_start = 0, n_stop = 0, n_wr = 0, n_rd = 0;
    bit armed = 0;
    localparam int OK = 0, GOT_START = 1, GOT_STOP = 2;

    initial begin
        for (int i = 0; i < 16; i++) mem[i] = 8'hC0 + 8'(i);
        sda_drive = 1'b1;
        #(START_NS);
        armed = 1;
    end

    always @(negedge sda) if (armed && scl) n_start++;
    always @(posedge sda) if (armed && scl) n_stop++;

    // receive one byte; returns early if a START or STOP shows up instead
    task automatic rx_byte(output logic [7:0] b, output int cond);
        logic v;
        b = '0; cond = OK;
        for (int i = 0; i < 8; i++) begin
            @(posedge scl);
            v = sda;
            forever begin
                @(negedge scl or sda);
                if (!scl) break;                       // normal: clock fell
                cond = sda ? GOT_STOP : GOT_START;     // SDA moved while SCL high
                return;
            end
            b = {b[6:0], v};
        end
    endtask

    task automatic send_ack();
        sda_drive = 1'b0;
        @(posedge scl);
        @(negedge scl);
        sda_drive = 1'b1;
    endtask

    // send one byte, then read the master's ACK (returns 1 if NACKed)
    task automatic tx_byte(input logic [7:0] b, output bit nack);
        for (int i = 7; i >= 0; i--) begin
            sda_drive = b[i];
            @(posedge scl);
            @(negedge scl);
        end
        sda_drive = 1'b1;
        @(posedge scl);
        nack = sda;
        @(negedge scl);
    endtask

    initial begin : run
        logic [7:0] a, d;
        int cond, ptr;
        bit have_start, first, nack;
        ptr = 0;
        wait (armed);
        forever begin
            do @(negedge sda); while (!scl);           // wait for START
            have_start = 1;
            while (have_start) begin
                have_start = 0;
                rx_byte(a, cond);
                if (cond == GOT_START) begin have_start = 1; continue; end
                if (cond == GOT_STOP || a[7:1] != ADDR) break;   // not for us
                send_ack();
                if (!a[0]) begin                                  // master writes
                    first = 1;
                    forever begin
                        rx_byte(d, cond);
                        if (cond == GOT_START) begin have_start = 1; break; end
                        if (cond == GOT_STOP) break;
                        if (first) ptr = int'(d[3:0]);
                        else begin mem[ptr] = d; ptr = (ptr + 1) % 16; n_wr++; end
                        first = 0;
                        send_ack();
                    end
                end else begin                                    // master reads
                    forever begin
                        tx_byte(mem[ptr], nack);
                        ptr = (ptr + 1) % 16; n_rd++;
                        if (nack) break;
                    end
                end
            end
        end
    end
endmodule
