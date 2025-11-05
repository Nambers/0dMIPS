#include <Cache_L1.h>
#include <Cache_L1_cache_L1.h>

#include "cache_test.hpp"
#include "common.hpp"

#define IDX_BITS 6 // log2(64)
#define IDX_MASK ((1 << IDX_BITS) - 1)
#define OFS_BITS 6 // log2(64)
#define OFS_MASK ((1 << OFS_BITS) - 1)
#define TAG_BITS (64 - IDX_BITS - OFS_BITS)

inline unsigned int getTag(uint64_t addr) {
    return (addr >> (IDX_BITS + OFS_BITS));
}

inline unsigned int getIndex(uint64_t addr) {
    return (addr >> OFS_BITS) & IDX_MASK;
}

inline unsigned int getOffset(uint64_t addr) { return addr & OFS_MASK; }

class Cache_L1Test : public CacheTest<Cache_L1> {
  public:
    std::uniform_int_distribution<uint64_t> addrDist{0, UINT64_MAX};
};

TEST_F(Cache_L1Test, readTest) {
    const uint64_t testAddr = addrDist(rng) & ~0x3F; // align to 64B
    inst_->addr = testAddr;
    inst_->mem_load_type = 3; // LW
    tick();
    EXPECT_TRUE(getLoad());
    EXPECT_FALSE(getStore());
    EXPECT_EQ(getMemAddr(), testAddr >> OFS_BITS);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    setDataByte(getOffset(testAddr) + 0, 0xef);
    setDataByte(getOffset(testAddr) + 1, 0xbe);
    setDataByte(getOffset(testAddr) + 2, 0xad);
    setDataByte(getOffset(testAddr) + 3, 0xde);
    setReady(true);
    tick();

    setDataByte(getOffset(testAddr) + 0, 0);
    setDataByte(getOffset(testAddr) + 1, 0);
    setDataByte(getOffset(testAddr) + 2, 0);
    setDataByte(getOffset(testAddr) + 3, 0);
    setReady(false);

    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0xdeadbeef, 32));
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());
    tick();
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0xdeadbeef, 32));
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());

    // test new read
    uint64_t testAddr2 = addrDist(rng) & ~0x3F;
    while (getTag(testAddr2) == getTag(testAddr) &&
           getIndex(testAddr2) == getIndex(testAddr)) {
        testAddr2 = addrDist(rng);
    }
    inst_->addr = testAddr2;
    tick();
    EXPECT_TRUE(getLoad());
    EXPECT_FALSE(getStore());
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    setDataByte(getOffset(testAddr2) + 0, 0x78);
    setDataByte(getOffset(testAddr2) + 1, 0x56);
    setDataByte(getOffset(testAddr2) + 2, 0x34);
    setDataByte(getOffset(testAddr2) + 3, 0x12);
    setReady(true);
    tick();

    setDataByte(getOffset(testAddr2) + 0, 0);
    setDataByte(getOffset(testAddr2) + 1, 0);
    setDataByte(getOffset(testAddr2) + 2, 0);
    setDataByte(getOffset(testAddr2) + 3, 0);
    setReady(false);
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0x12345678, 32));
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());
    tick();
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0x12345678, 32));
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());

    // test read back to first address
    inst_->addr = testAddr;
    tick();
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0xdeadbeef, 32));
}

TEST_F(Cache_L1Test, writeTest) {
    const uint64_t testAddr = addrDist(rng);
    inst_->addr = testAddr;
    inst_->wdata = 0xdeadbeef;
    inst_->mem_store_type = 3; // SW

    tick();
    EXPECT_TRUE(getLoad());
    EXPECT_FALSE(getStore());
    EXPECT_EQ(getMemAddr(), testAddr >> OFS_BITS);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    setDataByte(getOffset(testAddr) + 0, 0xef);
    setDataByte(getOffset(testAddr) + 1, 0xbe);
    setDataByte(getOffset(testAddr) + 2, 0xad);
    setDataByte(getOffset(testAddr) + 3, 0xde);
    setReady(true);
    tick();

    setDataByte(getOffset(testAddr) + 0, 0);
    setDataByte(getOffset(testAddr) + 1, 0);
    setDataByte(getOffset(testAddr) + 2, 0);
    setDataByte(getOffset(testAddr) + 3, 0);
    setReady(false);

    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());
    tick();
    EXPECT_TRUE(
        inst_->cache_L1->__PVT__dirty_array[static_cast<uint8_t>(
                                                inst_->cache_L1->way_hit) >>
                                            1][getIndex(testAddr)]);
    // push 2nd write into same index
    uint64_t testAddr2 = addrDist(rng);
    while (getTag(testAddr2) == getTag(testAddr) ||
           getIndex(testAddr2) != getIndex(testAddr)) {
        testAddr2 = addrDist(rng);
    }
    inst_->addr = testAddr2;
    tick();
    EXPECT_TRUE(getLoad());
    EXPECT_FALSE(getStore());
    EXPECT_EQ(getMemAddr(), testAddr2 >> OFS_BITS);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    setReady(true);
    tick();
    setReady(false);

    // push 3rd write into same index, causing writeback
    uint64_t testAddr3 = addrDist(rng);
    while ((getTag(testAddr3) == getTag(testAddr) ||
            getTag(testAddr3) == getTag(testAddr2)) ||
           getIndex(testAddr3) != getIndex(testAddr)) {
        testAddr3 = addrDist(rng);
    }
    inst_->addr = testAddr3;
    tick();

    EXPECT_FALSE(getLoad());
    EXPECT_TRUE(getStore());
    EXPECT_EQ(getMemAddr(), testAddr >> OFS_BITS); // writeback addr
    EXPECT_EQ(getDataOutByte(getOffset(testAddr) + 0), static_cast<char>(0xef));
    EXPECT_EQ(getDataOutByte(getOffset(testAddr) + 1), static_cast<char>(0xbe));
    EXPECT_EQ(getDataOutByte(getOffset(testAddr) + 2), static_cast<char>(0xad));
    EXPECT_EQ(getDataOutByte(getOffset(testAddr) + 3), static_cast<char>(0xde));
    setReady(true);
    tick();

    setReady(false);
    EXPECT_FALSE(getLoad());
    EXPECT_FALSE(getStore());
    tick();
    EXPECT_TRUE(getLoad());
    EXPECT_FALSE(getStore());
    EXPECT_EQ(getMemAddr(), testAddr3 >> OFS_BITS);
}
