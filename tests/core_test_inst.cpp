#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D800.h>
#include <Core_regfile__W40.h>

#include <fstream>
#include <iomanip>

/* #region read test */
#define TestGenRead(name, opcode, check_W_data)                                \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            write_mem_seg(MEM_SEG, 0,                                          \
                          inst_comb(build_I_inst(opcode, 0, 1, 16), 0));       \
            write_mem_seg(MEM_SEG, (2) * 8, val);                              \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 1);                                          \
            EXPECT_EQ(RF->W_data, check_W_data);                               \
        })

TestGenRead(LB, 0x20, (val & 0xff) | ((val & 0x80) ? BYTE_HIGH_FULL : 0));
TestGenRead(LBU, 0x24, val & 0xff);
TestGenRead(LW, 0x23, sign_extend(val &MASK32, 32));
TestGenRead(LWU, 0x27, val &MASK32);
TestGenRead(LD, 0x37, val);
/* #endregion */

/* #region write test */
#define TestGenWrite(name, opcode, check_mem)                                  \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            WRITE_RF(1, (val)); /* store val into reg $1*/                     \
            write_mem_seg(MEM_SEG, 0,                                          \
                          inst_comb(build_I_inst(opcode, 0, 1, 8), 0));        \
        },                                                                     \
        { EXPECT_EQ(*reinterpret_cast<uint64_t *>(&MEM_SEG[8]), check_mem); })

TestGenWrite(SW, 0x2b, val &MASK32);
TestGenWrite(SB, 0x28, val & 0xff);
TestGenWrite(SD, 0x3f, val);
/* #endregion */

// test both positive and negative 1
#define TestGenArith2(func_name, expr)                                         \
    func_name(Pos, (expr 1), 1);                                               \
    func_name(Neg, (expr(-1)), -1)

#define TEST32OVERFLOW(expr) ((expr) > INT32_MAX || (expr) < INT32_MIN)
#define TEST64OVERFLOW(expr) ((expr) > INT64_MAX || (expr) < INT64_MIN)

/* #region R type arithmetics operations test */
#define TestGenArithR(name, rs, shamt, funct, check_W_data, overflow_cond,     \
                      fixed_val)                                               \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            WRITE_RF(1, fixed_val); /* store 1 into reg $1*/                   \
            WRITE_RF(2, val);       /* store val into reg $2*/                 \
                                    /* $3 = $1 <OP> $2 */                      \
            write_mem_seg(                                                     \
                MEM_SEG, 0,                                                    \
                inst_comb(build_R_inst(0, rs, 2, 3, shamt, funct), 0));        \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 3);                                          \
            if (!overflow_cond)                                                \
                EXPECT_EQ(RF->W_data, check_W_data);                           \
        })

/*
@args:
    name: test name
    opcode: funct field in R type instruction from mips_define.sv
    overflow_expr: overflow condition
    expr: expected result expr
    num: resevered arg for TestGenArithR2
*/
#define Arith32(name, opcode, overflow_expr, expr, num)                        \
    TestGenArithR(name, 1, 0, opcode, sign_extend((expr) & MASK32, 32),        \
                  TEST32OVERFLOW(overflow_expr), num);
#define Arith32Shamt(name, opcode, overflow_expr, expr, num)                   \
    TestGenArithR(name, 0, num, opcode, sign_extend((expr) & MASK32, 32),      \
                  TEST32OVERFLOW(overflow_expr), 0);

