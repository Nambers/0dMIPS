#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D40.h>
#include <Core_regfile__W40.h>

#include <fstream>
#include <iomanip>

/* #region read test */
#define TestGenRead(name, opcode, check_W_data)                                                    \
    TestGenMem(                                                                                    \
        name,                                                                                      \
        {                                                                                          \
            MEM_SEG[0] = build_I_inst(opcode, 0, 1, 16);                                           \
            MEM_SEG[2] = val;                                                                      \
        },                                                                                         \
        {                                                                                          \
            EXPECT_TRUE(RF->wr_enable);                                                            \
            EXPECT_EQ(RF->W_addr, 1);                                                              \
            EXPECT_EQ(RF->W_data, check_W_data);                                                   \
        })

TestGenRead(LB, 0x20, (val & 0xff) | ((val & 0x80) ? BYTE_HIGH_FULL : 0));
TestGenRead(LBU, 0x24, val & 0xff);
TestGenRead(LW, 0x23, (val & MASK32) | ((val & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0));
TestGenRead(LWU, 0x27, val& MASK32);
TestGenRead(LD, 0x37, val);

TestGenMem(
    LUI, { MEM_SEG[0] = build_I_inst(0xf, 0, 1, val & MASK16); },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data,
                  ((val & MASK16) << 16) | ((val & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0));
    });
TestGenMem(
    ORI, { MEM_SEG[0] = build_I_inst(0xd, 0, 1, val & MASK16); },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, (val & MASK16));
    });
/* #endregion */

/* #region write test */
#define TestGenWrite(name, opcode, check_mem)                                                      \
    TestGenMem(                                                                                    \
        name,                                                                                      \
        {                                                                                          \
            WRITE_RF(1, val); /* store val into reg $1*/                                           \
            MEM_SEG[0] = build_I_inst(opcode, 0, 1, 8);                                            \
        },                                                                                         \
        { EXPECT_EQ(MEM_SEG[1], check_mem); })

TestGenWrite(SW, 0x2b, val& MASK32);
TestGenWrite(SB, 0x28, val & 0xff);
TestGenWrite(SD, 0x3f, val);
/* #endregion */

// test both positive and negative 1
#define TestGenArith2(func_name, expr)                                                             \
    func_name(Pos, (expr 1), 1);                                                                   \
    func_name(Neg, (expr(-1)), -1)

#define TEST32OVERFLOW(expr) ((expr) > INT32_MAX || (expr) < INT32_MIN)
#define TEST64OVERFLOW(expr) ((expr) > INT64_MAX || (expr) < INT64_MIN)

/* #region R type arithmetics operations test */
#define TestGenArithR(name, funct, check_W_data, overflow_cond, fixed_val)                         \
    TestGenMem(                                                                                    \
        name,                                                                                      \
        {                                                                                          \
            WRITE_RF(1, fixed_val); /* store 1 into reg $1*/                                       \
            WRITE_RF(2, val);       /* store val into reg $2*/                                     \
            /* $3 = $1 <OP> $2 */                                                                  \
            MEM_SEG[0] = build_R_inst(0, 1, 2, 3, 0, funct);                                       \
        },                                                                                         \
        {                                                                                          \
            EXPECT_TRUE(RF->wr_enable);                                                            \
            EXPECT_EQ(RF->W_addr, 3);                                                              \
            if (!overflow_cond) EXPECT_EQ(RF->W_data, check_W_data);                               \
        })

