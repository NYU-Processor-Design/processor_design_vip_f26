module data_mem #(
	parameter WORDS     = 2048,            // 2048 words = 8 KB
	parameter INIT_FILE = "data.mem"
)(
	input  logic        clk,
	input  logic [31:0] addr,
	input  logic [31:0] data_in,
	input  logic        MemWrite,
	input  logic [1:0]  mem_size,
	output logic [31:0] rd_word            // aligned word containing addr
	);

	localparam ADDR_WIDTH = $clog2(WORDS); // takes the ceiling of logBase2(WORDS)

	logic [31:0] mem [0:WORDS-1];
	
	// initial values for mem
	integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'b0;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

	logic [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH+1:2]; // ignore the last 2 bits; word addressing
	assign rd_word = mem[word_addr];

	logic [3:0]  byte_en; // set combinationally for purposes of writes
	logic [31:0] write_data;

	// combinational logic before a store op
	// note: no addr misalignment support, use of replication operator to meet 32-bit requirement for write_data
	always_comb begin
        byte_en = 4'b0000; write_data = data_in;
        case (mem_size)
            2'd0: begin byte_en = 4'b0001 << addr[1:0]; write_data = {4{data_in[7:0]}};  end
            2'd1: begin byte_en = addr[1] ? 4'b1100 : 4'b0011; write_data = {2{data_in[15:0]}}; end
            2'd2: begin byte_en = 4'b1111; write_data = data_in; end
            default: ;
        endcase
	end

	always_ff @(posedge clk) begin
        if (MemWrite) begin
            if (byte_en[0]) mem[word_addr][7:0]   <= write_data[7:0];
            if (byte_en[1]) mem[word_addr][15:8]  <= write_data[15:8];
            if (byte_en[2]) mem[word_addr][23:16] <= write_data[23:16];
            if (byte_en[3]) mem[word_addr][31:24] <= write_data[31:24];
        end
	end
endmodule

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
