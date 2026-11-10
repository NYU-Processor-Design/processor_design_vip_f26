// Minimal environment for riscv-tests (isa/rv32ui) on the Harvard RV32I core.
// No CSRs / traps: a test ends by storing a verdict to the I/O window.
//   verdict 1              = PASS
//   verdict (TESTNUM<<1)|1 = FAIL in test number TESTNUM
#ifndef _ENV_MINIMAL_H
#define _ENV_MINIMAL_H

#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align  2;                                                      \
        .globl _start;                                                  \
_start:

#define RVTEST_CODE_END

#define RVTEST_PASS                                                     \
        li      t6, 0xC0000000;                                         \
        li      t5, 1;                                                  \
        sw      t5, 0(t6);                                              \
1:      j       1b;

#define RVTEST_FAIL                                                     \
        li      t6, 0xC0000000;                                         \
        slli    t5, TESTNUM, 1;                                         \
        ori     t5, t5, 1;                                              \
        sw      t5, 0(t6);                                              \
1:      j       1b;

#define EXTRA_DATA
#define RVTEST_DATA_BEGIN  EXTRA_DATA .pushsection .data; .align 4; .global begin_signature; begin_signature:
#define RVTEST_DATA_END    .global end_signature; end_signature: .popsection

#endif
