// UART slot 1: 8N1, LSB first, with independent RX and TX FIFOs
// word offsets: 0 reads {tx_full, rx_empty, rx_head}, 1 reads/writes dvsr,
// 2 queues wr_data[7:0], and 3 removes the RX head; other reads return zero
// reads have no side effects; writes require cs; full writes and empty pops drop
// each serial bit spans 16 ticks, with one tick per dvsr + 1 clocks

// helper modules share this assignment's required source file
// verilator lint_off DECLFILENAME

// asynchronous FIFO head, with one extra pointer bit to distinguish full
module fpro_fifo #(
    parameter int W  = 8,
    parameter int AW = 4
)(
    input  logic         clk,
    input  logic         reset,
    input  logic         wr,
    input  logic [W-1:0] wdata,
    input  logic         rd,
    output logic [W-1:0] rdata,
    output logic         empty,
    output logic         full
);
    // storage stays unreset so synthesis can infer distributed RAM
    logic [W-1:0] memory [0:(2**AW)-1];
    logic [AW:0] write_ptr, read_ptr;

    // the head is valid only while the FIFO is nonempty
    always_comb begin
        empty = write_ptr == read_ptr;
        full = (write_ptr[AW] != read_ptr[AW]) &&
               (write_ptr[AW-1:0] == read_ptr[AW-1:0]);
        rdata = memory[read_ptr[AW-1:0]];
    end

    // qualify each operation against the occupancy before this clock edge
    always_ff @(posedge clk) begin
        // reset discards all entries without clearing storage
        if (reset) begin
            write_ptr <= '0;
            read_ptr <= '0;
        end else begin
            // a full FIFO rejects a push even when a pop occurs together
            if (wr && !full) begin
                memory[write_ptr[AW-1:0]] <= wdata;
                write_ptr <= write_ptr + 1'b1;
            end
            // an empty FIFO rejects a pop even when a push occurs together
            if (rd && !empty) begin
                read_ptr <= read_ptr + 1'b1;
            end
        end
    end
endmodule

