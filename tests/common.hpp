#ifndef TESTS_COMMON_HPP
#define TESTS_COMMON_HPP

#include <endian.h>
#include <gtest/gtest.h>
#include <limits>
#include <random>
#include <verilated.h>
#include <verilated_cov.h>

constexpr inline uint64_t inst_comb(uint32_t a, uint32_t b) {
    return htole64(be64toh((static_cast<uint64_t>(b) << 32) | (a)));
}

constexpr inline int64_t sign_extend(uint64_t val, int bits) {
    return static_cast<int64_t>(val << (64 - bits)) >> (64 - bits);
}

template <class T> class TestBaseI : public testing::Test {
  protected:
    TestBaseI() : rng(std::random_device{}()), ctx() {}
    virtual void tick() = 0;
    virtual void SetUp() override = 0;
    virtual void TearDown() override = 0;

    T *inst_ = nullptr;
    std::mt19937 rng;
    VerilatedContext ctx;
};

template <class T> class TestBase : public TestBaseI<T> {
  protected:
    void tick() override {
        this->inst_->clock = !this->inst_->clock;
        this->inst_->eval();
        this->ctx.timeInc(1);
        this->inst_->clock = !this->inst_->clock;
        this->inst_->eval();
        this->ctx.timeInc(1);
    }
    void SetUp() override {
        this->inst_ = new T{&this->ctx};
        this->inst_->clock = 0;
        reset();
    }
    void TearDown() override {
        this->inst_->final();
        delete this->inst_;
    };
    void reset() {
        this->inst_->reset = 1;
        tick();
        tick();
        this->inst_->reset = 0;
        this->ctx.time(0);
    }
};

template <class T, class Param>
class TestBaseWithParamI : public ::testing::WithParamInterface<Param>,
                           public TestBaseI<T> {};
template <class T, class Param>
class TestBaseWithParam : public ::testing::WithParamInterface<Param>,
                          public TestBase<T> {};

#endif // TESTS_COMMON_HPP
