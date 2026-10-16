module top(
	input logic clk
	);
	/*
	* Top Module:
	* The top module is required to stitch together all the different
	* parts of the core and get it to actually run. The requirements for
	* this module are to:
		* instantiate all modules with the appropriate inputs
		* create the necessary internal signals
		* implement the MUXes used in our schema with their appropriate
			* inputs and outputs, as well as logic.
		* create the program counter (32-bit) and necessary PC adder and the
			* logic necessary for sequentially changing the PC.
		* create instruction memory with its appropriate
		* specifications: 16-bit halfword-addressable, little-endian,
			* with 16,384 memory locations; combinational.
		* read the ".mem" hex files from the assembler.py output into
			* instruction memory.
	* This may seem like a lot to do, so I advise this to be broken up
	* into parts that individual people may work on in order to get it
	* completed.
	*/
endmodule
