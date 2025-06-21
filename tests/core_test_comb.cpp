#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D40.h>
#include <Core_regfile__W40.h>

#define INST_COMB(a, b) ((static_cast<uint64_t>(b) << 32) | a)

#define TestGenMem(name, init_test, check_result, cycle)                       \
    TEST_F(CoreTest, name) {                                                   \
        for (const auto val : common_boundary_cases) {                         \
            reset();                                                           \
            init_test;                                                         \
            RESET_PC();                                                        \
            for (auto i = 0; i < cycle; ++i)                                   \
                tick();                                                        \
            check_result;                                                      \
        }                                                                      \
    }

TestGenMem(
    BEQ_Multi,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);

        // beq $1, $2, +32
        MEM_SEG[0] = build_I_inst(0x4, 1, 2, 32 >> 2);
        // beq $1, $2, -12
        // 36 / 8 = 4.5, so 2nd inst in the slot
        MEM_SEG[(32 + 4) / 8] =
            INST_COMB(0, build_I_inst(0x4, 1, 2, -(24 >> 2)));
    },
    {
        // 4 for inst addr
        EXPECT_EQ(inst_->core->pc, (32 + 4) - 24 + 4);
    },
    // 3rd cycle jump
    // 4th IF stage of 2nd beq (flushed)
    // 7th EX stage of 2nd beg
    3 + 4 + 1);

TestGenMem(
    BEQ_StoreLoad,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // 0: beq $1, $2, +4  --> skip next one inst
        // 1: ori $1, $0, 0xabcd --> skiped
        // 2: sw $1, 0($0)
        // 3: lw $3, 0($0)
        MEM_SEG[0] = INST_COMB(build_I_inst(0x4, 1, 2, 4 >> 2),
                               build_I_inst(0xd, 0, 1, 0xabcd));
        MEM_SEG[1] =
            INST_COMB(build_I_inst(0x2b, 0, 1, 0), build_I_inst(0x23, 0, 3, 0));
    },
    {
        EXPECT_EQ(MEM_SEG[0] & MASK32, val & MASK32);
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data,
                  (val & MASK32) |
                      ((val & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0));
    },
    // 3rd cycle jump
    // 4th IF stage of sw (flushed)
    // 5th IF stage of lw, 9th MEM stage of lw, writeback
    4 + 5);
