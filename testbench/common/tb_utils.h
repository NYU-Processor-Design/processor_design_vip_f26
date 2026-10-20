// Self-checking helpers for Verilator C++ testbenches; output matches tb_utils.svh.
// End every test with `return TB_FINISH();`, which prints TEST PASSED or TEST FAILED;
// test runners use that line to decide pass/fail.
#pragma once

#include <cstdint>
#include <cstdio>

static int tb_errors = 0;

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
    if (tb_errors == 0) std::printf("TEST PASSED\n");
    else std::printf("TEST FAILED (%d errors)\n", tb_errors);
    return tb_errors == 0 ? 0 : 1;
}

// One full clock cycle for DUTs with a `clk` input (e.g. reg_file, data_mem).
template <typename Dut>
inline void tick(Dut& dut) {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
}
