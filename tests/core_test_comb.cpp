#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D40.h>
#include <Core_regfile__W40.h>

#define INST_COMB(a, b) ((static_cast<uint64_t>(b) << 32) | a)

TestGenMemCycle(
    BEQ_Multi,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);

        // beq $1, $2, +32
        MEM_SEG[0] = build_I_inst(0x4, 1, 2, 32 >> 2);
        // beq $1, $2, -12
        // 36 / 8 = 4.5, so 2nd inst in the slot
        MEM_SEG[(32 + 4) / 8] = INST_COMB(0, build_I_inst(0x4, 1, 2, -(24 >> 2)));
    },
    { EXPECT_EQ(inst_->core->pc, (32 + 4) - 24 + 4); },
    // 3rd cycle EX stage jump
    // 4th IF stage of 2nd beq (flushed)
    // 6th EX stage of 2nd beg
    3 + 3);

TestGenMemCycle(
    BEQ_StoreLoad,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // 0: beq $1, $2, +4  --> skip next one inst
        // 1: ori $1, $0, 0xabcd --> skiped
        // 2: sw $1, 0($0)
        // 3: lw $3, 0($0)
        MEM_SEG[0] = INST_COMB(build_I_inst(0x4, 1, 2, 4 >> 2), build_I_inst(0xd, 0, 1, 0xabcd));
        MEM_SEG[1] = INST_COMB(build_I_inst(0x2b, 0, 1, 0), build_I_inst(0x23, 0, 3, 0));
    },
    {
        EXPECT_EQ(MEM_SEG[0] & MASK32, val & MASK32);
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data, (val & MASK32) | ((val & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0));
    },
    // 3rd cycle jump
    // 4th IF stage of sw (flushed)
    // 5th IF stage of lw, 9th MEM stage of lw, writeback
    4 + 4);

TestGenMemOnceCycle(
    JAL_JR_Return,
    {
        MEM_SEG[0]      = build_J_inst(0x3, 32 >> 2);      // jal 32
        MEM_SEG[32 / 8] = build_R_inst(0, 31, 0, 0, 0, 8); // jr $ra
    },
    {
        EXPECT_EQ(inst_->core->pc, 32);
        tick();
        tick();
        tick();
        EXPECT_EQ(inst_->core->pc, 8); // jr $ra returns to 0 + 8
    },
    // 3 to EX
    3);
TestGenMemOnceCycle(
    BAL_JR_Return,
    {
        MEM_SEG[0]            = build_REGIMM_inst(0x1, 0x11, 0, 32 >> 2);      // bal 32
        MEM_SEG[(32 + 4) / 8] = INST_COMB(0, build_R_inst(0, 31, 0, 0, 0, 8)); // jr $ra
    },
    {
        EXPECT_EQ(inst_->core->pc, 32 + 4);
        tick();
        tick();
        tick();
        tick();
        EXPECT_EQ(inst_->core->pc, 8 + 4); // jr $ra returns to 0 + 8
    },
    // 3 to EX
    3);
