// ============================================================================
// fpro_mmio_ctrl.sv : MMIO controller (chapter 11.5)
//
// The MMIO subsystem is 64 slots x 32 registers x 32 bits. The 11-bit word
// address splits as   [10:5] = slot number   [4:0] = register offset.
//
// This module does the two system-level jobs:
//   * decoding : mmio_cs + slot number  ->  one chip-select per slot
//   * muxing   : routes the selected slot's read data back to the bus
// Write data, read/write strobes and the 5-bit register offset are simply
// broadcast to every slot (see fpro_mmio_sys.sv); a core only reacts when its
// own cs is high.
//
// N_SLOTS : how many slots exist in this build (1..64). Smaller = shorter
//           read-mux path = easier timing. Slot numbers >= N_SLOTS read as
//           UNUSED_RD.
// USED    : bit mask of slots that actually have a core attached.
// ============================================================================
module fpro_mmio_ctrl #(
    parameter int          N_SLOTS   = 16,
    parameter logic [63:0] USED      = 64'h1,
    parameter logic [31:0] UNUSED_RD = 32'hFFFF_FFFF
)(
    input  logic                           mmio_cs,
    input  logic [20:0]                    mmio_addr,
    // slot side
    output logic [N_SLOTS-1:0]             slot_cs,
    output logic [4:0]                     slot_addr,
    input  logic [N_SLOTS-1:0][31:0]       slot_rd_data,   // slot i drives slot_rd_data[i]
    // bus side
    output logic [31:0]                    mmio_rd_data
);
    logic [5:0] slot;
    assign slot      = mmio_addr[10:5];
    assign slot_addr = mmio_addr[4:0];

    for (genvar i = 0; i < N_SLOTS; i++) begin : g_cs
        // choose only the slot that mmio_addr is in addr space of; rest are cs == 0
        assign slot_cs[i] = mmio_cs & (slot == 6'(i));
    end

    // only choose slot which is within valid slot range
    // slot outside of range: mmio_rd_data == UNUSED_RD (32'hFFFF_FFFF)
    logic in_range;
    assign in_range     = (32'(slot) < N_SLOTS) && USED[slot];
    assign mmio_rd_data = in_range ? slot_rd_data[slot] : UNUSED_RD;
endmodule
