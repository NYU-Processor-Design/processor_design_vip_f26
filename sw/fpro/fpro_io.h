// fpro_io.h : register access helpers and bit-manipulation macros
//
// Address of register `off` of a core whose slot base address is `base`:
//        base + 4 * off          (registers are 32-bit words)
// Address of slot `n`:  BRIDGE_BASE + n * 32 words * 4 bytes
#ifndef FPRO_IO_H
#define FPRO_IO_H

#include <stdint.h>

// base address of slot `slot`
#define get_slot_addr(brg_base, slot) ((uint32_t)((brg_base) + (slot) * 32 * 4))

// `volatile` forces a real bus access every time (the compiler must not cache
// or reorder register reads/writes). All FPro accesses are whole 32-bit words.
static inline uint32_t io_read(uint32_t base, uint32_t off) {
    return *(volatile uint32_t *)(base + 4 * off);
}
static inline void io_write(uint32_t base, uint32_t off, uint32_t data) {
    *(volatile uint32_t *)(base + 4 * off) = data;
}

// single-bit helpers
#define bit_mask(n)            (1UL << (n))
#define bit_set(data, n)       ((data) |= bit_mask(n))
#define bit_clear(data, n)     ((data) &= ~bit_mask(n))
#define bit_toggle(data, n)    ((data) ^= bit_mask(n))
#define bit_read(data, n)      (((data) >> (n)) & 1UL)
#define bit_write(data, n, v)  ((v) ? bit_set(data, n) : bit_clear(data, n))

#endif
