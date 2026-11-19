// ============================================================================
// spi_slave_model.sv : behavioural SPI slave for the testbenches (not hardware)
//
//   * works in the mode given by CPOL / CPHA, MSB first, 8-bit bytes
//   * while selected (ss_n low) it answers byte k of a transfer with
//     RESP[k] (RESP holds up to 8 bytes, first byte in the top bits) and
//     records every byte it receives in rx[] (n_rx = how many)
//   * miso is only meaningful while ss_n is low; the testbench muxes it
// ============================================================================
module spi_slave_model #(
    parameter bit          CPOL = 1'b0,
    parameter bit          CPHA = 1'b0,
    parameter logic [63:0] RESP = 64'h1122_3344_5566_7788
)(
    input  logic ss_n,
    input  logic sclk,
    input  logic mosi,
    output logic miso
);
    logic [7:0] rx [16];
    int         n_rx    = 0;     // bytes received (all transfers)

    logic sclk_n;                // "normalized" clock: leading edge is always a rising edge
    assign sclk_n = sclk ^ CPOL;

    function automatic logic [7:0] resp_byte(input int k);
        return RESP[63 - 8*(k % 8) -: 8];
    endfunction

    initial begin : run
        logic [7:0] out, in;
        int bitn, k;
        miso = 1'b1;
        forever begin
            @(negedge ss_n);
            k = 0; in = '0; bitn = 7;
            out = resp_byte(k);
            if (!CPHA) miso = out[7];               // CPHA=0: first bit valid before the first edge
            forever begin
                @(posedge sclk_n or posedge ss_n);   // leading edge
                if (ss_n) break;
                if (!CPHA) in = {in[6:0], mosi};    // sample
                else       miso = out[bitn];        // shift out
                @(negedge sclk_n or posedge ss_n);   // trailing edge
                if (ss_n) break;
                if (CPHA) in = {in[6:0], mosi};     // sample
                if (bitn == 0) begin                 // byte complete
                    if (n_rx < 16) rx[n_rx] = in;
                    n_rx++;
                    k++;
                    out  = resp_byte(k);
                    bitn = 7;
                    if (!CPHA) miso = out[7];
                end else begin
                    bitn--;
                    if (!CPHA) miso = out[bitn];
                end
            end
            miso = 1'b1;
        end
    end
endmodule
