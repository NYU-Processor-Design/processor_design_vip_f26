import sys # for command line arguments
from pathlib import Path # this is for getting the absolute path to the script dir's parent dir

# OPCODES
OP     = 0b0110011
OP_IMM = 0b0010011
STORE  = 0b0100011
LOAD   = 0b0000011
BRANCH = 0b1100011
JALR   = 0b1100111
JAL    = 0b1101111
AUIPC  = 0b0010111
LUI    = 0b0110111


INSTRUCTIONS = {
    # OPCODE == OP
    "ADD": {
        "OPCODE": OP,
        "funct3": 0b000
    },
    "SUB": {
        "OPCODE": OP,
        "funct3": 0b000
    },
    "SLL": {
        "OPCODE": OP,
        "funct3": 0b001
    },
    "SLT": {
        "OPCODE": OP,
        "funct3": 0b010
    },
    "SLTU": {
        "OPCODE": OP,
        "funct3": 0b011
    },
    "XOR": {
        "OPCODE": OP,
        "funct3": 0b100
    },
    "SRL": {
        "OPCODE": OP,
        "funct3": 0b101
    },
    "SRA": {
        "OPCODE": OP,
        "funct3": 0b101
    },
    "OR": {
        "OPCODE": OP,
        "funct3": 0b110
    },
    "AND": {
        "OPCODE": OP,
        "funct3": 0b111
    },
    # OPCODE == OP_IMM
    "ADDI": {
        "OPCODE": OP_IMM,
        "funct3": 0b000
    },
    "SLTI": {
        "OPCODE": OP_IMM,
        "funct3": 0b010
    },
    "SLTIU": {
        "OPCODE": OP_IMM,
        "funct3": 0b011
    },
    "XORI": {
        "OPCODE": OP_IMM,
        "funct3": 0b100
    },
    "ORI": {
        "OPCODE": OP_IMM,
        "funct3": 0b110
    },
    "ANDI": {
        "OPCODE": OP_IMM,
        "funct3": 0b111
    },
    "SLLI": {
        "OPCODE": OP_IMM,
        "funct3": 0b001
    },
    "SRLI": {
        "OPCODE": OP_IMM,
        "funct3": 0b101
    },
    "SRAI": {
        "OPCODE": OP_IMM,
        "funct3": 0b101
    },
    # OPCODE == STORE
    "SB": {
        "OPCODE": STORE,
        "funct3": 0b000
    },
    "SH": {
        "OPCODE": STORE,
        "funct3": 0b001
    },
    "SW": {
        "OPCODE": STORE,
        "funct3": 0b010
    },
    # OPCODE == LOAD
    "LB": {
        "OPCODE": LOAD,
        "funct3": 0b000
    },
    "LH": {
        "OPCODE": LOAD,
        "funct3": 0b001
    },
    "LW": {
        "OPCODE": LOAD,
        "funct3": 0b010
    },
    "LBU": {
        "OPCODE": LOAD,
        "funct3": 0b100
    },
    "LHU": {
        "OPCODE": LOAD,
        "funct3": 0b101
    },
    # OPCODE == BRANCH
    "BEQ": {
        "OPCODE": BRANCH,
        "funct3": 0b000
    },
    "BNE": {
        "OPCODE": BRANCH,
        "funct3": 0b001
    },
    "BLT": {
        "OPCODE": BRANCH,
        "funct3": 0b100
    },
    "BGE": {
        "OPCODE": BRANCH,
        "funct3": 0b101
    },
    "BLTU": {
        "OPCODE": BRANCH,
        "funct3": 0b110
    },
    "BGEU": {
        "OPCODE": BRANCH,
        "funct3": 0b111
    },
    # OPCODE == JALR
    "JALR": {
        "OPCODE": JALR
    },
    # OPCODE == JAL
    "JAL": {
        "OPCODE": JAL
    },
    # OPCODE == AUIPC
    "AUIPC": {
        "OPCODE": AUIPC
    },
    # OPCODE == LUI
    "LUI": {
        "OPCODE": LUI
    }
}

