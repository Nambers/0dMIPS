#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_core_branch.h>
#include <Core_data_mem__D1000.h>
#include <Core_regfile__W40.h>

TestGenMemCycle(
    BEQ_Multi,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);

        // beq $1, $2, +32
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0x4, 1, 2, 32 >> 2), 0));
        // beq $1, $2, -12
        // 36 / 8 = 4.5, so 2nd inst in the slot
        write_mem_seg(MEM_SEG, ((32 + 4) / 8) * 8,
                      inst_comb(0, build_I_inst(0x4, 1, 2, -(24 >> 2))));
    },
    { EXPECT_EQ(FETCH_PC, (32 + 4) - 24 + 4); },
    // 3rd cycle EX stage jump
    // 4th IF stage of 2nd beq (flushed)
    // 6th EX stage of 2nd beg
    4 + 2);

TestGenMemCycle(
    BEQ_StoreLoad,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // 0: beq $1, $2, +4  --> skip next one inst
        // 1: ori $1, $0, 0xabcd --> skiped
        // 2: sw $1, 0($0)
        // 3: lw $3, 0($0)
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0x4, 1, 2, 4 >> 2),
                                build_I_inst(0xd, 0, 1, 0xabcd)));
        write_mem_seg(MEM_SEG, 8,
                      inst_comb(build_I_inst(0x2b, 0, 1, 4),
                                build_I_inst(0x23, 0, 3, 4)));
    },
    {
        EXPECT_EQ(read_mem_seg(MEM_SEG, 4) & MASK32, val & MASK32);
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data, sign_extend(val & MASK32, 32));
    },
    // 4rd cycle jump
    // 4th IF stage of sw (flushed)
    // 5th IF stage of lw, 9th MEM stage of lw, writeback
    4 + 1 + 2);

TestGenMemOnceCycle(
    JAL_JR_Return,
    {
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_J_inst(0x3, 32 >> 2), 0)); // jal 32
        write_mem_seg(MEM_SEG, 32,
                      inst_comb(build_R_inst(0, 31, 0, 0, 0, 8), 0)); // jr $ra
    },
    {
        EXPECT_EQ(FETCH_PC, 32);
        tick();
        tick();
        tick();
        EXPECT_EQ(FETCH_PC, 8); // jr $ra returns to 0 + 8
    },
    // 3 to EX
    2);
TestGenMemOnceCycle(
    BAL_JR_Return,
    {
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_REGIMM_inst(0x1, 0x11, 0, 32 >> 2), 0)); // bal 32
        write_mem_seg(MEM_SEG, ((32 + 4) / 8) * 8,
                      inst_comb(0, build_R_inst(0, 31, 0, 0, 0, 8))); // jr $ra
    },
    {
        EXPECT_EQ(FETCH_PC, 32 + 4);
        tick();
        tick();
        tick();
        tick();
        EXPECT_EQ(FETCH_PC, 8 + 4); // jr $ra returns to 0 + 8
    },
    // 3 to EX
    3);

TestGenMemOnceCycle(
    LA,
    {
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(
                build_I_inst(0x0f, 0, 1,
                             (fixedVal<uint32_t>() >> 16) & MASK16), // LUI
                build_I_inst(0x0d, 1, 1, fixedVal<int16_t>())        // ORI
                ));
    },
    {
        // 1st tick: LUI result
        auto lui_val =
            sign_extend(((fixedVal<uint32_t>() >> 16) & MASK16) << 16, 32);
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, lui_val);

        tick(); // move to ORI

        // 2nd tick: ORI result
        uint64_t ori_val = sign_extend(fixedVal<int32_t>(), 32);
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, ori_val);

        tick();
        EXPECT_FALSE(RF->wr_enable);
    },
    3);

TestGenMemOnceCycle(
    LW_ADDI,
    {
        write_mem_seg(MEM_SEG, 32,
                      sign_extend(fixedVal<int32_t>(),
                                  32)); // store value into $0
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_I_inst(0x23, 0, 1, 32),                   // LW
                      build_I_inst(0x9, 1, 1, fixedVal<int16_t>()))); // ADDI
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, sign_extend(fixedVal<int32_t>(), 32));

        tick();
        EXPECT_FALSE(RF->wr_enable);
        tick(); // stall, load-use hazard

        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, sign_extend(fixedVal<int32_t>(), 32) +
                                  sign_extend(fixedVal<int16_t>(), 16));

        tick();
        EXPECT_FALSE(RF->wr_enable);
    },
    3);

