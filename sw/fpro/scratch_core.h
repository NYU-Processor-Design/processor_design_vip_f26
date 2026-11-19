// ============================================================================
// scratch_core.h : driver for the scratch core (slot 6) -- FINISHED EXAMPLE
//
// This is the worked example for the driver part of the assignment: every
// driver in this folder has the same shape.
//   * a constexpr constructor that only stores the slot's base address
//     (so global objects need no startup code),
//   * an enum naming the register offsets (no magic numbers in the methods),
//   * small methods built only from io_read / io_write (see fpro_io.h).
// Get a core's base address with  get_slot_addr(BRIDGE_BASE, S6_SCRATCH).
// ============================================================================
#ifndef SCRATCH_CORE_H
#define SCRATCH_CORE_H

#include <stdint.h>
#include "fpro_map.h"
#include "fpro_io.h"

class ScratchCore {
public:
    enum { REG_0 = 0, REG_1 = 1, REG_2 = 2, REG_3 = 3 };
    constexpr explicit ScratchCore(uint32_t base) : base_(base) {}
    void     write(uint32_t reg, uint32_t v) { io_write(base_, reg, v); }
    uint32_t read(uint32_t reg) const        { return io_read(base_, reg); }
private:
    uint32_t base_;
};

#endif