REGISTERS = {
    "x0": 0, "zero": 0,
    "x1": 1, "ra": 1, # return address
    "x2": 2, "sp": 2, # stack pointer
    "x3": 3, "gp": 3, # global pointer
    "x4": 4, "tp": 4, # thread pointer
    "x5": 5, "t0": 5, # temp
    "x6": 6, "t1": 1, # temp
    "x7": 7, "t2": 2, # temp
    "x8": 8, "s0": 8, "fp": 8, # saved register/frame pointer
    "x9": 9, "s1": 9, # saved register
    "x10": 10, # function arguments/return values
    "x11": 11, # function arguments/return values
    "x12": 12, "a2": 12, # function arguments
    "x13": 13, "a3": 13, # function arguments
    "x14": 14, "a4": 14, # function arguments
    "x15": 15, "a5": 15, # function arguments
    "x16": 16, "a6": 16, # function arguments
    "x17": 17, "a7": 17, # function arguments
    "x18": 18, "s2": 18, # saved registers
    "x19": 19, "s3": 19, # saved registers
    "x20": 20, "s4": 20, # saved registers
    "x21": 21, "s5": 21, # saved registers
    "x22": 22, "s6": 22, # saved registers
    "x23": 23, "s7": 23, # saved registers
    "x24": 24, "s8": 24, # saved registers
    "x25": 25, "s9": 25, # saved registers
    "x26": 26, "s10": 26, # saved registers
    "x27": 27, "s11": 27, # saved registers
    "x28": 28, "t3": 28, # temp
    "x29": 29, "t4": 29, # temp
    "x30": 30, "t5": 30, # temp
    "x31": 31, "t6": 31  # temp
}


def main():
    # this can later be taken in as a command line argument
    # assembly_code = "./prog.asm"
    try:
        assembly_code = sys.argv[1]
    except Exception:
        print("Must enter a valid program to assemble")
        return 1

    # properly format instructions
    formatted = format_asm(assembly_code)

    # build the symbol table
    symbol_table = build_symbol_table(formatted)
    # for key, value in symbol_table.items():
    #     print(f"{key}: {value}")

    # convert assembly into machine code (hex)
    # using tuple unpacking, get two return vals:
    data_mem, instr_mem = assemble(formatted, symbol_table)

    # write machine code (hex) into appropriate output file
    # get the absolute path to the parent dir of the script
    script_dir = Path(__file__).resolve().parent
    # write the paths to data.mem and instr.mem; this uses Path's / operator.
    data_out  = script_dir / "out" / "data.mem"
    instr_out = script_dir / "out" / "instr.mem"
    write_data(data_mem, data_out) # write data mem as hex into output file
    write_instr(instr_mem, instr_out) # write instr mem as hex into output file
    return 0


def format_asm(file_name):
    formatted = list()
    with open(file_name, "r") as file:
        for line in file:
            tokenized = list() # the final list of args which will be processed

            # ===== clean up the line =====
            line = line.replace("\n", "") # remove line break
            line = line.strip() # remove whitespace from front and end of line
            if (len(line) == 0 or line[0] == "#" or line[0] == ";"):
                continue # skip; this is a one-line comment, or an empty line
            
            # remove comments from lines
            line = line.split("#")[0].strip()
            line = line.split(";")[0].strip()

            # ===== format it =====
            line = line.replace(",", "") # remove commas (only spaces will be left)
            # remove parentheses (load and store instr have these)
            line = line.replace("(", " ")
            line = line.replace(")", "")

            # ===== tokenize arguments =====
            tokenized = line.split() # split args by any whitespace (handles any length of whitespace)

            # add it to formatted
            formatted.append(tokenized)
            # print(tokenized)
    return formatted