/*
@args:
    name: test name
    opcode: funct field in R type instruction from mips_define.sv
    overflow_expr: overflow condition
    expr: expected result expr
    num: resevered arg for TestGenArithR2
*/
#define Arith32(name, opcode, overflow_expr, expr, num)                                            \
    TestGenArithR(name, opcode, expr& MASK32 | ((expr & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0),     \
                  TEST32OVERFLOW(overflow_expr), num);

#define TestAdd(AName, expr, num)                                                                  \
    Arith32(ADD##AName, 0x20, static_cast<int64_t>(num) + val, expr, num)
#define TestAddU(AName, expr, num)                                                                 \
    Arith32(ADDU##AName, 0x21, static_cast<int64_t>(num) + val, expr, num);

#define Arith64(name, opcode, overflow_expr, expr, num)                                            \
    TestGenArithR(name, opcode, expr, TEST64OVERFLOW(overflow_expr), num);
#define TestDAdd(AName, expr, num)                                                                 \
    Arith64(DADD##AName, 0x2c, static_cast<int64_t>(num) + val, expr, num)
#define TestDAddU(AName, expr, num)                                                                \
    Arith64(DADDU##AName, 0x2d, static_cast<int64_t>(num) + val, expr, num);

TestGenArith2(TestAdd, val +);
TestGenArith2(TestAddU, val +);
TestGenArith2(TestDAdd, val +);
TestGenArith2(TestDAddU, val +);

#define TestSub(AName, expr, num)                                                                  \
    Arith32(SUB##AName, 0x22, static_cast<int64_t>(num) - val, expr, num);

#define TestSubU(AName, expr, num)                                                                 \
    Arith32(SUBU##AName, 0x23, static_cast<int64_t>(num) - val, expr, num);

#define TestDSub(AName, expr, num)                                                                 \
    Arith64(DSUB##AName, 0x2e, static_cast<int64_t>(num) - val, expr, num);

TestGenArith2(TestSub, val -);
TestGenArith2(TestSubU, val -);
TestGenArith2(TestDSub, val -);
/* #endregion */

/* #region I type arithemtics operations test */
#define TestGenArithI(name, funct, check_W_data, overflow_cond, fixed_val)                         \
    TestGenMem(                                                                                    \
        name,                                                                                      \
        {                                                                                          \
            WRITE_RF(1, fixed_val); /* store 1 into reg $1*/                                       \
            /* $2 = $1 <OP> val */                                                                 \
            MEM_SEG[0] = build_I_inst(funct, 1, 2, val);                                           \
        },                                                                                         \
        {                                                                                          \
            EXPECT_TRUE(RF->wr_enable);                                                            \
            EXPECT_EQ(RF->W_addr, 2);                                                              \
            if (!overflow_cond) EXPECT_EQ(RF->W_data, check_W_data);                               \
        })
#define ArithI32(name, opcode, overflow_expr, expr, num)                                           \
    TestGenArithI(name, opcode, expr& MASK32 | ((expr & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0),     \
                  TEST32OVERFLOW(overflow_expr), num);
#define TestAddI(AName, expr, num)                                                                 \
    ArithI32(ADDI##AName, 0x8, static_cast<int64_t>(num) + val, expr, num)
#define TestAddIU(AName, expr, num)                                                                \
    ArithI32(ADDIU##AName, 0x9, static_cast<int64_t>(num) + val, expr, num);

TestGenArith2(TestAddI, val +);
TestGenArith2(TestAddIU, val +);

#define ArithI64(name, opcode, overflow_expr, expr, num)                                           \
    TestGenArithI(name, opcode, expr, TEST64OVERFLOW(overflow_expr), num);
#define TestDAddI(AName, expr, num)                                                                \
    ArithI64(DADDI##AName, 0x18, static_cast<int64_t>(num) + val, expr, num)
#define TestDAddIU(AName, expr, num)                                                               \
    ArithI64(DADDIU##AName, 0x19, static_cast<int64_t>(num) + val, expr, num);

TestGenArith2(TestDAddI, val +);
TestGenArith2(TestDAddIU, val +);
/* #endregion */

/* #region branching test */
TestGenMem(
    BEQ,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // beq $1, $2, +512
        MEM_SEG[0] = build_I_inst(0x4, 1, 2, 512 >> 2);
    },
    { EXPECT_EQ(inst_->core->pc, 4 + 512); });
TestGenMem(
    BEQ_Fail,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val + 1);
        // beq $1, $2, +512
        MEM_SEG[0] = build_I_inst(0x4, 1, 2, 512 >> 2);
    },
    {
        // 4 stages
        EXPECT_EQ(inst_->core->pc, 4 * 4);
    });
TestGenMem(
    BNE,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val + 1);
        // bne $1, $2, +512
        MEM_SEG[0] = build_I_inst(0x5, 1, 2, 512 >> 2);
    },
    { EXPECT_EQ(inst_->core->pc, 4 + 512); });
TestGenMem(
    BNE_Fail,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // bne $1, $2, +512
        MEM_SEG[0] = build_I_inst(0x5, 1, 2, 512 >> 2);
    },
    { EXPECT_EQ(inst_->core->pc, 4 * 4); });
TestGenMem(
    BC,
    {
        // bc $1, +512
        MEM_SEG[0] = build_J_inst(0x32, 512 >> 2);
    },
    { EXPECT_EQ(inst_->core->pc, 4 + 512); });
TestGenMemOnceCycle(
    J,
    {
        // j +512
        MEM_SEG[0] = build_J_inst(0x2, 512 >> 2);
    },
    { EXPECT_EQ(inst_->core->pc, 512); }, 3);

TestGenMemOnceCycle(
    JAL,
    {
        // jal +512 (target = (512 >> 2))
        MEM_SEG[0] = build_J_inst(0x3, 512 >> 2);
    },
    {
        // jal should jump to pc + 512, and store return address to $ra ($31)
        // EX stage
        EXPECT_EQ(inst_->core->pc, 512);
        tick(); // MEM stage
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 31);
        EXPECT_EQ(RF->W_data, 8); // return address is pc + 8
    },
    3);
TestGenMemOnceCycle(
    JR,
    {
        // Set $4 = 0x0d00
        WRITE_RF(4, 0x0d00);
        // jr $4
        MEM_SEG[0] = build_R_inst(0x0, 4, 0, 0, 0, 0x08);
    },
    { EXPECT_EQ(inst_->core->pc, 0x0d00); }, 3);
TestGenMemOnceCycle(
    JALR,
    {
        // Set $4 = 0x0d00
        WRITE_RF(4, 0x0d00);
        // jalr $4
        MEM_SEG[0] = build_R_inst(0x0, 4, 0, 1, 0, 0x09);
    },
    {
        EXPECT_EQ(inst_->core->pc, 0x0d00);
        tick(); // MEM stage
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, 8); // return address is pc + 8
    },
    3);
TestGenMemOnceCycle(
    BAL,
    {
        // bal +512 (offset = 512 / 4 = 128)
        MEM_SEG[0] = build_REGIMM_inst(0x1, 0x11, 0, 512 >> 2); // opcode=1, rt=17(BAL), rs=0
    },
    {
        // bal should jump to pc + 512, and store return address to $ra ($31)
        EXPECT_EQ(inst_->core->pc, 512 + 4); // PC updated after EX
        // tick();                          // MEM stage
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 31);
        EXPECT_EQ(RF->W_data, 8); // return address = pc + 8 from ID stage (pc = 0 + 8)
    },
    3 + 1);

/* #endregion */