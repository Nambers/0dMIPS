#include <gtest/gtest.h>
#include <verilated.h>
#include <verilated_cov.h>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    testing::InitGoogleTest(&argc, argv);
    auto res = RUN_ALL_TESTS();
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
    return res;
}