def build_symbol_table(assembly):
    # Run through the code once; build the symbol table
    # Symbol table should keep track of address related to where
    # it is in mem (data mem, or instr mem; harvard arch), and mem size (for data mem specifically)

    symbol_table = dict() # format of data - label: {mode: blah, addr: blah, size: blah}
    mode = None
    data_addr = 0
    instr_addr = 0

    for line in assembly:
        # check for mode change
        if line[0][0] == ".":
            mode = line[0]
            continue
        # check for single line label:
        elif len(line) == 1:
            addr = None
            if mode == ".data":
                addr = data_addr
            else:
                addr = instr_addr
            data = {"mode": mode, "addr": addr}
            key = line[0][0:(len(line[0])-1)] # this just gets the text label w/o the colon character at the end
            symbol_table[key] = data
            continue
        # check for label w/ data or instr
        elif line[0][-1] == ":":
            addr = None
            if mode == ".data":
                addr = data_addr
            else:
                addr = instr_addr
            data = {"mode": mode, "addr": addr}
            key = line[0][0:(len(line[0])-1)] # this just gets the text label w/o the colon character at the end
            symbol_table[key] = data
        
        # check if data
        if mode == ".data":
            # check size of data
            # move data_addr accordingly (every addr is 1 byte)
            values = len(line) - 2 # minus 2 b/c every data line has a label, and a data type before the values
            key = line[0][0:(len(line[0])-1)]

            if line[1] == ".byte":
                symbol_table[key]["size"] = values
                data_addr += values
            elif line[1] == ".half" or line[1] == ".hword":
                symbol_table[key]["size"] = values * 2
                data_addr += values * 2
            elif line[1] == ".word":
                symbol_table[key]["size"] = values * 4
                data_addr += values * 4
            elif line[1] == ".dword":
                symbol_table[key]["size"] = values * 8
                data_addr += values * 8
            else:
                print("error!") # temporary way to tell if an invalid data type was used; custom error msgs will
                                # be used in the future
        # check if instr
        elif mode == ".text":
            instr_addr += 2 # addr moves 4 bytes for every instr; all are the same size (two halfword positions)
    return symbol_table


def assemble(assembly, symbol_table):
    # Registers: use string manip to tell if valid, & to choose reg binary.
    # Instructions: hash table will be used to refer to valid instructions, 
    # and to choose the appropriate binary.

    data_mem = list() # byte-addressable; little endian
    instr_mem = list() # word-addressable; little endian, each instruction is two half-words

    instr_addr = 0
    mode = None
    for line in assembly:
        # check for mode change
        if line[0][0] == ".":
            mode = line[0]
            continue
        # check for single line label; skip
        elif len(line) == 1:
            continue
        # check for label w/ data or instr
        elif line[0][-1] == ":":
            # ignore label; treat as data or instruction line
            if mode == ".data":
                # easy; little endian
                data = assemble_data(line[1:], symbol_table) # ignore the label for assembly
                data_mem.extend(data) # append the new values into data_mem
            else: # mode == ".text"
                instruction = assemble_instr(line[1:], symbol_table, instr_addr) # ignore the label for assembly
                instr_mem.append(instruction & 0xFFFF)
                instr_mem.append(instruction >> 16)
                instr_addr += 2
        else:
            instruction = assemble_instr(line, symbol_table, instr_addr)
            instr_mem.append(instruction & 0xFFFF)
            instr_mem.append(instruction >> 16)
            instr_addr += 2
    return data_mem, instr_mem


