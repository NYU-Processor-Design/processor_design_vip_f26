#!/usr/bin/env python3
# independent encoders and architectural oracle; no production decoder is reused
import argparse
import importlib.util
import json
from pathlib import Path
import random
import sys

parser = argparse.ArgumentParser(description="generate deterministic execution traces")
parser.add_argument("--out", type=Path, required=True)
parser.add_argument("--seed", type=int, default=2601101)
parser.add_argument("--random-instructions", type=int, default=1200)
parser.add_argument("--assembler", action="store_true")
args = parser.parse_args()
if not 0 <= args.random_instructions <= 7000:
    parser.error("--random-instructions must be between 0 and 7000")
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
program = []
names = []

# encode each instruction independently of the project assembler
def emit(word, name):
    program.append(word & 0xffffffff)
    names.append(name)

# encode I-type immediates
def i(op, rd, f3, rs1, imm):
    return ((imm & 4095) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

# encode R-type arithmetic
def r(rd, f3, rs1, rs2, alt=0):
    return (alt << 30) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33

# encode signed byte offsets for conditional branches
def b(f3, rs1, rs2, imm):
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((imm >> 1) & 15) << 8) | (((imm >> 11) & 1) << 7) | 0x63

# encode signed byte offsets for jumps
def j(rd, imm):
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 1023) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 255) << 12) | (rd << 7) | 0x6f

# encode store offsets
def s(f3, rs1, rs2, imm):
    return (((imm >> 5) & 127) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 31) << 7) | 0x23

# initialize registers and tested memory through instructions, independent of power-on state
for register in range(1, 32):
    emit(i(0x13, register, 0, 0, 0), "addi")
for address in range(0, 64, 4):
    emit(s(2, 0, 0, address), "sw")

# exercise signed extremes and both outcomes of all branch forms
emit(i(0x13, 1, 0, 0, -1), "addi")
emit(i(0x13, 2, 0, 0, 1), "addi")
emit(0x800001b7, "lui")
emit(0x80000237, "lui")
emit(i(0x13, 4, 0, 4, -1), "addi")
emit(i(0x13, 31, 0, 0, 32), "addi")
branch_names = {0:"beq", 1:"bne", 4:"blt", 5:"bge", 6:"bltu", 7:"bgeu"}
for f3, name in branch_names.items():
    for a, c in [(1, 1), (1, 2), (2, 1), (3, 4), (4, 3)]:
        emit(b(f3, a, c, 8), name)
        emit(i(0x13, 6, 0, 6, 1), "addi")
        emit(i(0x13, 7, 0, 7, 1), "addi")

# exercise backwards control flow and aliased JALR source and destination
emit(i(0x13, 8, 0, 0, 3), "addi")
emit(i(0x13, 8, 0, 8, -1), "addi")
emit(b(1, 8, 0, -4), "bne")
emit(j(5, 8), "jal")
emit(i(0x13, 6, 0, 6, 15), "addi")
emit(i(0x13, 8, 0, 0, 3), "addi")
emit(i(0x13, 8, 0, 8, -1), "addi")
emit(b(0, 8, 0, 8), "beq")
emit(j(5, -8), "jal")
target = (len(program) + 3) * 4
emit(i(0x13, 10, 0, 0, target - 2), "addi")
emit(i(0x67, 10, 0, 10, 3), "jalr")
emit(i(0x13, 6, 0, 6, 15), "addi")
target = (len(program) + 3) * 4
emit(i(0x13, 10, 0, 0, target + 6), "addi")
emit(i(0x67, 9, 0, 10, -5), "jalr")
emit(i(0x13, 6, 0, 6, 15), "addi")

# exercise arithmetic boundaries, all widths, and negative offsets
ops = [(0,0,"add"), (0,1,"sub"), (1,0,"sll"), (2,0,"slt"), (3,0,"sltu"), (4,0,"xor"), (5,0,"srl"), (5,1,"sra"), (6,0,"or"), (7,0,"and")]
for f3, alt, name in ops:
    for a, c in [(1,2), (3,4), (4,3), (0,0), (2,1)]:
        emit(r(11, f3, a, c, alt), name)
for f3, alt, name in [x for x in ops if x[2] != "sub"]:
    for imm in [-2048, -1, 0, 1, 31, 2047]:
        value = (imm & 31) | (alt << 10) if f3 in [1,5] else imm
        emit(i(0x13, 12, f3, 1, value), name + "i")
for f3, name in [(0,"sb"), (1,"sh"), (2,"sw")]:
    for offset in [-32, -16, 0, 28]:
        emit(s(f3, 31, 1, offset), name)
for f3, name in [(0,"lb"),(1,"lh"),(2,"lw"),(4,"lbu"),(5,"lhu")]:
    for offset in [-32, -16, 0, 28]:
        emit(i(0x03, 13, f3, 31, offset), name)

