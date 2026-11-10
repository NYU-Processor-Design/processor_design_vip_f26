/* Harvard RV32I core: IMEM 0x00000000 (32K) holds .text; DMEM 0x10000000 (16K)
   holds .data/.rodata/.bss/stack. Separate memories: BOTH images are preloaded
   (instr.mem and data.mem); nothing is copied at boot. I/O window 0xC0000000. */
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 32K
    DMEM (rw) : ORIGIN = 0x10000000, LENGTH = 16K
}
SECTIONS
{
    .text : { *(.text.init) *(.text .text.*) } > IMEM
    .data : { *(.data .data.*) *(.sdata .sdata.*) . = ALIGN(4); } > DMEM
    .rodata : { *(.rodata .rodata.*) *(.srodata .srodata.*) . = ALIGN(4); } > DMEM
    .init_array : { __init_array_start = .; KEEP(*(SORT(.init_array.*))) KEEP(*(.init_array)) __init_array_end = .; } > DMEM
    .bss (NOLOAD) : { __bss_start = .; *(.sbss .sbss.* .bss .bss.* COMMON) . = ALIGN(4); __bss_end = .; } > DMEM
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) }
}