def assemble_instr(line, symbol_table, curr_addr):
    '''
        // TYPES
        OP     = R
        OP_IMM = I
        STORE  = S
        LOAD   = I
        BRANCH = B
        JALR   = I
        JAL    = J
        AUIPC  = U
        LUI    = U
    '''
    # instruction line; treat accordingly (cannot be data line b/c all data lines will have labels)
    instruction = 0
    opcode = INSTRUCTIONS[line[0].upper()]["OPCODE"]
    instruction |= opcode << 0 # [6:0]

    match opcode:
        # personal note: the case statement in python is not like switch when using variables; remember this for the future!
        case x if x == OP:
            # R-type instruction
            instruction |= REGISTERS[line[1]] << 7 # rd [11:7]
            # funct3 [14:12]
            instruction |= INSTRUCTIONS[line[0].upper()]["funct3"] << 12
            # rs1 [19:15]
            instruction |= REGISTERS[line[2]] << 15
            # rs2 [24:20]
            instruction |= REGISTERS[line[3]] << 20
            # funct7 [31:25]
            instruction |= 0b0000000 << 25
            
            if line[0].upper() == "SUB" or line[0].upper() == "SRA":
                instruction |= 1 << 30

        case x if x == OP_IMM:
            # I-type instruction e.g.: slti rd, rs1, imm[11:0]
            # rd [11:7]
            instruction |= REGISTERS[line[1]] << 7
            # funct3 [14:12]
            instruction |= INSTRUCTIONS[line[0].upper()]["funct3"] << 12
            # rs1 [19:15]
            instruction |= REGISTERS[line[2]] << 15
            # final bits: [31:20]

            if line[0].upper() in ["SLLI", "SRLI", "SRAI"]:
                # shamt [24:20]
                instruction |= (int(line[3]) & 0b11111) << 20
                # funct7 [31:25]
                instruction |= 0b0000000 << 25
                if opcode == "SRAI":
                    instruction |= 1 << 30
            else:
                # imm [31:20]
                if line[3] in symbol_table:
                    # use the addr assoc w/ the label as imm
                    instruction |= (symbol_table[line[3]]["addr"] & 0xFFF) << 20
                else: # imm is a number; treat accordingly
                    instruction |= (int(line[3]) & 0xFFF) << 20 # only 12-bit imm accepted
        case x if x == JALR:
            # I-type instruction e.g.: jalr rd, rs1, imm[11:0]
            # rd [11:7]
            instruction |= REGISTERS[line[1]] << 7
            # funct3 [14:12]
            instruction |= INSTRUCTIONS[line[0].upper()]["funct3"] << 12
            # rs1 [19:15]
            instruction |= REGISTERS[line[2]] << 15
            # imm [31:20]
            if line[3] in symbol_table:
                label_addr = symbol_table[line[3]]["addr"]
                instruction |= ((label_addr - curr_addr) & 0xFFF) << 20
            else:
                instruction |= ((int(line[3]) - curr_addr) & 0xFFF) << 20 # use the raw addr from data mem
            
        case x if x == LOAD:
            # I-type instruction e.g.: lb rd, imm(rs1)
            # rd [11:7]
            instruction |= REGISTERS[line[1]] << 7
            # funct3 [14:12]
            instruction |= INSTRUCTIONS[line[0].upper()]["funct3"] << 12
            # rs1 [19:15]
            instruction |= REGISTERS[line[3]] << 15
            # imm [31:20]
            if line[2] in symbol_table:
                # use the addr assoc w/ the label as imm
                instruction |= (symbol_table[line[2]]["addr"] & 0xFFF) << 20
            else: # imm is a number; treat accordingly
                instruction |= (int(line[2]) & 0xFFF) << 20 # only 12-bit imm accepted
        case x if x == STORE:
            # S-type instruction e.g.: sw rs2, imm(rs1)
            imm = None
            if line[2] in symbol_table:
                imm = symbol_table[line[2]]["addr"] & 0xFFF
            else:
                imm = int(line[2]) & 0xFFF
            # imm[4:0] [11:7]
            instruction |= (imm & 0b11111) << 7
            # funct3 [14:12]
            instruction |= INSTRUCTIONS[line[0].upper()]["funct3"] << 12
            # rs1 [19:15]
            instruction |= REGISTERS[line[3]] << 15
            # rs2 [24:20]
            instruction |= REGISTERS[line[1]] << 20
            # imm[11:5] [31:25]
            instruction |= ((imm >> 5) & 0b1111111) << 25
        case x if x == BRANCH:
            # B-type instruction e.g.: beq rs1, rs2, imm[12:1]
            imm = None
            if line[3] in symbol_table:
                label_addr = symbol_table[line[3]]["addr"]
                imm = (label_addr - curr_addr) & 0xFFF
            else:
                imm = (int(line[3]) - curr_addr)& 0xFFF
            # imm[11] [7]
            instruction |= ((imm >> 11) & 1) << 7
            # imm[4:1] [11:8]
            instruction |= ((imm >> 1) & 0b1111) << 8
            # funct3 [14:12]
            instruction |= INSTRUCTIONS[line[0].upper()]["funct3"] << 12
            # rs1 [19:15]
            instruction |= REGISTERS[line[1]] << 15
            # rs2 [24:20]
            instruction |= REGISTERS[line[2]] << 20
            # imm[10:5] [30:25]
            instruction |= ((imm >> 5) & 0b111111) << 25
            # imm[12] [31]
            instruction |= ((imm >> 12) & 1) << 31

        case x if x == JAL:
            # J-type instruction e.g.: jal rd, imm[20:1]
            imm = None
            if line[2] in symbol_table:
                label_addr = symbol_table[line[2]]["addr"]
                imm = (label_addr - curr_addr) & 0xFFFFFF # 24-bit mask; 21 bits needed
            else:
                # J-imm = jump_target_addr - curr_instr_addr
                imm = (int(line[2]) - curr_addr)& 0xFFFFFF
            # rd [11:7]
            instruction |= REGISTERS[line[1]] << 7
            # imm[19:12] [19:12]
            instruction |= ((imm >> 12) & 0xFF) << 12
            # imm[11] [20]
            instruction |= ((imm >> 11) & 1) << 20
            # imm[10:1] [30:21]
            instruction |= ((imm >> 1) & 0b1111111111) << 21
            # imm[20] [31]
            instruction |= ((imm >> 20) & 1) << 31
        case x if x in [AUIPC, LUI]:
            # U-type instruction e.g.: lui rd, imm[19:0]
            # rd [11:7]
            instruction |= REGISTERS[line[1]] << 7
            # imm [31:12]
            imm = None
            if line[2] in symbol_table:
                imm = symbol_table[line[2]]["addr"] & 0xFFFFF
            else:
                imm = int(line[2]) & 0xFFFFF
            instruction |= imm << 12
        case _:
            # this is the default case; should handle EBREAK, ECALL, and FENCE instructions as NOPs
            return None # this is temporary; will change it to a nop in the future

    # return the instruction as machine code
    return instruction


