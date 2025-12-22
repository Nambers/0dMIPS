#include "common.hpp"
#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_core_MEM.h>
#include <Core_regfile__W40.h>
#include <cstdint>

/* #region read test */
#define TestGenRead(name, opcode, check_W_data)                                \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            setAddrDWord(ICACHE, 0,                                            \
                         inst_comb(build_I_inst(opcode, 0, 1, 16), 0));        \
            setAddrDWord(DCACHE, (2) * 8, val);                                \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 1);                                          \
            EXPECT_EQ(RF->W_data, check_W_data);                               \
            tick();                                                            \
        })

TestGenRead(LB, 0x20, sign_extend(val & 0xff, 8));
TestGenRead(LBU, 0x24, val & 0xff);
TestGenRead(LH, 0x21, sign_extend(val &MASK16, 16));
TestGenRead(LHU, 0x25, val &MASK16);
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
            setAddrDWord(ICACHE, 0,                                            \
                         inst_comb(build_I_inst(opcode, 0, 1, 8), 0));         \
        },                                                                     \
        { EXPECT_EQ(getAddrDWord(DCACHE, 8), check_mem); })

TestGenWrite(SW, 0x2b, val &MASK32);
TestGenWrite(SH, 0x29, val &MASK16);
TestGenWrite(SB, 0x28, val & 0xff);
TestGenWrite(SD, 0x3f, val);
/* #endregion */

/* #region sign extend test */
#define TestGenSignExtend(name, opcode, func, check_W_data)                    \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            setAddrDWord(                                                      \
                ICACHE, 0,                                                     \
                inst_comb(build_R_inst(0b011111, 0, 1, 2, opcode, func), 0));  \
            WRITE_RF(1, val); /* store val into reg $1*/                       \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 2);                                          \
            EXPECT_EQ(RF->W_data, check_W_data);                               \
        })
TestGenSignExtend(SEB, 0b10000, 0b100000, sign_extend(val & 0xff, 8));
TestGenSignExtend(SEH, 0b11000, 0b100000, sign_extend(val &MASK16, 16));
/* #endregion */

// test both positive and negative 1
#define TestGenArith2_overflow(func_name, expr)                                \
    func_name(Pos, (expr 1), 1);                                               \
    func_name(Neg, (expr(-1)), -1)
#define TestGenArith2(func_name)                                               \
    func_name(Pos, 1);                                                         \
    func_name(Neg, -1)

// #define TEST32OVERFLOW(expr) ((expr) > INT32_MAX || (expr) < INT32_MIN)
#define TEST32OVERFLOW(a, b, op)                                               \
    __builtin_##op##_overflow_p(a, b, static_cast<int32_t>(0))
// #define TEST64OVERFLOW(expr) ((expr) > INT64_MAX || (expr) < INT64_MIN)
#define TEST64OVERFLOW(a, b, op)                                               \
    __builtin_##op##_overflow_p(a, b, static_cast<int64_t>(0))

/* #region R type arithmetics operations test */
#define TestGenArithR(name, rs, shamt, funct, check_W_data, fixed_val, rev)    \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            WRITE_RF(1, rev ? fixed_val : val); /* store 1 into reg $1*/       \
            WRITE_RF(2, rev ? val : fixed_val); /* store val into reg $2*/     \
                                                /* $3 = $1 <OP> $2 */          \
            setAddrDWord(                                                      \
                ICACHE, 0,                                                     \
                inst_comb(build_R_inst(0, rs, 2, 3, shamt, funct), 0));        \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 3);                                          \
            EXPECT_EQ(RF->W_data, check_W_data);                               \
        })
