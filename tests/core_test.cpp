#include <Core.h>
#include <Core_core.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D40.h>

#include <fstream>
#include <iomanip>

#include "common.hpp"

template <std::size_t T>
void reloadMemory(VlUnpacked<QData, T> &mem, const char *filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Failed to open " << filename << "!" << std::endl;
        return;
    }
    uint64_t startAddr;
    file.ignore(1, '@');
    file >> std::hex >> startAddr;
    while (!file.eof()) {
        file >> std::hex >> mem[startAddr++];
    }
    file.close();
}

class CoreTest : public TestBase<Core> {
    void customSetUp() override { std::system("mkdir -p test_tmp"); }
};

TEST_F(CoreTest, ReadAndWrite) {
    std::system(
        "cd test_tmp && make -f ../example_asm/Makefile "
        "../example_asm/test_read_write -B");
    reloadMemory(inst_->core->MEM_stage->mem->data_seg,
                 "test_tmp/memory.text.mem");
    reloadMemory(inst_->core->MEM_stage->mem->data_seg,
                 "test_tmp/memory.data.mem");
    while (ctx.time() < 50 * 2) {
        // std::cout << "time = " << ctx.time() << "\tpc = " << std::hex
        //           << std::right << std::setfill('0') << std::setw(8)
        //           << inst_->core->pc << "\tinst = " << inst_->core->inst
        //           << std::dec << std::left << std::endl;
        tick();
    }
    auto result_addr = 0xa0 / 8;
    // word1 result
    EXPECT_EQ(inst_->core->MEM_stage->mem->data_seg[result_addr], 0x1BADB002);
    EXPECT_EQ(inst_->core->MEM_stage->mem->data_seg[++result_addr], 0x1BADB002);
    // word2 result
    EXPECT_EQ(inst_->core->MEM_stage->mem->data_seg[++result_addr], 0xffffffffDEADBEEF);
    EXPECT_EQ(inst_->core->MEM_stage->mem->data_seg[++result_addr], 0xDEADBEEF);
    // byte1 result
    EXPECT_EQ(inst_->core->MEM_stage->mem->data_seg[++result_addr], 0x3100000031);
    // byte2 result
    EXPECT_EQ(inst_->core->MEM_stage->mem->data_seg[++result_addr], 0x000000efffffffef);
}