# exercise each final valid data-memory address without a crossing access
emit((2 << 12) | (30 << 7) | 0x37, "lui")
emit(i(0x13, 30, 0, 30, -4), "addi")
for f3, name, offset in [(2, "sw", 0), (1, "sh", 2), (0, "sb", 3)]:
    emit(s(f3, 30, 1, offset), name)
for f3, name, offset in [(2, "lw", 0), (1, "lh", 2), (5, "lhu", 2), (0, "lb", 3), (4, "lbu", 3)]:
    emit(i(0x03, 13, f3, 30, offset), name)
emit((0xabcde << 12) | (14 << 7) | 0x37, "lui")
emit((0xfffff << 12) | (15 << 7) | 0x17, "auipc")
emit(i(0x13, 0, 0, 1, 23), "addi")

# preserve a reproducible dependency-heavy random sequence
rng = random.Random(args.seed)
for n in range(args.random_instructions):
    rd, a, c = rng.randrange(31), rng.randrange(32), rng.randrange(32)
    kind = rng.randrange(6)
    f3, alt, name = rng.choice(ops)
    if kind == 0:
        emit(r(rd, f3, a, c, alt), name)
    elif kind == 1:
        if name == "sub":
            alt, name = 0, "add"
        imm = rng.randrange(-2048, 2048)
        if f3 in [1, 5]:
            imm = (imm & 31) | (alt << 10)
        emit(i(0x13, rd, f3, a, imm), name + "i")
    elif kind == 2:
        emit((rng.randrange(1 << 20) << 12) | (rd << 7) | 0x37, "lui")
    elif kind == 3:
        emit((rng.randrange(1 << 20) << 12) | (rd << 7) | 0x17, "auipc")
    elif kind == 4:
        f3, name = rng.choice([(0,"sb"),(1,"sh"),(2,"sw")])
        offset = rng.randrange(0, 61, 4) - 32
        emit(s(f3, 31, c, offset), name)
    else:
        f3, name = rng.choice([(0,"lb"),(1,"lh"),(2,"lw"),(4,"lbu"),(5,"lhu")])
        offset = rng.randrange(0, 61, 4) - 32
        emit(i(0x03, rd, f3, 31, offset), name)

# read every final register and tested byte through architectural ports
for register in range(32):
    emit(r(0, 0, register, 0), "add")
for address in range(64):
    emit(i(0x03, 1, 4, 0, address), "lbu")
stop_pc = len(program) * 4
emit(j(0, 0), "jal")

# smoke-test the unchanged assembler through its actual image writer
if args.assembler:
    sys.dont_write_bytecode = True
    repo = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location("project_assembler", repo / "assembler/assembler.py")
    assembler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(assembler)
    source = out / "sequential.asm"
    source.write_text(".text\naddi x1, x0, 7\naddi x2, x1, -3\nadd x3, x2, x1\nsw x3, 0(x0)\nlw x4, 0(x0)\n")
    formatted = assembler.format_asm(source)
    data_image, instruction_image = assembler.assemble(formatted, assembler.build_symbol_table(formatted))
    program = [instruction_image[n] | instruction_image[n + 1] << 16 for n in range(0, len(instruction_image), 2)]
    expected_program = [i(0x13, 1, 0, 0, 7), i(0x13, 2, 0, 1, -3), r(3, 0, 2, 1),
                        s(2, 0, 3, 0), i(0x03, 4, 2, 0, 0)]
    if program != expected_program:
        raise AssertionError("assembler smoke encoding differs from the independent encoder")
    names = ["addi", "addi", "add", "sw", "lw"]
    stop_pc = len(program) * 4
    destination = out / "assembler/out"
    destination.mkdir(parents=True, exist_ok=True)
    assembler.write_instr(instruction_image, destination / "instr.mem")
    assembler.write_data(data_image, destination / "data.mem")
    if len((destination / "instr.mem").read_text().splitlines()) != 16384:
        raise AssertionError("assembler image must contain 16384 halfwords")

# interpret signed values without relying on host integer width
def sext(x, bits):
    return (x & ((1 << (bits - 1)) - 1)) - (x & (1 << (bits - 1)))

# interpret a register as signed RV32I data
def signed(x):
    return sext(x, 32)

