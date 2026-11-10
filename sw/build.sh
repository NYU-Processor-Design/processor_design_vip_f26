#!/bin/bash
# usage: sw/build.sh prog.cpp [more.cpp ...]   ->  build/instr.mem  build/data.mem
set -e
HERE=$(cd "$(dirname "$0")" && pwd); OUT=${OUT:-$HERE/../build}; mkdir -p "$OUT"
P=riscv64-unknown-elf
$P-gcc -march=rv32i -mabi=ilp32 -mstrict-align -I"$HERE" -Os -ffreestanding -fno-exceptions -fno-threadsafe-statics -fno-use-cxa-atexit -fno-asynchronous-unwind-tables \
       -nostartfiles -nostdlib -T"$HERE/link.ld" -Wl,--gc-sections "$HERE/crt0.S" "$@" -lgcc -o "$OUT/prog.elf"
$P-objcopy -O binary -j .text "$OUT/prog.elf" "$OUT/imem.bin"
$P-objcopy -O binary -j .data -j .rodata -j .init_array "$OUT/prog.elf" "$OUT/dmem.bin"
python3 "$HERE/bin2mem.py" "$OUT/imem.bin" "$OUT/instr.mem" 1
python3 "$HERE/bin2mem.py" "$OUT/dmem.bin" "$OUT/data.mem" 1
$P-size "$OUT/prog.elf"
