// Self-checking helpers for Verilator C++ testbenches; output matches tb_utils.svh.
// End every test with `return TB_FINISH();`, which prints TEST PASSED or TEST FAILED;
// test runners use that line to decide pass/fail.
// Use tb_eval(dut) instead of dut.eval(). When built with --trace, every tb_eval
// adds a sample to waves.vcd, or to the path given with +wave=<file>.
#pragma once

#include <cstdint>
#include <cstdio>
#include <string>

#include "verilated.h"
#if VM_TRACE
#include "verilated_vcd_c.h"
#endif

static int tb_errors = 0;
static uint64_t tb_time = 0;
#if VM_TRACE
static VerilatedVcdC* tb_vcd = nullptr;
#endif

#define CHECK(COND, MSG) \
    do { \
        if (!(COND)) { \
            tb_errors++; \
            std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, MSG); \
        } \
    } while (0)

#define CHECK_EQ(ACT, EXP, MSG) \
    do { \
        const uint64_t act_ = (uint64_t)(ACT), exp_ = (uint64_t)(EXP); \
        if (act_ != exp_) { \
            tb_errors++; \
            std::printf("FAIL %s:%d: %s: got 0x%llx, expected 0x%llx\n", __FILE__, __LINE__, MSG, \
                        (unsigned long long)act_, (unsigned long long)exp_); \
        } \
    } while (0)

#define TB_FINISH() tb_finish()

inline int tb_finish() {
#if VM_TRACE
    if (tb_vcd) tb_vcd->close();
#endif
    if (tb_errors == 0) std::printf("TEST PASSED\n");
    else std::printf("TEST FAILED (%d errors)\n", tb_errors);
    return tb_errors == 0 ? 0 : 1;
}

// Evaluate the DUT and record one waveform sample.
template <typename Dut>
inline void tb_eval(Dut& dut) {
#if VM_TRACE
    if (!tb_vcd) {
        Verilated::traceEverOn(true);
        tb_vcd = new VerilatedVcdC;
        dut.trace(tb_vcd, 99);
        const std::string arg = Verilated::commandArgsPlusMatch("wave=");
        tb_vcd->open(arg.empty() ? "waves.vcd" : arg.substr(6).c_str());
    }
#endif
    dut.eval();
#if VM_TRACE
    tb_vcd->dump(tb_time);
#endif
    tb_time++;
}

// One full clock cycle for DUTs with a `clk` input (e.g. reg_file, data_mem).
template <typename Dut>
inline void tick(Dut& dut) {
    dut.clk = 0;
    tb_eval(dut);
    dut.clk = 1;
    tb_eval(dut);
}