#define TestGenArithR_overflow(name, rs, shamt, funct, check_W_data,           \
                               overflow_cond, fixed_val)                       \
    TestGenMemNoCheck(                                                         \
        name, OVERFLOW_EXC,                                                    \
        {                                                                      \
            WRITE_RF(1, val);       /* store 1 into reg $1*/                   \
            WRITE_RF(2, fixed_val); /* store val into reg $2*/                 \
                                    /* $3 = $1 <OP> $2 */                      \
            setAddrDWord(                                                      \
                ICACHE, 0,                                                     \
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
#define Arith32_overflow(name, opcode, overflow_expr, expr, num)               \
    TestGenArithR_overflow(name, 1, 0, opcode, sign_extend(expr, 32),          \
                           overflow_expr, num);
#define Arith32(name, opcode, expr, num)                                       \
    TestGenArithR(name, 1, 0, opcode, sign_extend(expr, 32), num, false);
#define Arith32_rev(name, opcode, expr, num)                                   \
    TestGenArithR(name, 1, 0, opcode, sign_extend(expr, 32), num, true);
#define Arith32Shamt(name, opcode, expr, num)                                  \
    TestGenArithR(name, 0, num, opcode, sign_extend(expr, 32), 0, true);
#define Arith32ShamtRS1(name, opcode, expr, num)                               \
    TestGenArithR(name, 1, num, opcode, sign_extend(expr, 32), 0, true);
#define TestAdd(AName, expr, num)                                              \
    Arith32_overflow(ADD##AName, 0x20, TEST32OVERFLOW(val, num, add), expr,    \
                     num);
#define TestAddU(AName, expr, num)                                             \
    Arith32_overflow(ADDU##AName, 0x21, TEST32OVERFLOW(val, num, add), expr,   \
                     num);
#define TestSLL(AName, num) Arith32Shamt(SLL##AName, 0x00, val << num, num);
#define TestSRL(AName, num) Arith32Shamt(SRL##AName, 0x02, val >> num, num);
#define TestSRA(AName, num) Arith32Shamt(SRA##AName, 0x03, val >> num, num);
#define TestROTR(AName, num)                                                   \
    Arith32ShamtRS1(ROTR##AName, 0x02, (val >> num) | (val << (32 - num)), num);
#define TestSRLV(AName, num) Arith32_rev(SRLV##AName, 0x06, val >> num, num);
#define TestSub(AName, expr, num)                                              \
    Arith32_overflow(SUB##AName, 0x22, TEST32OVERFLOW(val, num, sub), expr,    \
                     num);

#define TestSubU(AName, expr, num)                                             \
    Arith32_overflow(SUBU##AName, 0x23, TEST32OVERFLOW(val, num, sub), expr,   \
                     num);

#define Arith64_overflow(name, opcode, overflow_expr, expr, num)               \
    TestGenArithR_overflow(name, 1, 0, opcode, expr, overflow_expr, num);
#define Arith64(name, opcode, expr, num)                                       \
    TestGenArithR(name, 1, 0, opcode, expr, num, false);
#define Arith64Shamt(name, opcode, expr, num)                                  \
    TestGenArithR(name, 0, num, opcode, expr, 0, true);
#define Arith64ShamtRS1(name, opcode, expr, num)                               \
    TestGenArithR(name, 1, num, opcode, expr, 0, true);
#define TestDAdd(AName, expr, num)                                             \
    Arith64_overflow(DADD##AName, 0x2c, TEST64OVERFLOW(val, num, add), expr,   \
                     num)
#define TestDAddU(AName, expr, num)                                            \
    Arith64_overflow(DADDU##AName, 0x2d, TEST64OVERFLOW(val, num, add), expr,  \
                     num);
#define TestDsll32(AName, num)                                                 \
    Arith64Shamt(DSLL32##AName, 0x3c, val << (num + 32), num);
#define TestDrotr(AName, num)                                                  \
    Arith64ShamtRS1(Drotr##AName, 0x3a, (val >> num) | (val << (64 - num)),    \
                    num);
#define TestAnd(AName, num) Arith64(AND##AName, 0x24, val &num, num);
#define TestOr(AName, num) Arith64(OR##AName, 0x25, val | num, num);
#define TestXor(AName, num) Arith64(XOR##AName, 0x26, val ^ num, num);
#define TestNor(AName, num) Arith64(NOR##AName, 0x27, ~(val | num), num);
#define TestDSub(AName, expr, num)                                             \
    Arith64_overflow(DSUB##AName, 0x2e, TEST64OVERFLOW(val, num, sub), expr,   \
                     num);

TestGenArith2(TestAnd);
TestGenArith2(TestOr);
TestGenArith2(TestXor);
TestSLL(1, 1);
TestSLL(4, 4);
TestSRL(1, 1);
TestSRL(5, 5);
TestSRA(1, 1);
TestNor(1, 1);
TestNor(f, 0xf);
TestNor(Neg1, -1);
TestROTR(1, 1);
TestROTR(4, 4);
TestSRLV(1, 1);
TestSRLV(5, 5);

TestGenArith2_overflow(TestAdd, val +);
TestGenArith2_overflow(TestAddU, val +);
TestGenArith2_overflow(TestDAdd, val +);
TestGenArith2_overflow(TestDAddU, val +);
TestDsll32(1, 1);
TestDrotr(1, 1);
TestDrotr(4, 4);
TestGenArith2_overflow(TestSub, val -);
TestGenArith2_overflow(TestSubU, val -);
TestGenArith2_overflow(TestDSub, val -);
/* #endregion */

/* #region I type arithemtics operations test */
TestGenMem(
    LUI,
    {
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_I_inst(0xf, 0, 1, val & MASK16), 0));
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, sign_extend((val & MASK16) << 16, 32));
    });
#define TestGenArithI(name, funct, check_W_data, fixed_val)                    \
    TestGenMem(                                                                \
        name,                                                                  \
        {                                                                      \
            WRITE_RF(1, val); /* store 1 into reg $1*/                         \
                              /* $2 = $1 <OP> val */                           \
            setAddrDWord(ICACHE, 0,                                            \
                         inst_comb(build_I_inst(funct, 1, 2, fixed_val), 0));  \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 2);                                          \
            EXPECT_EQ(RF->W_data, check_W_data);                               \
        })
#define TestGenArithI_overflow(name, funct, check_W_data, overflow_cond,       \
                               fixed_val)                                      \
    TestGenMemNoCheck(                                                         \
        name, OVERFLOW_EXC,                                                    \
        {                                                                      \
            WRITE_RF(1, val); /* store 1 into reg $1*/                         \
                              /* $2 = $1 <OP> val */                           \
            setAddrDWord(ICACHE, 0,                                            \
                         inst_comb(build_I_inst(funct, 1, 2, fixed_val), 0));  \
        },                                                                     \
        {                                                                      \
            EXPECT_TRUE(RF->wr_enable);                                        \
            EXPECT_EQ(RF->W_addr, 2);                                          \
            if (!overflow_cond)                                                \
                EXPECT_EQ(RF->W_data, check_W_data);                           \
        })
