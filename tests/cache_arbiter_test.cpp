#include <Cache_arbiter.h>

#include "cache_test.hpp"
#include "common.hpp"

#define IDX_BITS 6 // log2(64)
#define IDX_MASK ((1 << IDX_BITS) - 1)
#define OFS_BITS 6 // log2(64)
#define OFS_MASK ((1 << OFS_BITS) - 1)
#define TAG_BITS (64 - IDX_BITS - OFS_BITS)

class Cache_arbiterTest : public CacheTest<Cache_arbiter> {
  public:
    std::uniform_int_distribution<uint64_t> addrDist{0, UINT64_MAX};
};

TEST_F(Cache_arbiterTest, C1_Test) {
    const auto testAddr = addrDist(rng) & ~0x3F; // align to 64B
}

TEST_F(Cache_arbiterTest, C2_Test) {}

TEST_F(Cache_arbiterTest, C1C2_SameTimeTest) {}

TEST_F(Cache_arbiterTest, C2_After_C1_Test) {}

TEST_F(Cache_arbiterTest, C1_After_C2_Test) {}