TestGenMemOnceCycle(
    ORI_ADDI,
    {
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_I_inst(0xd, 0, 1, fixedVal<int16_t>()),   // ORI
                      build_I_inst(0x9, 1, 1, fixedVal<int16_t>()))); // ADDI
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, fixedVal<int16_t>());

        tick();

        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, fixedVal<int16_t>() * 2);

        tick();
        EXPECT_FALSE(RF->wr_enable);
    },
    3);
TestGenMemOnceCycle(
    LA_LA,
    {
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(
                build_I_inst(0x0f, 0, 1, (fixedVal<uint32_t>() >> 16) & MASK16),
                build_I_inst(0x0d, 1, 1, fixedVal<int16_t>())));

        write_mem_seg(
            MEM_SEG, (1) * 8,
            inst_comb(build_I_inst(0x0f, 0, 1,
                                   (fixedVal2<uint32_t>() >> 16) & MASK16),
                      build_I_inst(0x0d, 1, 1, fixedVal2<int16_t>())));
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(
            RF->W_data,
            sign_extend(((fixedVal<uint32_t>() >> 16) & MASK16) << 16, 32));

        tick();
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, sign_extend(fixedVal<int32_t>(), 32));

        tick();
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(
            RF->W_data,
            sign_extend(((fixedVal2<uint32_t>() >> 16) & MASK16) << 16, 32));

        tick();
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, sign_extend(fixedVal2<int32_t>(), 32));

        tick(); // done
        EXPECT_FALSE(RF->wr_enable);
    },
    3 // total 5 cycles
);

TestGenMemCycle(
    LUI_Load,
    {
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0xf, 0, 1, 1),             // LUI
                                build_I_inst(0x23, 1, 2, -(1 << 15)))); // LW
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, 1 << 16);
        EXPECT_EQ(inst_->core->MEM_stage->mem->addr,
                  (1 << 16) - (1 << 15)); // 0x8000
    },
    3);

// --- CP0 ---
TestGenMemOnceCycle(
    MTC0_MFC0,
    {
        WRITE_RF(1, fixedVal<uint32_t>());
        // save and retrive from reg12,0 (status reg)
        // MTC0 $1, 12, 0
        // MFC0 $2, 12, 0
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_CP0_inst(4, 1, 12, 0),
                                build_CP0_inst(0, 2, 12, 0)));
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 2);
        EXPECT_EQ(RF->W_data, fixedVal<uint32_t>());
    },
    4);

TestGenMemOnceCycle(
    SYSCALL_MFC0, const auto syscallInst = ((fixedVal<uint32_t>() << 6) &
                                            ((~0b111111UL) << 26)) |
                                           0b001100;
    {
        inst_->core->branch_unit->interrupeHandlerAddr = 32;
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(syscallInst, // SYSCALL
                                0));
        write_mem_seg(
            MEM_SEG, 32,
            inst_comb(build_CP0_inst(0, 2, 8, 1), 0)); // MFC0 $2, 8, 1
    },
    {
        EXPECT_EQ(FETCH_PC,
                  32); // syscall jumps to default error handler
        tick();
        tick();
        tick();
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 2);
        EXPECT_EQ(RF->W_data, syscallInst); // badInstr
    },
    4); // handler written in MEM stage + 1 for jump
TestGenMemOnceCycle(
    SYSCALL_ERET,
    {
        inst_->core->branch_unit->interrupeHandlerAddr = 32;
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(((fixedVal<uint32_t>() << 6) & ((~0b111111UL) << 26)) |
                          0b001100, // SYSCALL
                      0));
        write_mem_seg(MEM_SEG, 32,
                      inst_comb(0b0100001UL << 25 | 0b011000, 0)); // ERET
    },
    {
        EXPECT_EQ(FETCH_PC,
                  32); // syscall jumps to default error handler
        tick();
        tick();
        EXPECT_EQ(FETCH_PC, 0 + 4); // ERET returns to 0
    },
    4);
