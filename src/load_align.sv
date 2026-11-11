// load_align: select byte/halfword from a word and sign/zero extend (LB LBU LH LHU LW)
module load_align(
    input  logic [31:0] word,     // comes from data_mem module output
    input  logic [1:0]  byte_off, // offset
    input  logic [1:0]  mem_size, // byte, halfword, word
    input  logic        sign_val, // signed or unsigned load
    output logic [31:0] data_out
);
    reg [7:0]  b; // byte
    reg [15:0] h; // halfword
    always_comb begin
        b = word[8*byte_off +: 8]; // indexed part-select; take 8 bits, starting at 8*byte_off and counting upwards
        h = byte_off[1] ? word[31:16] : word[15:0];
        case (mem_size)
            2'd0:    data_out = sign_val ? {{24{b[7]}},  b} : {24'b0, b};
            2'd1:    data_out = sign_val ? {{16{h[15]}}, h} : {16'b0, h};
            default: data_out = word;
        endcase
    end
endmodule

