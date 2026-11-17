// ============================================================================
// fpro_scratch.sv : four general read/write registers.
//
// This file has two jobs:
//   1. a harmless slot (S4_SCRATCH) that lets software test the bus by writing
//      and reading back values, and
//   2. the TEMPLATE for new cores. Copy it, rename it, replace the register
//      logic with your own hardware, and keep the slot-interface port list.
//
// Wrapper recipe (see fpro/README.md):
//   - decide the register map (offset, direction, fields)
//   - writes : decode  cs && write && (addr == N)  into an enable  (always_ff)
//   - reads  : a case on addr that selects what rd_data shows      (always_comb!)
//   - registers that the processor only reads must be driven by your hardware
// ============================================================================
module fpro_scratch (
    input  logic        clk,
    input  logic        reset,
    // slot interface
    input  logic        cs,
    input  logic        read,
    input  logic        write,
    input  logic [4:0]  addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data
);
    logic [31:0] r0, r1, r2, r3;

    // ---- write decoding ----
    logic wr_en;
    assign wr_en = cs && write;

    always_ff @(posedge clk) begin
        if (reset) begin
            r0 <= 32'd0; r1 <= 32'd0; r2 <= 32'd0; r3 <= 32'd0;
        end else if (wr_en) begin
            case (addr)
                5'd0: r0 <= wr_data;
                5'd1: r1 <= wr_data;
                5'd2: r2 <= wr_data;
                5'd3: r3 <= wr_data;
                default: ;
            endcase
        end
    end

    // ---- read multiplexing ----
    always_comb begin
        case (addr)
            5'd0:    rd_data = r0;
            5'd1:    rd_data = r1;
            5'd2:    rd_data = r2;
            5'd3:    rd_data = r3;
            default: rd_data = 32'd0;
        endcase
    end
endmodule