#define TestAdd(AName, expr, num)                                              \
    Arith32(ADD##AName, 0x20, static_cast<int64_t>(num) + val, expr, num)
#define TestAddU(AName, expr, num)                                             \
    Arith32(ADDU##AName, 0x21, static_cast<int64_t>(num) + val, expr, num);
#define TestAnd(AName, expr, num)                                              \
    Arith32(AND##AName, 0x24, val &(num & MASK16), expr, num);
#define TestOr(AName, expr, num)                                               \
    Arith32(OR##AName, 0x25, val | (num & MASK16), expr, num);
#define TestXor(AName, expr, num)                                              \
    Arith32(XOR##AName, 0x26, val ^ (num & MASK16), expr, num);
#define TestNor(AName, expr, num)                                              \
    Arith32(NOR##AName, 0x27, ~(val | (num & MASK16)), expr, num);
#define TestSLL(AName, expr, num)                                              \
    Arith32Shamt(SLL##AName, 0x00, (val & MASK16) << num, expr, num);
#define TestSRL(AName, expr, num)                                              \
    Arith32Shamt(SRL##AName, 0x02, (val & MASK16) >> num, expr, num);
#define TestSRA(AName, expr, num)                                              \
    Arith32Shamt(SRA##AName, 0x03,                                             \
                 ((val & MASK16) >> num) |                                     \
                     ((val & MASK16) & 0x8000 ? 0xffff0000 : 0),               \
                 expr, num);

#define Arith64(name, opcode, overflow_expr, expr, num)                        \
    TestGenArithR(name, 1, 0, opcode, expr, TEST64OVERFLOW(overflow_expr), num);
#define TestDAdd(AName, expr, num)                                             \
    Arith64(DADD##AName, 0x2c, static_cast<int64_t>(num) + val, expr, num)
#define TestDAddU(AName, expr, num)                                            \
    Arith64(DADDU##AName, 0x2d, static_cast<int64_t>(num) + val, expr, num);

TestGenArith2(TestAnd, val &);
TestGenArith2(TestOr, val |);
TestGenArith2(TestXor, val ^);
TestSLL(Pos, ((val & MASK16) << 1), 1);
// TestSLL(Neg, ((val & MASK16) << (-1)), -1);
TestSRL(Pos, ((val & MASK16) >> 1), 1);
// TestSRL(Neg, ((val & MASK16) >> (-1)), -1);
TestSRA(Pos, ((val & MASK16) >> 1) | ((val & MASK16) & 0x8000 ? 0xffff0000 : 0),
        1);
TestNor(Pos, ~(val | 1), 1);
TestNor(Neg, ~(val | (-1)), -1);

TestGenArith2(TestAdd, val +);
TestGenArith2(TestAddU, val +);
TestGenArith2(TestDAdd, val +);
TestGenArith2(TestDAddU, val +);

#define TestSub(AName, expr, num)                                              \
    Arith32(SUB##AName, 0x22, static_cast<int64_t>(num) - val, expr, num);

#define TestSubU(AName, expr, num)                                             \
    Arith32(SUBU##AName, 0x23, static_cast<int64_t>(num) - val, expr, num);

#define TestDSub(AName, expr, num)                                             \
    Arith64(DSUB##AName, 0x2e, static_cast<int64_t>(num) - val, expr, num);

TestGenArith2(TestSub, val -);
TestGenArith2(TestSubU, val -);
TestGenArith2(TestDSub, val -);
/* #endregion */

/* #region I type arithemtics operations test */
TestGenMem(
    LUI,
    {
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0xf, 0, 1, val & MASK16), 0));
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, sign_extend((val & MASK16) << 16, 32));
    });
#define TestGenArithI(name, funct, check_W_data, overflow_cond, fixed_val)     \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            WRITE_RF(1, fixed_val); /* store 1 into reg $1*/                   \
                                    /* $2 = $1 <OP> val */                     \
            write_mem_seg(MEM_SEG, 0,                                          \
                          inst_comb(build_I_inst(funct, 1, 2, val), 0));       \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 2);                                          \
            if (!overflow_cond)                                                \
                EXPECT_EQ(RF->W_data, check_W_data);                           \
        })
#define ArithI32(name, opcode, overflow_expr, expr, num)                       \
    TestGenArithI(name, opcode, sign_extend(expr &MASK32, 32),                 \
                  TEST32OVERFLOW(overflow_expr), num);
#define TestAddI(AName, expr, num)                                             \
    ArithI32(ADDI##AName, 0x8, static_cast<int64_t>(num) + val, expr, num)
#define TestAddIU(AName, expr, num)                                            \
    ArithI32(ADDIU##AName, 0x9, static_cast<int64_t>(num) + val, expr, num);
#define TestOrI(AName, expr, num)                                              \
    ArithI32(ORI##AName, 0xd, val | (num & MASK16), expr, num);
#define TestXorI(AName, expr, num)                                             \
    ArithI32(XORI##AName, 0xe, val ^ (num & MASK16), expr, num);

TestGenArith2(TestAddI, val +);
TestGenArith2(TestAddIU, val +);
TestGenArith2(TestOrI, val |);
TestGenArith2(TestXorI, val ^);

#define ArithI64(name, opcode, overflow_expr, expr, num)                       \
    TestGenArithI(name, opcode, expr, TEST64OVERFLOW(overflow_expr), num);
#define TestDAddI(AName, expr, num)                                            \
    ArithI64(DADDI##AName, 0x18, static_cast<int64_t>(num) + val, expr, num)
#define TestDAddIU(AName, expr, num)                                           \
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
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0x4, 1, 2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512 + 4); });
TestGenMem(
    BEQ_Fail,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val + 1);
        // beq $1, $2, +512
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0x4, 1, 2, 512 >> 2), 0));
    },
    {
        // 4 stages
        EXPECT_EQ(FETCH_PC, 4 * 3);
    });
TestGenMem(
    BNE,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val + 1);
        // bne $1, $2, +512
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0x5, 1, 2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512 + 4); });
TestGenMem(
    BNE_Fail,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // bne $1, $2, +512
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_I_inst(0x5, 1, 2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 4 * 3); });
TestGenMemOnce(
    BC,
    {
        // bc $1, +512
        write_mem_seg(MEM_SEG, 0, inst_comb(build_J_inst(0x32, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512 + 4); });
TestGenMemOnceCycle(
    J,
    {
        // j +512
        write_mem_seg(MEM_SEG, 0, inst_comb(build_J_inst(0x2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512); }, 2);

TestGenMemOnceCycle(
    JAL,
    {
        // jal +512 (target = (512 >> 2))
        write_mem_seg(MEM_SEG, 0, inst_comb(build_J_inst(0x3, 512 >> 2), 0));
    },
    {
        // jal should jump to pc + 512, and store return address to $ra ($31)
        // EX stage
        EXPECT_EQ(FETCH_PC, 512);
        tick(); // MEM stage
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 31);
        EXPECT_EQ(RF->W_data, 4); // return address is pc + 4
    },
    2);
TestGenMemOnceCycle(
    JR,
    {
        // Set $4 = 0x0d00
        WRITE_RF(4, 0x0d00);
        // jr $4
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_R_inst(0x0, 4, 0, 0, 0, 0x08), 0));
    },
    { EXPECT_EQ(FETCH_PC, 0x0d00); }, 2);
TestGenMemOnceCycle(
    JALR,
    {
        // Set $4 = 0x0d00
        WRITE_RF(4, 0x0d00);
        // jalr $4
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_R_inst(0x0, 4, 0, 1, 0, 0x09), 0));
    },
    {
        EXPECT_EQ(FETCH_PC, 0x0d00);
        tick(); // MEM stage
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, 4); // return address is pc + 4
    },
    2);