# track initialization separately so unknown production power-on state is never assumed
regs, data, pc = [0] * 32, [0] * 8192, 0
known_registers, known_data = {0}, set()
trace, trace_regs, trace_data = [], [], []
coverage, branch_coverage = set(), set()
for cycle in range(len(program) + 100):
    word = program[pc // 4]
    coverage.add(names[pc // 4])
    op, rd, f3, a, c = word & 127, (word >> 7) & 31, (word >> 12) & 7, (word >> 15) & 31, (word >> 20) & 31
    av, cv = regs[a], regs[c]
    if op in [0x13, 0x33, 0x63, 0x67, 0x03, 0x23] and a not in known_registers:
        raise AssertionError("rs1 precedes register initialization")
    if op in [0x33, 0x63, 0x23] and c not in known_registers:
        raise AssertionError("rs2 precedes register initialization")
    next_pc, result, address, size = pc + 4, None, 0, 0
    flags = (int(a in known_registers) << 2) | (int(c in known_registers) << 3)
    imm = sext(word >> 20, 12)
    if op in [0x13, 0x33]:
        bv = (imm & 0xffffffff) if op == 0x13 else cv
        if f3 == 0: result = av - bv if op == 0x33 and word & (1 << 30) else av + bv
        elif f3 == 1: result = av << (bv & 31)
        elif f3 == 2: result = int(signed(av) < signed(bv))
        elif f3 == 3: result = int(av < bv)
        elif f3 == 4: result = av ^ bv
        elif f3 == 5: result = signed(av) >> (bv & 31) if word & (1 << 30) else av >> (bv & 31)
        elif f3 == 6: result = av | bv
        else: result = av & bv
    elif op in [0x37, 0x17]:
        result = (word & 0xfffff000) + (pc if op == 0x17 else 0)
    elif op == 0x63:
        taken = {0:av == cv, 1:av != cv, 4:signed(av) < signed(cv), 5:signed(av) >= signed(cv), 6:av < cv, 7:av >= cv}[f3]
        branch_coverage.add((f3, taken))
        offset = sext(((word >> 31) << 12) | (((word >> 7) & 1) << 11) | (((word >> 25) & 63) << 5) | (((word >> 8) & 15) << 1), 13)
        if taken: next_pc = pc + offset
    elif op == 0x6f:
        offset = sext(((word >> 31) << 20) | (((word >> 12) & 255) << 12) | (((word >> 20) & 1) << 11) | (((word >> 21) & 1023) << 1), 21)
        result, next_pc = pc + 4, pc + offset
    elif op == 0x67:
        result, next_pc = pc + 4, (av + imm) & 0xfffffffe
    elif op in [0x03, 0x23]:
        if op == 0x23: imm = sext(((word >> 25) << 5) | ((word >> 7) & 31), 12)
        address, size = (av + imm) & 0xffffffff, 1 << (f3 & 3)
        assert 0 <= address <= len(data) - size
        if op == 0x23:
            for k in range(size):
                data[address + k] = (cv >> (k * 8)) & 255
                known_data.add(address + k)
        else:
            if not set(range(address, address + size)) <= known_data:
                raise AssertionError("load precedes memory initialization")
            result = sum(data[address + k] << (8 * k) for k in range(size))
            if not f3 & 4: result = sext(result, size * 8)
    else:
        raise ValueError(hex(word))
    flags |= int(result is not None) | (int(op == 0x23) << 1) | (int(op == 0x03) << 4)
    fields = [pc, word, next_pc & 0xffffffff, flags, av, cv,
              (result or 0) & 0xffffffff, address, f3 & 3]
    trace.append(sum(value << (32 * k) for k, value in enumerate(fields)))
    if result is not None and rd:
        regs[rd] = result & 0xffffffff
        known_registers.add(rd)
    pc = next_pc & 0xffffffff
    trace_regs.append(sum(value << (32 * k) for k, value in enumerate(regs)))
    trace_data.append(sum(value << (8 * k) for k, value in enumerate(data[:64])))
    if pc == stop_pc:
        break
else:
    raise AssertionError("program did not finish")
# require all directed forms and branch outcomes even when random traffic is disabled
if not args.assembler:
    assert len(branch_coverage) == 12, branch_coverage
    assert len(coverage) == 37, coverage
halfwords = [half for word in program for half in [word & 65535, word >> 16]]
if len(halfwords) > 16382:
    raise AssertionError("program overlaps the final fetch probe")
halfwords += [0] * (16384 - len(halfwords))
last_word = 0 if args.assembler else 0x87658c63
halfwords[-2:] = [last_word & 65535, last_word >> 16]

# keep generated data under the runner's build directory
for filename, items, width in [("program.mem", halfwords, 4), ("trace.mem", trace, 72), ("regs.mem", trace_regs, 256), ("data.mem", trace_data, 128)]:
    (out / filename).write_text("".join(f"{value:0{width}x}\n" for value in items))
(out / "cycles.svh").write_text(f"localparam integer CYCLES = {len(trace)};\nlocalparam logic [31:0] LAST_WORD = 32'h{last_word:08x};\n")
summary = {"seed": args.seed, "instructions": len(program), "cycles": len(trace),
           "instruction_forms": sorted(coverage), "branch_outcomes": sorted(branch_coverage),
           "mode": "assembler" if args.assembler else "independent"}
(out / "functional_coverage.json").write_text(json.dumps(summary, indent=2) + "\n")
print(f"generated {len(program)} instructions, {len(trace)} executed cycles, {len(coverage)} instruction forms, {len(branch_coverage)} branch outcomes")
