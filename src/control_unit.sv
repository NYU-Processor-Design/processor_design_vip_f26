module control_unit(
	input logic [31:0] instr,
	output logic branch_decoder_on,
	output logic [2:0] funct3, // funct3 output is specifically for the branch decoder
	output logic mux_PC,
	output logic [1:0] mux_reg,
	output logic RegWrite,
	output logic MemWrite,
	output logic [1:0] mux_ALUA,
	output logic mux_ALUB,
	output logic [3:0] ALU_funct,
	output logic sign_val,
	output logic [1:0] read_size
	
	);
	/*
	* Control Unit Module:
	* The control unit's requirements are to decode the given instruction
	* combinationally and to output the appropriate control signals given
	* a specific type of instruction. The logic can get a bit cumbersome,
	* so refer heavily to "MICRO-ARCHITECTURE/RV32I_INSTRUCTIONS.pdf" in
	* the shared google drive to group instructions together for simpler
	* decoding. Make sure to avoid inferred latching when using
	* combinational logic here (e.g. always @(*) must be handled with
	* care), and to distribute the work fairly in order to meet our goals.
	*/


	// Defining Instructions 
	logic [6:0] opcode;
	
	assign opcode = instr[6:0];
	assign funct3 = instr[14:12];
	

	//Deciding Instructions 
	always_comb begin 
		branch_decoder_on = 1'b0;
		mux_PC = 1'b1;
		mux_reg = 2'b00;
		RegWrite = 1'b0;
		MemWrite = 1'b0;
		mux_ALUA = 2'b00;
		mux_ALUB = 1'b0;
		ALU_funct = 4'b0000;
		sign_val  = 1'b0;
		read_size = 2'b00;

		case(opcode) 
			7'b0110111: begin // LUI
				branch_decoder_on = 1'b0;
				mux_PC = 1'b1;
				mux_reg = 2'b00;
				RegWrite = 1'b1;
				MemWrite = 1'b0;
				mux_ALUA = 2'b01;
				mux_ALUB = 1'b1;
				ALU_funct = 4'b0000;
				sign_val  = 1'b0;
				read_size = 2'b00;


			end 
			7'b0010111: begin // AUIPC
				branch_decoder_on = 1'b0;
				mux_PC = 1'b1;
				mux_reg = 2'b00;
				RegWrite = 1'b1;
				MemWrite = 1'b0;
				mux_ALUA = 2'b10;
				mux_ALUB = 1'b1;
				ALU_funct = 4'b0000;
				sign_val  = 1'b0;
				read_size = 2'b00;

			end 
			7'b1101111: begin // JAL
				branch_decoder_on = 1'b0;
				mux_PC = 1'b0;
				mux_reg = 2'b01;
				RegWrite = 1'b1;
				MemWrite = 1'b0;
				mux_ALUA = 2'b10;
				mux_ALUB = 1'b1;
				ALU_funct = 4'b1010;
				sign_val  = 1'b0;
				read_size = 2'b10;
			end 
			7'b1100111: begin // JALR
				case(funct3) 
					3'b000: begin
						branch_decoder_on = 1'b0;
						mux_PC = 1'b0;
						mux_reg = 2'b01;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b1010;
						sign_val  = 1'b0;
						read_size = 2'b10;
				
					end

					default: begin 
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end 
				endcase
			end 
			
			7'b0000011: begin // Loads
				case(funct3)
					3'b000: begin  // Load Byte
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b10;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b1;
						read_size = 2'b00;

					end
					
					3'b001: begin // Load Halfword
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b10;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b1;
						read_size = 2'b01;
					end 

					3'b010: begin // Load Word 
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b10;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b1;
						read_size = 2'b10;
					end 

					3'b100: begin  // Load Byte Unsigned
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b10;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end

					3'b101: begin  // Load Halfword Unsigned
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b10;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b01;
					end

					default: begin
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end 
				endcase		
			end 
			7'b0100011: begin // Stores
				case(funct3) 
					3'b000: begin	// Store Byte
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b1;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
					3'b001: begin	// Store Halfword
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b1;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b01;
					end

					3'b010: begin	// Store Word
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b1;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b10;
					end

					default: begin
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
				endcase
			end 
			7'b0001111: begin // FENCE / FENCEI
				case(funct3) // Nop operation 
					default: begin
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
				endcase 
			end 

			7'b0010011: begin // Immediate arithmetic 
				case(funct3) 
					3'b000: begin // ADDI
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0000;
						sign_val  = 1'b1;
						read_size = 2'b01;	
					end

					3'b010: begin //SLTI
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0011;
						sign_val  = 1'b1;
						read_size = 2'b01;	
					end

					3'b011: begin //SLTIU
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0100;
						sign_val  = 1'b0;
						read_size = 2'b01;
					end 

					3'b100: begin //XORI
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0101;
						sign_val  = 1'b1;
						read_size = 2'b01;

					end

					3'b110: begin //ORI
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b1000;
						sign_val  = 1'b1;
						read_size = 2'b01;

					end

					3'b111: begin //ANDI
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b1001;
						sign_val  = 1'b1;
						read_size = 2'b01;

					end
					3'b001: begin //SLLI
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b1;
						ALU_funct = 4'b0010;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
					
					3'b101: begin
						case(instr[30])
							1'b0: begin // SRLI
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b1;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b1;
								ALU_funct = 4'b0110;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end

							1'b1: begin // SRAI
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b1;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b1;
								ALU_funct = 4'b0111;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end
							default: begin
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b0;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0000;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end
						endcase	
					end
			
					default: begin
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
				endcase 
			end 
			7'b0110011: begin // Register arithmetic 
				case(funct3)
					3'b000: begin 
						case(instr[30])
							1'b0: begin // ADD
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b1;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0000;
								sign_val  = 1'b1;
								read_size = 2'b01;
							end 

							1'b1: begin // SUB					
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b1;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0001;
								sign_val  = 1'b1;
								read_size = 2'b01;
							end 

							default: begin
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b0;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0000;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end
						endcase	
					end
					3'b101: begin 
						case(instr[30])
							1'b0: begin // SRL
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b1;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0110;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end
							1'b1: begin // SRA
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b1;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0111;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end

							default: begin
								branch_decoder_on = 1'b0;
								mux_PC = 1'b1;
								mux_reg = 2'b00;
								RegWrite = 1'b0;
								MemWrite = 1'b0;
								mux_ALUA = 2'b00;
								mux_ALUB = 1'b0;
								ALU_funct = 4'b0000;
								sign_val  = 1'b0;
								read_size = 2'b00;
							end
						endcase
					end

					3'b001: begin // SLL
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0010;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
					3'b010: begin // SLT
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0011;
						sign_val  = 1'b1;
						read_size = 2'b00;
					end

					3'b011: begin // SLTU
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0100;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end

					3'b100: begin // XOR
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0101;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end

					3'b110: begin // OR
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b1000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end

					3'b111: begin // AND
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b1;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b1001;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end

					default: begin
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
				endcase
			end 
			
			7'b1110011: begin // System instructions 
				case (funct3)
					3'b000: begin
						// rs1 = 0 and rd = 0
						if ((instr[19:15] == 5'b00000) && (instr[11:7]  == 5'b00000)) begin 

							case (instr[31:20])
								12'b000000000000: begin // ECALL 
									branch_decoder_on = 1'b0;
									mux_PC = 1'b1;
									mux_reg = 2'b00;
									RegWrite = 1'b0;
									MemWrite = 1'b0;
									mux_ALUA = 2'b00;
									mux_ALUB = 1'b0;
									ALU_funct = 4'b0000;
									sign_val  = 1'b0;
									read_size = 2'b00;
								end

								12'b000000000001: begin // EBREAK 
									branch_decoder_on = 1'b0;
									mux_PC = 1'b1;
									mux_reg = 2'b00;
									RegWrite = 1'b0;
									MemWrite = 1'b0;
									mux_ALUA = 2'b00;
									mux_ALUB = 1'b0;
									ALU_funct = 4'b0000;
									sign_val  = 1'b0;
									read_size = 2'b00;
				
								end
								default: begin 
									branch_decoder_on = 1'b0;
									mux_PC = 1'b1;
									mux_reg = 2'b00;
									RegWrite = 1'b0;
									MemWrite = 1'b0;
									mux_ALUA = 2'b00;
									mux_ALUB = 1'b0;
									ALU_funct = 4'b0000;
									sign_val  = 1'b0;
									read_size = 2'b00;
								end
							endcase
						end
					end

					default: begin 
						
					end
				endcase
			end
			7'b1100011: begin // Branches
				case(funct3)
					3'b000, 3'b001: begin //BEQ + BNE
						branch_decoder_on = 1'b1;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0001;
						sign_val  = 1'b1;
						read_size = 2'b01;
					end
					3'b100, 3'b101: begin //BLT + BGE
						branch_decoder_on = 1'b1;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0011;
						sign_val  = 1'b1;
						read_size = 2'b01;
					end

					3'b110, 3'b111: begin //BLTU + BGEU
						branch_decoder_on = 1'b1;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0100;
						sign_val  = 1'b0;
						read_size = 2'b01;
					end

					default: begin 
						branch_decoder_on = 1'b0;
						mux_PC = 1'b1;
						mux_reg = 2'b00;
						RegWrite = 1'b0;
						MemWrite = 1'b0;
						mux_ALUA = 2'b00;
						mux_ALUB = 1'b0;
						ALU_funct = 4'b0000;
						sign_val  = 1'b0;
						read_size = 2'b00;
					end
				endcase
			end
			default: begin 
				branch_decoder_on = 1'b0;
				mux_PC = 1'b1;
				mux_reg = 2'b00;
				RegWrite = 1'b0;
				MemWrite = 1'b0;
				mux_ALUA = 2'b00;
				mux_ALUB = 1'b0;
				ALU_funct = 4'b0000;
				sign_val  = 1'b0;
				read_size = 2'b00;
				
			end 	
		endcase
	end
endmodule
