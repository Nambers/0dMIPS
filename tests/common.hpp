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

#define CACHE_DATA(way, word)                                                  \
    cache                                                                      \
        ->way_bank__BRA__##way##__KET____DOT__word_bank__BRA__##word##__KET____DOT__data
template <typename T>
auto &cacheDataBank(T *cache, unsigned int way, unsigned int word) {
    assert(way < 2);
    assert(word < 8);

    if (way == 0) {
        switch (word) {
        case 0:
            return CACHE_DATA(0, 0);
        case 1:
            return CACHE_DATA(0, 1);
        case 2:
            return CACHE_DATA(0, 2);
        case 3:
            return CACHE_DATA(0, 3);
        case 4:
            return CACHE_DATA(0, 4);
        case 5:
            return CACHE_DATA(0, 5);
        case 6:
            return CACHE_DATA(0, 6);
        case 7:
            return CACHE_DATA(0, 7);
        }
    }

    switch (word) {
    case 0:
        return CACHE_DATA(1, 0);
    case 1:
        return CACHE_DATA(1, 1);
    case 2:
        return CACHE_DATA(1, 2);
    case 3:
        return CACHE_DATA(1, 3);
    case 4:
        return CACHE_DATA(1, 4);
    case 5:
        return CACHE_DATA(1, 5);
    case 6:
        return CACHE_DATA(1, 6);
    case 7:
        return CACHE_DATA(1, 7);
    }

    __builtin_unreachable();
}

#undef CACHE_DATA

template <typename T>
uint64_t readCacheDWord(T *cache, unsigned int way, uint64_t addr) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);

    const auto index = getIndex(addr);
    const auto word_idx = offset / sizeof(uint64_t);
    const auto byte_idx = offset % sizeof(uint64_t);
    const auto low_word = cacheDataBank(cache, way, word_idx)[index];

    if (byte_idx == 0)
        return low_word;

    assert(word_idx + 1 < 8);
    const auto high_word = cacheDataBank(cache, way, word_idx + 1)[index];
    const auto shift = byte_idx * 8;
    return (low_word >> shift) | (high_word << (64 - shift));
}

template <typename T>
void writeCacheDWord(T *cache, unsigned int way, uint64_t addr,
                     uint64_t dword) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);

    const auto index = getIndex(addr);
    const auto word_idx = offset / sizeof(uint64_t);
    const auto byte_idx = offset % sizeof(uint64_t);
    auto &low_word = cacheDataBank(cache, way, word_idx)[index];

    if (byte_idx == 0) {
        low_word = dword;
        return;
    }

    assert(word_idx + 1 < 8);
    auto &high_word = cacheDataBank(cache, way, word_idx + 1)[index];
    const auto shift = byte_idx * 8;
    const uint64_t low_keep_mask = (1ULL << shift) - 1;
    const uint64_t high_keep_mask = ~((1ULL << (64 - shift)) - 1);

    low_word = (low_word & low_keep_mask) | (dword << shift);
    high_word = (high_word & high_keep_mask) | (dword >> (64 - shift));
}

template <typename T> uint64_t getAddrDWord(T *cache, uint64_t addr) {
    const auto way = 0; // for test simplicity
    return readCacheDWord(cache, way, addr);
}

template <typename T>
void setAddrDWord(T *cache, uint64_t addr, uint64_t dword) {
    const auto index = getIndex(addr);
    const auto fixedWay = 0; // for test simplicity
    writeCacheDWord(cache, fixedWay, addr, dword);
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