// sample synchronized RX at the centers of the start, data, and stop bits
module fpro_uart_rx (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,
    input  logic       rx,
    output logic       done,
    output logic [7:0] data
);
    // keep the first synchronizer stage out of the receive state machine
    (* ASYNC_REG = "TRUE" *) logic rx_meta, rx_sync;
    typedef enum logic [2:0] {IDLE, START, DATA, STOP, RECOVER} state_t;
    state_t state;
    logic [3:0] tick_count;
    logic [2:0] bit_count;

    // idle-high initialization avoids a false start after reset
    always_ff @(posedge clk) begin
        // reset both synchronizer stages together
        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    // done is a single-clock pulse, independent of the tick duration
    always_ff @(posedge clk) begin
        // reset abandons the current frame
        if (reset) begin
            state <= IDLE;
            tick_count <= '0;
            bit_count <= '0;
            data <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            // detect a start without waiting for the next baud tick
            case (state)
                IDLE: begin
                    tick_count <= '0;
                    bit_count <= '0;
                    // a low line begins start-bit qualification
                    if (!rx_sync) begin
                        state <= START;
                    end
                end
                // a short low pulse is rejected at the start-bit midpoint
                START: begin
                    if (tick) begin
                        // tick 7 is the eighth tick after start detection
                        if (tick_count == 4'd7) begin
                            tick_count <= '0;
                            // accept only a start bit that remains low
                            if (rx_sync) begin
                                state <= IDLE;
                            end else begin
                                state <= DATA;
                            end
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end
                // collect one LSB-first data bit every 16 ticks
                DATA: begin
                    if (tick) begin
                        // the output is only valid when done is asserted
                        if (tick_count == 4'd15) begin
                            tick_count <= '0;
                            data[bit_count] <= rx_sync;
                            // the last data bit is followed by a stop check
                            if (bit_count == 3'd7) begin
                                state <= STOP;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                            end
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end
                // only a high stop bit commits the received byte
                STOP: begin
                    if (tick) begin
                        // a bad frame waits for idle before accepting another start
                        if (tick_count == 4'd15) begin
                            tick_count <= '0;
                            done <= rx_sync;
                            // hold off new frames until an invalid stop returns high
                            if (rx_sync) begin
                                state <= IDLE;
                            end else begin
                                state <= RECOVER;
                            end
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end
                // a sustained break must not create extra received bytes
                RECOVER: begin
                    if (rx_sync) begin
                        state <= IDLE;
                    end
                end
                // restore the idle state after an invalid state encoding
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

// launch on a tick boundary so every transmitted bit lasts exactly 16 ticks
module fpro_uart_tx (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick,
    input  logic       start,
    input  logic [7:0] din,
    output logic       pop,
    output logic       tx
);
    // one byte is held independently of the FIFO during transmission
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    logic [3:0] tick_count;
    logic [2:0] bit_count;
    logic [7:0] shift;

    // sample and remove the same FIFO head on the accepting clock edge
    always_comb begin
        pop = !reset && tick && start &&
              ((state == IDLE) || ((state == STOP) && (tick_count == 4'd15)));
    end

    // the registered output avoids combinational glitches on the serial pin
    always_ff @(posedge clk) begin
        // reset abandons the current frame and drives the line high
        if (reset) begin
            state <= IDLE;
            tick_count <= '0;
            bit_count <= '0;
            shift <= '0;
            tx <= 1'b1;
        end else if (pop) begin
            // queued frames can follow a completed stop bit immediately
            shift <= din;
            tick_count <= '0;
            bit_count <= '0;
            state <= START;
            tx <= 1'b0;
        end else if (tick) begin
            // advance only on the shared 16x baud enable
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                end
                // hold the start level for a full bit period
                START: begin
                    if (tick_count == 4'd15) begin
                        tick_count <= '0;
                        state <= DATA;
                        tx <= shift[0]; // LSB first
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end
                // shift only after the current data bit has finished
                DATA: begin
                    if (tick_count == 4'd15) begin
                        tick_count <= '0;
                        // the eighth data bit is followed by one high stop bit
                        if (bit_count == 3'd7) begin
                            state <= STOP;
                            tx <= 1'b1;
                        end else begin
                            shift <= {1'b0, shift[7:1]};
                            bit_count <= bit_count + 1'b1;
                            tx <= shift[1];
                        end
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end
                // remain idle if no queued byte is accepted at the boundary
                STOP: begin
                    if (tick_count == 4'd15) begin
                        tick_count <= '0;
                        state <= IDLE;
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end
                // restore a safe output after an invalid state encoding
                default: begin
                    state <= IDLE;
                    tx <= 1'b1;
                end
            endcase
        end
    end
endmodule
// verilator lint_on DECLFILENAME

// connect the FPro registers, divider, FIFOs, and serial engines
module fpro_uart #(
    parameter int CLK_HZ  = 25_000_000,
    parameter int BAUD    = 9600,
    parameter int FIFO_AW = 4
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        cs,
    input  logic        read,
    input  logic        write,
    input  logic [4:0]  addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    input  logic        rx,
    output logic        tx
);
    // rounded reset divisor: 162 at 25 MHz and 9600 baud
    localparam logic [10:0] DVSR_INIT = 11'((CLK_HZ + 8*BAUD) / (16*BAUD) - 1);
    logic [10:0] dvsr, tick_count;
    logic tick, set_divisor, push_tx, pop_rx;
    logic [7:0] rx_byte, rx_head, tx_head;
    logic rx_done, rx_empty, tx_full, tx_empty, tx_pop;
    logic unused_rx_full, unused_inputs;

    // only selected writes affect registers or FIFO occupancy
    always_comb begin
        set_divisor = cs && write && (addr == 5'd1);
        push_tx = cs && write && (addr == 5'd2);
        pop_rx = cs && write && (addr == 5'd3);
        tick = !set_divisor && (tick_count == dvsr);
        unused_inputs = &{1'b0, read, wr_data[31:11]}; // reads never change state
    end

    // restart the divider on writes, including when the new divisor is smaller
    always_ff @(posedge clk) begin
        // a divisor of zero enables every clock after reset
        if (reset) begin
            dvsr <= DVSR_INIT;
            tick_count <= '0;
        end else if (set_divisor) begin
            dvsr <= wr_data[10:0];
            tick_count <= '0;
        end else if (tick) begin
            tick_count <= '0;
        end else begin
            tick_count <= tick_count + 1'b1;
        end
    end

    // completed RX frames enter the receive queue; full queues drop new bytes
    fpro_fifo #(.W(8), .AW(FIFO_AW)) rx_fifo (
        .clk(clk), .reset(reset), .wr(rx_done), .wdata(rx_byte),
        .rd(pop_rx), .rdata(rx_head), .empty(rx_empty), .full(unused_rx_full)
    );

    // software pushes TX bytes and the transmitter removes them on acceptance
    fpro_fifo #(.W(8), .AW(FIFO_AW)) tx_fifo (
        .clk(clk), .reset(reset), .wr(push_tx), .wdata(wr_data[7:0]),
        .rd(tx_pop), .rdata(tx_head), .empty(tx_empty), .full(tx_full)
    );

    // synchronize and decode the external receive pin
    fpro_uart_rx receiver (
        .clk(clk), .reset(reset), .tick(tick), .rx(rx),
        .done(rx_done), .data(rx_byte)
    );

    // transmit independently of software reads and receive traffic
    fpro_uart_tx transmitter (
        .clk(clk), .reset(reset), .tick(tick), .start(!tx_empty),
        .din(tx_head), .pop(tx_pop), .tx(tx)
    );

    // expose status and data together without removing the receive head
    always_comb begin
        case (addr)
            5'd0: rd_data = {22'd0, tx_full, rx_empty, rx_head};
            5'd1: rd_data = {21'd0, dvsr};
            default: rd_data = '0;
        endcase
    end
endmodule
