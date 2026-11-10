# crt0.S : startup for the Harvard RV32I core (no OS, no traps)
# .data/.rodata are preloaded into data RAM (data.mem), so only .bss is cleared
# here, then C++ global constructors run (Chu-style drivers create global objects).
    .section .text.init
    .globl _start
_start:
    la      sp, _stack_top
    la      t0, __bss_start
    la      t1, __bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:  la      s0, __init_array_start
    la      s1, __init_array_end
3:  bgeu    s0, s1, 4f
    lw      t0, 0(s0)
    jalr    t0
    addi    s0, s0, 4
    j       3b
4:  call    main
5:  j       5b          # main returned: spin
