#include <Core.h>
#include <Core_core.h>
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D40.h>
#include <Core_regfile__W40.h>

#include <fstream>
#include <iomanip>

#include "common.hpp"

#define MASK5 0b11111
#define MASK6 0b111111
#define MASK32 0xffffffff
#define WORD_SIGN_MASK 0x80000000
#define WORD_HIGH_FULL 0xffffffff00000000
#define BYTE_HIGH_FULL 0xffffffffffffff00

#define MASKED(val, mask) ((val##mask) & (MASK##mask))
#define u64(a, b) ((uint64_t(a) << 32) | uint64_t(b))

const uint64_t common_boundary_cases[] = {
    0, 1, 0x7fffffffffffffff, 0x8000000000000000, 0xffffffffffffffff};

#define MEM_SEG inst_->core->MEM_stage->mem->data_seg
#define RF inst_->core->ID_stage->rf

#define SET_INST(inst) MEM_SEG[0] = (uint64_t)(inst) << 32;

#define WRITE_RF(addr, data) \
    RF->W_data = data;       \
    RF->wr_enable = 1;       \
    RF->W_addr = addr;       \
    tick()

#define RESET_PC() inst_->core->pc = 0

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
        if (startAddr >= mem.size()) {
            std::cerr << "Memory size exceeded!" << std::endl;
            break;
        }
        file >> std::hex >> mem[startAddr++];
    }
    file.close();
}

class CoreTest : public TestBase<Core> {
    void customSetUp() override {
        std::system("mkdir -p test_tmp >> /dev/null");
    }
};

uint32_t build_R_inst(uint8_t opcode6, uint8_t rs5, uint8_t rt5, uint8_t rd5,
                      uint8_t shift5, uint8_t funct6) {
    return (MASKED(opcode, 6) << 26) | (MASKED(rs, 5) << 21) |
           (MASKED(rt, 5) << 16) | (MASKED(rd, 5) << 11) |
           (MASKED(shift, 5) << 6) | MASKED(funct, 6);
}

uint32_t build_I_inst(uint8_t opcode6, uint8_t rs5, uint8_t rt5,
                      int16_t imm16) {
    return (MASKED(opcode, 6) << 26) | (MASKED(rs, 5) << 21) |
           (MASKED(rt, 5) << 16) | imm16;
}

#define TestGen(name, init_test, pre_test, check_result) \
    TEST_F(CoreTest, name) {                             \
        for (const auto val : common_boundary_cases) {   \
            reset();                                     \
            MEM_SEG[0] = 0;                              \
            MEM_SEG[1] = 0;                              \
            RESET_PC();                                  \
            init_test;                                   \
            RESET_PC();                                  \
            pre_test;                                    \
            inst_->core->pc = 4;                         \
            tick(); /* IF Stage */                       \
            /* all reset to pc = 0 so it will do nop*/   \
            RESET_PC();                                  \
            tick(); /* ID Stage */                       \
            inst_->core->pc -= 4;                        \
            tick(); /* EX Stage */                       \
            inst_->core->pc -= 4;                        \
            tick(); /* MEM Stage */                      \
            check_result;                                \
        }                                                \
    }

/* #region read test */
#define TestGenRead(name, opcode, check_W_data)              \
    TestGen(                                                 \
        name, { SET_INST(build_I_inst(opcode, 0, 1, 16)); }, \
        { MEM_SEG[2] = val; },                               \
        {                                                    \
            EXPECT_TRUE(RF->wr_enable);                      \
            EXPECT_EQ(RF->W_addr, 1);                        \
            EXPECT_EQ(RF->W_data, check_W_data);             \
        })