def assemble_data(line, symbol_table):
    # example data line: ['.word', '2', '5', '8', '12', '16', '23', '38', '56', '72', '91']
    final_vals = list()
    data_type = line.pop(0)
    if data_type == ".byte":
        while len(line) > 0:
            final_vals.append(int(line.pop(0)) & 0xFF)
    elif data_type == ".half" or data_type == ".hword":
        while len(line) > 0:
            half = int(line.pop(0)) & 0xFFFF
            final_vals.append(half & 0xFF)
            final_vals.append((half >> 8) & 0xFF)
    elif data_type == ".word":
        while len(line) > 0:
            word = int(line.pop(0)) & 0xFFFFFFFF
            final_vals.append(word & 0xFF)
            final_vals.append((word >> 8)  & 0xFF)
            final_vals.append((word >> 16) & 0xFF)
            final_vals.append((word >> 24) & 0xFF)
    elif data_type == ".dword":
        double = int(line.pop(0)) & 0xFFFFFFFFFFFFFFFF
        final_vals.append(double & 0xFF)
        final_vals.append((double >> 8)  & 0xFF)
        final_vals.append((double >> 16) & 0xFF)
        final_vals.append((double >> 24) & 0xFF)
        final_vals.append((double >> 32) & 0xFF)
        final_vals.append((double >> 40) & 0xFF)
        final_vals.append((double >> 48) & 0xFF)
        final_vals.append((double >> 56) & 0xFF)
    return final_vals


def write_data(memory, filepath):
    max_mem = 8192 # amount of mem cells in data_mem (verilog module)
    padding = max_mem - len(memory)
    # pad the rest of memory with zeroes
    for _ in range(padding):
        memory.append(0)
    with open(filepath, "w") as file:
        for line in memory:
            file.write(f"{line:02x}\n")
    return None


def write_instr(memory, filepath):
    max_mem = 8192 * 2 # amount of mem cells in instr_mem (found within risc_v verilog module)
    padding = max_mem - len(memory)
    # pad the rest of memory with zeroes
    for _ in range(padding):
        memory.append(0)
    with open(filepath, "w") as file:
        for line in memory:
            file.write(f"{line:04x}\n")
    return None


if __name__ == "__main__":
    main()