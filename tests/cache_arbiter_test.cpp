#include <Cache_arbiter.h>

#include "cache_test.hpp"
#include "common.hpp"

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