TestGenRead(LB, 0x20, (val & 0xff) | ((val & 0x80) ? BYTE_HIGH_FULL : 0));
TestGenRead(LBU, 0x24, val & 0xff);
TestGenRead(LW, 0x23,
            (val & MASK32) | ((val & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0));
TestGenRead(LWU, 0x27, val &MASK32);
TestGenRead(LD, 0x37, val);
/* #endregion */

/* #region write test */
#define TestGenWrite(name, opcode, check_mem)            \
    TestGen(                                             \
        name, ,                                          \
        {                                                \
            RESET_PC();                                  \
            WRITE_RF(1, val); /* store val into reg $1*/ \
            SET_INST(build_I_inst(opcode, 0, 1, 8));     \
        },                                               \
        { EXPECT_EQ(MEM_SEG[1], check_mem); })

TestGenWrite(SW, 0x2b, val &MASK32);
TestGenWrite(SB, 0x28, val & 0xff);
TestGenWrite(SD, 0x3f, val);
/* #endregion */

/* #region R type arithmetics operations test */
#define TestGenArithR(name, funct, check_W_data, overflow_cond, fixed_val) \
    TestGen(                                                               \
        name,                                                              \
        {                                                                  \
            RESET_PC();                                                    \
            WRITE_RF(1, fixed_val); /* store 1 into reg $1*/               \
            /* $3 = $1 <OP> $2 */                                          \
            SET_INST(build_R_inst(0, 1, 2, 3, 0, funct));                  \
        },                                                                 \
        {                                                                  \
            RESET_PC();                                                    \
            WRITE_RF(2, val); /* store val into reg $2*/                   \
        },                                                                 \
        {                                                                  \
            EXPECT_TRUE(RF->wr_enable);                                    \
            EXPECT_EQ(RF->W_addr, 3);                                      \
            if (!overflow_cond) EXPECT_EQ(RF->W_data, check_W_data);       \
        })

// test both positive and negative 1
#define TestGenArithR2(func_name, expr) \
    func_name(Pos, (expr 1), 1);        \
    func_name(Neg, (expr(-1)), -1)

#define TEST32OVERFLOW(expr) ((expr) > INT32_MAX || (expr) < INT32_MIN)

/*
@args:
    name: test name
    opcode: funct field in R type instruction from mips_define.sv
    overflow_expr: overflow condition
    expr: expected result expr
    num: resevered arg for TestGenArithR2
*/
#define Arith32(name, opcode, overflow_expr, expr, num)                \
    TestGenArithR(                                                     \
        name, opcode,                                                  \
        expr &MASK32 | ((expr & WORD_SIGN_MASK) ? WORD_HIGH_FULL : 0), \
        TEST32OVERFLOW(overflow_expr), num);

#define TestAdd(AName, expr, num) \
    Arith32(ADD##AName, 0x20, (int64_t)num + val, expr, num)
#define TestAddU(AName, expr, num) \
    Arith32(ADDU##AName, 0x21, (int64_t)num + val, expr, num);

TestGenArithR2(TestAdd, val +);
TestGenArithR2(TestAddU, val +);

#define TestSub(AName, expr, num) \
    Arith32(SUB##AName, 0x22, (int64_t)num - val, expr, num);

#define TestSubU(AName, expr, num) \
    Arith32(SUBU##AName, 0x23, (int64_t)num - val, expr, num);

TestGenArithR2(TestSub, val -);
TestGenArithR2(TestSubU, val -);
/* #endregion */

/* #region branching test */
TestGen(
    BEQ,
    {
        // beq $1, $2, 8
        SET_INST(build_I_inst(0x4, 1, 2, 16));
    },
    {
        RESET_PC();
        WRITE_RF(1, val);
        RESET_PC();
        WRITE_RF(2, val);
        std::cout << "val: " << val << std::endl;
    },
    { EXPECT_EQ(inst_->core->pc, 16); })
    TestGen(
        BEQ_F,
        {
            // beq $1, $2, 8
            SET_INST(build_I_inst(0x4, 1, 2, 16));
        },
        {
            RESET_PC();
            WRITE_RF(1, val);
            RESET_PC();
            WRITE_RF(2, val + 1);
        },
        { EXPECT_EQ(inst_->core->pc, 4); })
    /* #endregion */