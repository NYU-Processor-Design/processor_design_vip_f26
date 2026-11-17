// ============================================================================
// fpro_bridge.sv : processor data port  ->  FPro bus  (chapter 11)
//
// FPro bus signals (all synchronous, every transaction completes in ONE clock):
//   fp_addr    [20:0]  word address (byte address bits 22:2)
//   fp_wr_data [31:0]  write data         fp_rd_data [31:0]  read data
//   fp_wr / fp_rd      1-bit strobes
//   fp_mmio_cs         selects the MMIO subsystem   (address bit 23 == 0)
//   fp_video_cs        selects the video subsystem  (address bit 23 == 1)
//
// The core's io_* port is already "bus shaped" (address + strobes + data), so
// the bridge is purely combinational: it decodes the window, splits the two
// subsystems and forwards the signals. There is no ready/handshake: a write is
// sampled by the target register at the clock edge that ends the store's
// cycle, a read is a combinational mux that must settle within that cycle.
// ============================================================================
module fpro_bridge #(
    parameter logic [31:0] BASE = 32'hC000_0000   // window base; top byte is compared
)(
    // processor side (from risc_v io_* port)
    input  logic [31:0] io_addr,
    input  logic [31:0] io_wdata,
    input  logic        io_we,
    input  logic        io_re,
    output logic [31:0] io_rdata,
    // FPro bus
    output logic        fp_mmio_cs,
    output logic        fp_video_cs,
    output logic        fp_wr,
    output logic        fp_rd,
    output logic [20:0] fp_addr,
    output logic [31:0] fp_wr_data,
    input  logic [31:0] fp_rd_data
);
    logic hit;
    assign hit = (io_addr[31:24] == BASE[31:24]); // tells us if io_addr matches the address space for IO

    // io_addr[23] == 0 means mmio selected, == 1 means video is selected
    assign fp_mmio_cs  = hit & ~io_addr[23];
    assign fp_video_cs = hit &  io_addr[23];
    assign fp_addr     = io_addr[22:2];            // bits 1:0 are 0 (word aligned)
    assign fp_wr       = io_we;
    assign fp_rd       = io_re;
    assign fp_wr_data  = io_wdata;
    assign io_rdata    = fp_rd_data;
endmodule
