module data_mem(
	input logic [31:0] addr,
	input logic [31:0] data_in,
	input logic sign_val,
	input logic [1:0] read_size,
	input logic clk,
	input logic MemWrite,
	output logic [31:0] data_out
	);

	localparam int unsigned MEM_BYTES = 8192;
	logic [7:0] mem [0:MEM_BYTES-1];
	logic [12:0] byte_addr;

	assign byte_addr = addr[12:0];

	always_comb begin
		data_out = 32'b0;
		case (read_size)
			2'd0: begin
				if (addr < MEM_BYTES)
					data_out = sign_val ? 32'($signed(mem[byte_addr]))
					                    : {24'b0, mem[byte_addr]};
			end
			2'd1: begin
				if (addr <= MEM_BYTES - 2)
					data_out = sign_val
						? 32'($signed({mem[byte_addr + 13'd1], mem[byte_addr]}))
						: {16'b0, mem[byte_addr + 13'd1], mem[byte_addr]};
			end
			2'd2: begin
				if (addr <= MEM_BYTES - 4)
					data_out = {mem[byte_addr + 13'd3], mem[byte_addr + 13'd2],
					            mem[byte_addr + 13'd1], mem[byte_addr]};
			end
			default: data_out = 32'b0;
		endcase
	end

	always_ff @(posedge clk) begin
		if (MemWrite) begin
			case (read_size)
				2'd0: begin
					if (addr < MEM_BYTES)
						mem[byte_addr] <= data_in[7:0];
				end
				2'd1: begin
					if (addr <= MEM_BYTES - 2) begin
						mem[byte_addr] <= data_in[7:0];
						mem[byte_addr + 13'd1] <= data_in[15:8];
					end
				end
				2'd2: begin
					if (addr <= MEM_BYTES - 4) begin
						mem[byte_addr] <= data_in[7:0];
						mem[byte_addr + 13'd1] <= data_in[15:8];
						mem[byte_addr + 13'd2] <= data_in[23:16];
						mem[byte_addr + 13'd3] <= data_in[31:24];
					end
				end
				default: begin end
			endcase
		end
	end
endmodule
