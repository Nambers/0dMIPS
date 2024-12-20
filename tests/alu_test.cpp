#include <Alu.h>

#include <bitset>
#include <random>

#include "common.hpp"

#define ALU_ADD 0b010
#define ALU_SUB 0b011
#define ALU_AND 0b100
#define ALU_OR 0b101
#define ALU_NOR 0b110
#define ALU_XOR 0b111

class ALUTest : public TestBaseI<Alu> {
   protected:
    void tick() override { inst_->eval(); }
    void SetUp() override { inst_ = new Alu; }
    void TearDown() override {
        inst_->final();
        delete inst_;
    }
};

#define TEST_ALU_OP(op, op2, test_au)                                     \
    TEST_F(ALUTest, ALU##op##Test) {                                      \
        DIST_TYPE dist(INT32_MIN, INT32_MAX);                             \
        for (int i = 0; i < 100; i++) {                                   \
            const int32_t a = getRandomInt(dist), b = getRandomInt(dist); \
            inst_->alu__02Ea = a;                                         \
            inst_->alu__02Eb = b;                                         \
            inst_->alu_op = ALU_##op;                                     \
            tick();                                                       \
            const int64_t result = op2;                                   \
            if (test_au) {                                                \
                EXPECT_EQ(inst_->overflow,                                \
                          result > INT32_MAX || result < INT32_MIN);      \
                if (!inst_->overflow) {                                   \
                    EXPECT_EQ(static_cast<int32_t>(inst_->alu__02Eout),   \
                              static_cast<int32_t>(result));              \
                    EXPECT_EQ(inst_->zero, result == 0);                  \
                    EXPECT_EQ(inst_->negative, result < 0);               \
                }                                                         \
            } else {                                                      \
                EXPECT_EQ(static_cast<int32_t>(inst_->alu__02Eout),       \
                          static_cast<int32_t>(result));                  \
            }                                                             \
        }                                                                 \
    }

TEST_ALU_OP(ADD, static_cast<int64_t>(a) + b, 1)
TEST_ALU_OP(SUB, static_cast<int64_t>(a) - b, 1)
TEST_ALU_OP(AND, a &b, 0)
TEST_ALU_OP(OR, a | b, 0)
TEST_ALU_OP(NOR, ~(a | b), 0)
TEST_ALU_OP(XOR, a ^ b, 0)
