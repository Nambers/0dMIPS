#include <Cache_L1.h>
#include <Cache_L1_cache_L1.h>

#include "common.hpp"

inline unsigned int getTag(uint64_t addr) { return (addr >> 12); }

inline unsigned int getIndex(uint64_t addr) { return (addr >> 6) & 0x3f; }

inline unsigned int getOffset(uint64_t addr) { return addr & 0x3f; }

class Cache_L1Test : public TestBase<Cache_L1> {
  public:
    std::uniform_int_distribution<uint64_t> addrDist{0, UINT64_MAX};
};

TEST_F(Cache_L1Test, readMissTest) {
    const uint64_t testAddr = addrDist(rng);
    inst_->addr = testAddr;
    inst_->mem_load_type = 3; // LW
    tick();
    EXPECT_TRUE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    // EXPECT_EQ(inst_->mem_addr, testAddr & ~0x3fULL);
}
