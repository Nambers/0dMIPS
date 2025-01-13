#include <gtest/gtest.h>
#include <verilated.h>
#include <verilated_cov.h>

#include <random>

template <class T>
class TestBaseI : public testing::Test {
   protected:
    using DIST_TYPE = std::uniform_int_distribution<std::mt19937::result_type>;
    TestBaseI() : rng(dev()), ctx() {};
    virtual void tick() = 0;
    virtual void SetUp() = 0;
    virtual void TearDown() = 0;
    inline int getRandomInt(DIST_TYPE dist) { return dist(rng); }

    T *inst_ = nullptr;
    std::random_device dev;
    std::mt19937 rng;
    VerilatedContext ctx;
};

template <class T>
class TestBase : public TestBaseI<T> {
   protected:
    T *inst_;
    virtual void customSetUp() {};
    void tick() override {
        inst_->clock = !inst_->clock;
        inst_->eval();
        this->ctx.timeInc(1);
        inst_->clock = !inst_->clock;
        inst_->eval();
        this->ctx.timeInc(1);
    };
    void SetUp() override {
        inst_ = new T{&this->ctx};
        inst_->clock = 1;
        inst_->reset = 1;
        tick();
        inst_->reset = 0;
        customSetUp();
    };
    void TearDown() override {
        inst_->final();
        delete inst_;
    };
};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    testing::InitGoogleTest(&argc, argv);
    auto res = RUN_ALL_TESTS();
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
    return res;
}
