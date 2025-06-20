#include "Alu.h"
#include "common.hpp"
#include <cstdint>
#include <gtest/gtest.h>
#include <limits>
#include <memory>
#include <random>

#define ALU_ADD 0b010
#define ALU_SUB 0b011
#define ALU_AND 0b100
#define ALU_OR 0b101
#define ALU_NOR 0b110
#define ALU_XOR 0b111

struct ALUParam {
    std::string name;
    int code;
    std::function<int64_t(int32_t, int32_t)> compute;
    bool testAu;
};

class ALUTest : public TestBaseWithParamI<Alu, ALUParam> {
  protected:
    std::uniform_int_distribution<int32_t> dist{INT32_MIN, INT32_MAX};
    void tick() override {
        // no need to clock
        inst_->eval();
    }
    void SetUp() override { inst_ = new Alu{&this->ctx}; }
    void TearDown() override {
        inst_->final();
        delete inst_;
        inst_ = nullptr;
    }
};

TEST_P(ALUTest, ALUTest) {
    const auto &p = GetParam();

    for (int i = 0; i < 100; ++i) {
        int32_t a = dist(rng);
        int32_t b = dist(rng);

        inst_->a = a;
        inst_->b = b;
        inst_->alu_op = p.code;
        tick();

        int64_t expected = p.compute(a, b);
        bool overflowed = (expected > std::numeric_limits<int32_t>::max()) ||
                          (expected < std::numeric_limits<int32_t>::min());

        if (p.testAu) {
            EXPECT_EQ(inst_->overflow, overflowed);
            if (!inst_->overflow) {
                EXPECT_EQ(static_cast<int32_t>(inst_->out),
                          static_cast<int32_t>(expected));
                EXPECT_EQ(inst_->zero, expected == 0);
                EXPECT_EQ(inst_->negative, expected < 0);
            }
        } else {
            EXPECT_EQ(static_cast<int32_t>(inst_->out),
                      static_cast<int32_t>(expected));
        }
    }
}

INSTANTIATE_TEST_SUITE_P(
    ALUOperations, ALUTest,
    ::testing::Values(
        ALUParam{"Add", ALU_ADD, [](auto a, auto b) { return int64_t(a) + b; },
                 true},
        ALUParam{"Sub", ALU_SUB, [](auto a, auto b) { return int64_t(a) - b; },
                 true},
        ALUParam{"And", ALU_AND, [](auto a, auto b) { return a & b; }, false},
        ALUParam{"Or", ALU_OR, [](auto a, auto b) { return a | b; }, false},
        ALUParam{"Nor", ALU_NOR, [](auto a, auto b) { return ~(a | b); },
                 false},
        ALUParam{"Xor", ALU_XOR, [](auto a, auto b) { return a ^ b; }, false}),
    [](const ::testing::TestParamInfo<ALUTest::ParamType> &info) {
        return info.param.name;
    });
