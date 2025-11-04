#include <Cache_L1.h>
#include <Cache_L1_cache_L1.h>

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

class Cache_L1Test : public TestBase<Cache_L1> {
  public:
    std::uniform_int_distribution<uint64_t> addrDist{0, UINT64_MAX};
};

TEST_F(Cache_L1Test, readTest) {
    const uint64_t testAddr = addrDist(rng) & ~0x3F; // align to 64B
    char buff[64] = {0};
    buff[getOffset(testAddr) + 0] = 0xef;
    buff[getOffset(testAddr) + 1] = 0xbe;
    buff[getOffset(testAddr) + 2] = 0xad;
    buff[getOffset(testAddr) + 3] = 0xde;
    inst_->addr = testAddr;
    inst_->mem_load_type = 3; // LW
    tick();
    EXPECT_TRUE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    EXPECT_EQ(inst_->mem_addr, testAddr & ~OFS_MASK);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    inst_->mem_data.m_storage[0] = 0x100;
    memcpy(inst_->mem_data.m_storage, buff, 64);
    inst_->mem_ready = 1;
    tick();
    memset(inst_->mem_data.m_storage, 0, 64);
    inst_->mem_ready = 0;
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0xdeadbeef, 32));
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    tick();
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0xdeadbeef, 32));
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);

    // test new read
    uint64_t testAddr2 = addrDist(rng) & ~0x3F;
    while (getTag(testAddr2) == getTag(testAddr) &&
           getIndex(testAddr2) == getIndex(testAddr)) {
        testAddr2 = addrDist(rng);
    }
    inst_->addr = testAddr2;
    tick();
    EXPECT_TRUE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    memset(buff, 0, 64);
    buff[getOffset(testAddr2) + 0] = 0x78;
    buff[getOffset(testAddr2) + 1] = 0x56;
    buff[getOffset(testAddr2) + 2] = 0x34;
    buff[getOffset(testAddr2) + 3] = 0x12;
    memcpy(inst_->mem_data.m_storage, buff, 64);
    inst_->mem_ready = 1;
    tick();
    memset(inst_->mem_data.m_storage, 0, 64);
    inst_->mem_ready = 0;
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0x12345678, 32));
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    tick();
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0x12345678, 32));
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);

    // test read back to first address
    inst_->addr = testAddr;
    tick();
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_EQ(inst_->rdata, sign_extend(0xdeadbeef, 32));
}

TEST_F(Cache_L1Test, writeTest) {
    char buff[64] = {0};
    const uint64_t testAddr = addrDist(rng);
    inst_->addr = testAddr;
    inst_->wdata = 0xdeadbeef;
    inst_->mem_store_type = 3; // SW
    tick();
    EXPECT_TRUE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    EXPECT_EQ(inst_->mem_addr, testAddr & ~OFS_MASK);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    buff[getOffset(testAddr) + 0] = 0xef;
    buff[getOffset(testAddr) + 1] = 0xbe;
    buff[getOffset(testAddr) + 2] = 0xad;
    buff[getOffset(testAddr) + 3] = 0xde;

    memcpy(inst_->mem_data.m_storage, buff, 64);
    inst_->mem_ready = 1;
    tick();
    memset(inst_->mem_data.m_storage, 0, 64);
    inst_->mem_ready = 0;
    EXPECT_GT(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
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
    EXPECT_TRUE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    EXPECT_EQ(inst_->mem_addr, testAddr2 & ~OFS_MASK);
    EXPECT_EQ(static_cast<uint8_t>(inst_->cache_L1->way_hit), 0);

    memcpy(inst_->mem_data.m_storage, buff, 64);
    inst_->mem_ready = 1;
    tick();
    inst_->mem_ready = 0;

    // push 3rd write into same index, causing writeback
    uint64_t testAddr3 = addrDist(rng);
    while ((getTag(testAddr3) == getTag(testAddr) ||
            getTag(testAddr3) == getTag(testAddr2)) ||
           getIndex(testAddr3) != getIndex(testAddr)) {
        testAddr3 = addrDist(rng);
    }
    inst_->addr = testAddr3;
    tick();
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_TRUE(inst_->mem_req_store);
    EXPECT_EQ(inst_->mem_addr, testAddr & ~OFS_MASK); // writeback addr
    memcpy(inst_->mem_data_out.m_storage, buff, 64);
    EXPECT_EQ(buff[getOffset(testAddr) + 0], static_cast<char>(0xef));
    EXPECT_EQ(buff[getOffset(testAddr) + 1], static_cast<char>(0xbe));
    EXPECT_EQ(buff[getOffset(testAddr) + 2], static_cast<char>(0xad));
    EXPECT_EQ(buff[getOffset(testAddr) + 3], static_cast<char>(0xde));
    inst_->mem_ready = 1;
    tick();
    inst_->mem_ready = 0;
    EXPECT_FALSE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    tick();
    EXPECT_TRUE(inst_->mem_req_load);
    EXPECT_FALSE(inst_->mem_req_store);
    EXPECT_EQ(inst_->mem_addr, testAddr3 & ~OFS_MASK);
}
