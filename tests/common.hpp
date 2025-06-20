#ifndef TESTS_COMMON_HPP
#define TESTS_COMMON_HPP

#include <gtest/gtest.h>
#include <limits>
#include <random>
#include <verilated.h>
#include <verilated_cov.h>

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
        this->inst_->clock = 1;
        this->inst_->reset = 1;
        tick();
        this->inst_->reset = 0;
    }
    void TearDown() override {
        this->inst_->final();
        delete this->inst_;
    };
    void reset() {
        this->inst_->reset = 1;
        tick();
        this->inst_->reset = 0;
    }
};

template <class T, class Param>
class TestBaseWithParamI : public ::testing::WithParamInterface<Param>,
                           public TestBaseI<T> {};
template <class T, class Param>
class TestBaseWithParam : public ::testing::WithParamInterface<Param>,
                          public TestBase<T> {};

#endif // TESTS_COMMON_HPP