#define ArithI32_overflow(name, opcode, overflow_expr, expr, num)              \
    TestGenArithI_overflow(name, opcode, sign_extend(expr &MASK32, 32),        \
                           overflow_expr, num);
#define ArithI32(name, opcode, expr, num)                                      \
    TestGenArithI(name, opcode, sign_extend(expr &MASK32, 32), num);
#define TestAddI(AName, expr, num)                                             \
    ArithI32_overflow(ADDI##AName, 0x8, TEST32OVERFLOW(val, num, add), expr,   \
                      num)
#define TestAddIU(AName, expr, num)                                            \
    ArithI32_overflow(ADDIU##AName, 0x9, TEST32OVERFLOW(val, num, add), expr,  \
                      num);

#define ArithI64_overflow(name, opcode, overflow_expr, expr, num)              \
    TestGenArithI_overflow(name, opcode, expr, overflow_expr, num);
#define ArithI64(name, opcode, expr, num)                                      \
    TestGenArithI(name, opcode, expr, num);
#define TestDAddI(AName, expr, num)                                            \
    ArithI64_overflow(DADDI##AName, 0x18, TEST64OVERFLOW(val, num, add), expr, \
                      num)
#define TestDAddIU(AName, expr, num)                                           \
    ArithI64_overflow(DADDIU##AName, 0x19, TEST64OVERFLOW(val, num, add),      \
                      expr, num);
#define TestOrI(AName, num)                                                    \
    ArithI64(ORI##AName, 0xd, (val & MASK64) | (num & MASK16), num);
#define TestXorI(AName, num)                                                   \
    ArithI64(XORI##AName, 0xe, (val & MASK64) ^ (num & MASK16), num);

TestGenArith2_overflow(TestAddI, val +);
TestGenArith2_overflow(TestAddIU, val +);
TestGenArith2(TestOrI);
TestGenArith2(TestXorI);
TestGenArith2_overflow(TestDAddI, val +);
TestGenArith2_overflow(TestDAddIU, val +);
/* #endregion */

/* #region branching test */
TestGenMemCycle(
    BEQ,
    {
        preloadCacheLine(ICACHE, 512, 516);
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // beq $1, $2, +512
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_I_inst(0x4, 1, 2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512 + 4); }, 5);
TestGenMemCycle(
    BEQ_Fail,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val + 1);
        // beq $1, $2, +512
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_I_inst(0x4, 1, 2, 512 >> 2), 0));
    },
    {
        // 5 stages
        EXPECT_EQ(FETCH_PC, 4 * 4);
    },
    5);
