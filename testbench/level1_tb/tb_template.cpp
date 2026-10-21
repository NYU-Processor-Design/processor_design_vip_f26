// Copy to <module>_tb.cpp, replace Valu with V<module>, and replace the checks
// with your own.
#include "Valu.h"
#include "tb_utils.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Valu dut;

    dut.inA = 2;
    dut.inB = 3;
    dut.ALU_funct = 0;  // ADD
    dut.eval();
    CHECK_EQ(dut.out, 5, "2 + 3");

    dut.inA = 0xFFFFFFFF;
    dut.inB = 1;
    dut.eval();
    CHECK_EQ(dut.out, 0, "wraps on overflow");
    CHECK(dut.zflag == 1, "zero flag set");

    // Sequential modules: set inputs, then tick(dut) to apply a rising edge.

    dut.final();
    return TB_FINISH();
}
