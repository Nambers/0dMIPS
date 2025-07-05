#include <gtest/gtest.h>
#include <verilated.h>
#include <verilated_cov.h>

bool dumpCov = false;

int main(int argc, char **argv) {
    Verilated::mkdir("logs");
    testing::InitGoogleTest(&argc, argv);
    Verilated::commandArgs(argc, argv);
    if (const char* dump = std::getenv("DUMP_COV"))
        dumpCov = std::string(dump) == "1" || std::string(dump) == "true";
    Verilated::assertOn(true);
    Verilated::traceEverOn(true);
    return RUN_ALL_TESTS();
}