TestGenMemCycle(
    BNE,
    {
        preloadCacheLine(ICACHE, 512, 516);
        WRITE_RF(1, val);
        WRITE_RF(2, val + 1);
        // bne $1, $2, +512
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_I_inst(0x5, 1, 2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512 + 4); }, 5);
TestGenMemCycle(
    BNE_Fail,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, val);
        // bne $1, $2, +512
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_I_inst(0x5, 1, 2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 4 * 4); }, 5);
TestGenMemOnceCycle(
    BC,
    {
        preloadCacheLine(ICACHE, 512, 516);
        // bc $1, +512
        setAddrDWord(ICACHE, 0, inst_comb(build_J_inst(0x32, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512 + 4); }, 5);
TestGenMemOnceCycle(
    J,
    {
        preloadCacheLine(ICACHE, 512, 516);
        // j +512
        setAddrDWord(ICACHE, 0, inst_comb(build_J_inst(0x2, 512 >> 2), 0));
    },
    { EXPECT_EQ(FETCH_PC, 512); }, 4);

TestGenMemOnceCycle(
    JAL,
    {
        preloadCacheLine(ICACHE, 512, 516);
        // jal +512 (target = (512 >> 2))
        setAddrDWord(ICACHE, 0, inst_comb(build_J_inst(0x3, 512 >> 2), 0));
    },
    {
        // jal should jump to pc + 512, and store return address to $ra ($31)
        // EX stage
        EXPECT_EQ(FETCH_PC, 512);
        tick(); // MEM1 finished
        tick(); // MEM2 finished
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 31);
        EXPECT_EQ(RF->W_data, 4); // return address is pc + 4
    },
    4);
TestGenMemOnceCycle(
    JR,
    {
        preloadCacheLine(ICACHE, 0x0d00, 0x0d04);
        // Set $4 = 0x0d00
        WRITE_RF(4, 0x0d00);
        // jr $4
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_R_inst(0x0, 4, 0, 0, 0, 0x08), 0));
    },
    { EXPECT_EQ(FETCH_PC, 0x0d00); }, 4);
TestGenMemOnceCycle(
    JALR,
    {
        preloadCacheLine(ICACHE, 0x0d00, 0x0d04);
        // Set $4 = 0x0d00
        WRITE_RF(4, 0x0d00);
        // jalr $4
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_R_inst(0x0, 4, 0, 1, 0, 0x09), 0));
    },
    {
        EXPECT_EQ(FETCH_PC, 0x0d00);
        tick(); // MEM stage
        tick();
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, 4); // return address is pc + 4
    },
    4);
TestGenMemOnceCycle(
    BAL,
    {
        preloadCacheLine(ICACHE, 512, 520);
        // bal +512 (offset = 512 / 4 = 128)
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_REGIMM_inst(0x1, 0x11, 0, 512 >> 2),
                               0)); // opcode=1, rt=17(BAL), rs=0
    },
    {
        // bal should jump to pc + 512, and store return address to $ra ($31)
        EXPECT_EQ(FETCH_PC, 512 + 4); // FETCH_PC updated after EX
        tick();
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 31);
        EXPECT_EQ(RF->W_data,
                  4); // return address = pc + 4 from ID stage (pc = 0 + 4)
    },
    5);
TestGenMemOnce(
    ADDIUPC,
    {
        // addiupc $1, 0xff
        setAddrDWord(
            ICACHE, 0,
            inst_comb(build_I_inst(0x3b, 1, 0, fixedVal<uint16_t>() >> 2), 0));
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 1);
        EXPECT_EQ(RF->W_data, fixedVal<uint16_t>() & (~0b00));
    });

/* #endregion */

/* #region slt test */
TestGenMem(
    SLT,
    {
        WRITE_RF(1, val); // store val into reg $1
        WRITE_RF(2, 0);
        setAddrDWord(
            ICACHE, 0,
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
        setAddrDWord(
            ICACHE, 0,
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
        setAddrDWord(
            ICACHE, 0,
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
        setAddrDWord(
            ICACHE, 0,
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
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_R_inst(0, 2, 1, 3, 4, 0b101),
                               0)); // lsa $3, $2, $1, 4
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data,
                  sign_extend((fixedVal<uint64_t>() << (4 + 1)) + val, 32));
    });
TestGenMem(
    DLSA,
    {
        WRITE_RF(1, val);
        WRITE_RF(2, fixedVal<uint64_t>());
        setAddrDWord(ICACHE, 0,
                     inst_comb(build_R_inst(0, 2, 1, 3, 4, 0b10101),
                               0)); // lsa $3, $2, $1, 4
    },
    {
        EXPECT_TRUE(RF->wr_enable);
        EXPECT_EQ(RF->W_addr, 3);
        EXPECT_EQ(RF->W_data, (fixedVal<uint64_t>() << (4 + 1)) + val);
    });

TestGenMemOnce(
    NOP,
    {
        setAddrDWord(ICACHE, 0, inst_comb(0, 0)); // nop
    },
    {
        EXPECT_EQ(FETCH_PC, 4 * 5);
        EXPECT_FALSE(RF->wr_enable);
    });
