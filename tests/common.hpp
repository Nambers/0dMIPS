#ifndef TESTS_COMMON_HPP
#define TESTS_COMMON_HPP

#define IDX_BITS 5 // log2(32)
#define IDX_MASK ((1 << IDX_BITS) - 1)
#define OFS_BITS 6 // log2(64)
#define OFS_MASK ((1 << OFS_BITS) - 1)

#define MASK5 0b11111
#define MASK6 0b111111
#define MASK16 0xffff
#define MASK32 0xffffffffULL
#define WORD_SIGN_MASK 0x80000000
#define WORD_HIGH_FULL 0xffffffff00000000
#define BYTE_HIGH_FULL 0xffffffffffffff00

#define MASKED(val, mask) ((val##mask) & (MASK##mask))

#include <endian.h>
#include <gtest/gtest.h>
#include <limits>
#include <random>
#include <verilated.h>
#include <verilated_cov.h>

extern bool dumpCov;

// for cache L1
inline uint64_t getTag(uint64_t addr) {
    return (addr >> (IDX_BITS + OFS_BITS));
}

inline unsigned int getIndex(uint64_t addr) {
    return (addr >> OFS_BITS) & IDX_MASK;
}

inline unsigned int getOffset(uint64_t addr) { return addr & OFS_MASK; }

// using DataType = VlUnpacked<VlUnpacked<VlWide<16> /*511:0*/, 64>, 2>;
// using ValidType = VlUnpacked<VlUnpacked<CData /*0:0*/, 64>, 2>;
// using DirtyType = VlUnpacked<VlUnpacked<CData /*0:0*/, 64>, 2>;
// using TagType = VlUnpacked<VlUnpacked<QData /*51:0*/, 64>, 2>;

template <typename T> uint64_t getAddrDWord(T *cache, uint64_t addr) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);
    assert(offset < 64 - sizeof(uint32_t));
    const auto index = getIndex(addr);
    const auto way = 0; // for test simplicity
    // data_line is 64bytes
    auto &data_line = cache->data_array[way][index];
    static_assert(sizeof(decltype(data_line[0])) == sizeof(uint32_t));
    uint64_t low = data_line[offset / sizeof(uint32_t)];
    uint64_t high = data_line[offset / sizeof(uint32_t) + 1];
    return (high << 32) | low;
}

template <typename T>
void setAddrDWord(T *cache, uint64_t addr, uint64_t dword) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);
    const auto index = getIndex(addr);
    const auto fixedWay = 0; // for test simplicity
    // data_line is 64bytes
    auto &data_line = cache->data_array[fixedWay][index];
    static_assert(sizeof(decltype(data_line[0])) == sizeof(uint32_t));
    data_line[offset / sizeof(uint32_t)] = dword & MASK32;
    data_line[offset / sizeof(uint32_t) + 1] = (dword >> 32) & MASK32;
    cache->valid_array[fixedWay][index] = 1;
    cache->tag_array[fixedWay][index] = getTag(addr);
    // printf("set to index=%d, tag=%lx\n", index, getTag(addr));
}

constexpr inline uint64_t inst_comb(uint32_t lo, uint32_t hi) {
    return (static_cast<uint64_t>(hi) << 32) | lo;
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
        if (dumpCov)
            Verilated::threadContextp()->coveragep()->write(
                std::string("logs/coverage_") +
                ::testing::UnitTest::GetInstance()
                    ->current_test_info()
                    ->name() +
                ".dat");
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

#endif // TESTS_COMMON_HPP