TestGenMemOnceCycle(
    BAL,
    {
        // bal +512 (offset = 512 / 4 = 128)
        write_mem_seg(MEM_SEG, 0,
                      inst_comb(build_REGIMM_inst(0x1, 0x11, 0, 512 >> 2),
                                0)); // opcode=1, rt=17(BAL), rs=0
    },
    {
        // bal should jump to pc + 512, and store return address to $ra ($31)
        EXPECT_EQ(FETCH_PC, 512 + 4); // FETCH_PC updated after EX
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 31);
        EXPECT_EQ(RF->W_data,
                  4); // return address = pc + 4 from ID stage (pc = 0 + 4)
    },
    3);
TestGenMemOnceCycle(
    ADDIUPC,
    {
        // addiupc $1, 0xff
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_I_inst(0x3b, 1, 0, fixedVal<uint16_t>() >> 2), 0));
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, fixedVal<uint16_t>() & (~0b00));
    },
    3);

/* #endregion */

/* #region slt test */
TestGenMem(
    SLT,
    {
        WRITE_RF(1, val); // store val into reg $1
        WRITE_RF(2, 0);
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_R_inst(0, 1, 2, 3, 0, 0x2a), 0)); // slt $2, $1, $3
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data, static_cast<int64_t>(val) < 0);
    });

TestGenMem(
    SLTI,
    {
        WRITE_RF(1, val); // store val into reg $1
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_I_inst(0xa, 1, 2, 16), 0)); // slti $2, $1, 16
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 2);
        EXPECT_EQ(RF->W_data, static_cast<int64_t>(val) < 16);
    });

TestGenMem(
    SLTU,
    {
        WRITE_RF(1, val); // store val into reg $1
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_R_inst(0, 1, 2, 3, 0, 0x2b), 0)); // sltu $2, $1, $3
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data, val < 0);
    });

TestGenMem(
    SLTIU,
    {
        WRITE_RF(1, val); // store val into reg $1
        write_mem_seg(
            MEM_SEG, 0,
            inst_comb(build_I_inst(0xb, 1, 2, 16), 0)); // sltiu $2, $1, 16
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 2);
        EXPECT_EQ(RF->W_data, val < 16);
    });
/* #endregion */

TestGenMem(
    LSA,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, fixedVal<uint64_t>());
        write_mem_seg(MEM_SEG, 0,
                      inst_comb((2ULL << 21) | (1ULL << 16) | (3ULL << 11) |
                                    (4 << 6) | 0b101,
                                0)); // lsa $3, $2, $1, 4
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data,
                  sign_extend((fixedVal<uint64_t>() << 4) + val, 32));
    });
TestGenMem(
    DLSA,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, fixedVal<uint64_t>());
        write_mem_seg(MEM_SEG, 0,
                      inst_comb((2ULL << 21) | (1ULL << 16) | (3ULL << 11) |
                                    (4 << 6) | 0b10101,
                                0)); // lsa $3, $2, $1, 4
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data, (fixedVal<uint64_t>() << 4) + val);
    });

TestGenMemOnce(
    NOP,
    {
        write_mem_seg(MEM_SEG, 0, inst_comb(0, 0)); // nop
    },
    {
        EXPECT_EQ(FETCH_PC, 4 * 3);
        EXPECT_FALSE(RF->wr_enable);
    });
