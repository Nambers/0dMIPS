#ifndef CORE_TEST_HPP
#define CORE_TEST_HPP

#include "common.hpp"
#include <Core.h>
#include <Core_cache_L1.h>
#include <Core_core.h>
#include <Core_core_IF.h>
#include <Core_core_MEM.h>
#include <Core_core_branch.h>
#include <Core_cp0.h>

#include <array>

constexpr uint8_t OVERFLOW_EXC = 0x0c;
constexpr uint8_t RESERVED_INSTR_EXC = 0x0a;
constexpr uint8_t SYSCALL_EXC = 0x08;
constexpr uint8_t BREAK_EXC = 0x09;

template <class T, class... U>
constexpr std::array<T, sizeof...(U)> make_array(U &&...u) {
    return {static_cast<T>(u)...};
};

template <typename T> inline constexpr T fixedVal() {
    return static_cast<T>((0x0d00 << 16) | 0x0d00);
}
template <typename T> inline constexpr T fixedVal2() {
    return static_cast<T>((0xc100 << 16) | 0xc100);
}

// using DataType = VlUnpacked<VlUnpacked<VlWide<16> /*511:0*/, 64>, 2>;
// using ValidType = VlUnpacked<VlUnpacked<CData /*0:0*/, 64>, 2>;
// using DirtyType = VlUnpacked<VlUnpacked<CData /*0:0*/, 64>, 2>;
// using TagType = VlUnpacked<VlUnpacked<QData /*51:0*/, 64>, 2>;

inline uint64_t getAddrDWord(Core_cache_L1 *cache, uint64_t addr) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);
    const auto index = getIndex(addr);
    const auto way = 0; // for test simplicity
    // data_line is 64bytes
    auto &data_line = cache->data_array[way][index];
    uint64_t low = data_line[offset / sizeof(uint32_t)];
    uint64_t high = data_line[offset / sizeof(uint32_t) + 1];
    return (high << 32) | low;
}

inline void setAddrDWord(Core_cache_L1 *cache, uint64_t addr, uint64_t dword) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);
    const auto index = getIndex(addr);
    const auto fixedWay = 0; // for test simplicity
    // data_line is 64bytes
    auto &data_line = cache->data_array[fixedWay][index];
    data_line[offset / sizeof(uint32_t)] = dword & MASK32;
    data_line[offset / sizeof(uint32_t) + 1] = (dword >> 32) & MASK32;
    cache->valid_array[fixedWay][index] = 1;
    cache->tag_array[fixedWay][index] = getTag(addr);
    // printf("set to index=%x, tag=%x, ofs=%x\n", index, getTag(addr), offset);
}

inline void preloadCacheLine(Core_cache_L1 *cache, uint64_t start_addr,
                             uint64_t end_addr) {
    const auto fixedWay = 0; // for test simplicity
    for (auto i = getIndex(start_addr); i <= getIndex(end_addr) + 1; i++) {
        memset(&cache->data_array[fixedWay][i], 0, sizeof(VlWide<16>));
        cache->valid_array[fixedWay][i] = 1;
        cache->tag_array[fixedWay][i] = getTag(start_addr);
        // printf("preload index=%x, tag=%x\n", i, getTag(start_addr));
    }
}

template <typename Wide>
uint64_t vlwide_get(const Wide &wide, int idx /* low_bit */, int width) {
    int high_bit = idx + width - 1;
    int low_bit = idx;
    int low_word = low_bit / 32;
    int high_word = high_bit / 32;
    int offset = low_bit % 32;

    auto get32 = [&](int w) -> uint32_t {
        return static_cast<uint32_t>(wide.at(w));
    };

    if (high_word == low_word) {
        uint32_t word = get32(low_word);
        uint64_t mask = (width == 32 ? 0xFFFFFFFFull : ((1ull << width) - 1));
        return (word >> offset) & mask;
    }

    int low_width = 32 - offset;
    uint64_t low_part = get32(low_word) >> offset;
    uint64_t high_part = uint64_t(get32(high_word)) << low_width;

    uint64_t mask = (width == 64 ? ~0ull : ((1ull << width) - 1));
    return (high_part | low_part) & mask;
}

constexpr static auto common_boundary_cases = make_array<uint64_t>(
    0, 1, 0x7fffffffffffffff, 0x8000000000000000, 0xffffffffffffffff);

#define DCACHE inst_->core->MEM_stage->data_cache
#define ICACHE inst_->core->IF_stage->inst_cache
#define RF inst_->core->ID_stage->rf
// #define FETCH_PC vlwide_get(inst_->core->IF_regs, 0, 64)
#define FETCH_PC inst_->core->IF_stage->first_half_pc

inline void set_pc(Core *inst_, uint64_t pc) {
    pc = (pc == 0) ? 0 : pc - 4;

    inst_->core->branch_unit->next_fetch_pc = pc;
    inst_->core->IF_stage->first_half_pc4 = pc;
    inst_->core->IF_stage->first_half_pc = pc;
}

#define SET_PC(pc) set_pc(inst_, pc)
#define RESET_PC() set_pc(inst_, 0)

inline VlWide<5> buildMemRegs(int addr, uint64_t data) {
    VlWide<5> regs{};
    auto part1 = 5 + 1 + 1;
    uint64_t data1 = data & ((1 << (32 - part1)) - 1);
    uint64_t data2 = data >> (32 - part1);

    regs[4] = 0; // EPC
    regs[3] = 0;
    regs[2] = (data2 >> 32) & MASK32; // W_data
    regs[1] = data2 & MASK32;

    regs[0] = 0b10 | ((addr & 0x1f) << 2) | (data1 << part1);

    return regs;
}

#define WRITE_RF(addr, data)                                                   \
    inst_->core->MEM_regs = buildMemRegs(addr, data);                          \
    tick()

#define CASES_HEAD for (const uint64_t val : common_boundary_cases) {
#define CASES_TAIL }

#define TestGenMemInternal(name, init_test, check_result, cycle, ele1, ele2,   \
                           ele3)                                               \
    TEST_F(CoreTest, name) {                                                   \
        ele1 reset();                                                          \
        preloadCacheLine(ICACHE, 0, 0xff);                                     \
        preloadCacheLine(DCACHE, 0, 0xff);                                     \
        init_test;                                                             \
        tick();                                                                \
        RESET_PC();                                                            \
        for (auto i = 0; i < cycle; ++i) {                                     \
            tick();                                                            \
            ele3;                                                              \
        }                                                                      \
        check_result;                                                          \
        ele2                                                                   \
    }

#define TestGenMemCycle(name, init_test, check_result, cycle)                  \
    TestGenMemInternal(name, init_test, check_result, cycle, CASES_HEAD,       \
                       CASES_TAIL,                                             \
                       ASSERT_EQ(inst_->core->MEM_stage->cp0_->exc_code, 0))
#define TestGenMemOnceCycle(name, init_test, check_result, cycle)              \
    TestGenMemInternal(name, init_test, check_result, cycle, , ,               \
                       ASSERT_EQ(inst_->core->MEM_stage->cp0_->exc_code, 0))

#define TestGenMemCycleNoCheck(name, exc, init_test, check_result, cycle)      \
    TestGenMemInternal(                                                        \
        name, init_test, check_result, cycle, CASES_HEAD, CASES_TAIL,          \
        ASSERT_TRUE(inst_->core->MEM_stage->cp0_->exc_code == exc ||           \
                    inst_->core->MEM_stage->cp0_->exc_code == 0))
#define TestGenMemOnceCycleNoCheck(name, exc, init_test, check_result, cycle)  \
    TestGenMemInternal(                                                        \
        name, init_test, check_result, cycle, , ,                              \
        ASSERT_TRUE(inst_->core->MEM_stage->cp0_->exc_code == exc ||           \
                    inst_->core->MEM_stage->cp0_->exc_code == 0))

/*
    IF Stage
    IF2 Stage
    ID Stage
    EX Stage
    MEM Stage
    MEM2 Stage
    WB Stage
*/
#define TestGenMem(name, init_test, check_result)                              \
    TestGenMemCycle(name, init_test, check_result, 6)
#define TestGenMemOnce(name, init_test, check_result)                          \
    TestGenMemOnceCycle(name, init_test, check_result, 6)
#define TestGenMemNoCheck(name, exc, init_test, check_result)                  \
    TestGenMemCycleNoCheck(name, exc, init_test, check_result, 6)
#define TestGenMemOnceNoCheck(name, exc, init_test, check_result)              \
    TestGenMemOnceCycleNoCheck(name, exc, init_test, check_result, 6)

class CoreTest : public TestBase<Core> {
  protected:
    void SetUp() override {
        this->inst_ = new Core{&this->ctx};
        this->inst_->clock = 1;
        this->inst_->reset = 1;
        tick();
        this->inst_->reset = 0;
    }
};

inline uint32_t build_R_inst(uint8_t opcode6, uint8_t rs5, uint8_t rt5,
                             uint8_t rd5, uint8_t shift5, uint8_t funct6) {
    return (MASKED(opcode, 6) << 26) | (MASKED(rs, 5) << 21) |
           (MASKED(rt, 5) << 16) | (MASKED(rd, 5) << 11) |
           (MASKED(shift, 5) << 6) | MASKED(funct, 6);
}

inline uint32_t build_I_inst(uint8_t opcode6, uint8_t rs5, uint8_t rt5,
                             int16_t imm16) {
    return (MASKED(opcode, 6) << 26) | (MASKED(rs, 5) << 21) |
           (MASKED(rt, 5) << 16) | (imm16 & MASK16);
}
inline uint32_t build_J_inst(uint8_t opcode6, uint32_t addr26) {
    return (MASKED(opcode, 6) << 26) | (addr26 & 0x03ffffff);
}
inline uint32_t build_REGIMM_inst(uint8_t opcode, uint8_t rt, uint8_t rs,
                                  int16_t offset) {
    return (static_cast<uint32_t>(opcode) << 26) |
           (static_cast<uint32_t>(rs) << 21) |
           (static_cast<uint32_t>(rt) << 16) | (static_cast<uint16_t>(offset));
}
inline uint32_t build_CP0_inst(uint8_t MT5, uint8_t rt5, uint8_t rd5,
                               uint8_t sel3) {
    return (static_cast<uint32_t>(0b010000) << 26) |
           (static_cast<uint32_t>(MT5) << 21) |
           (static_cast<uint32_t>(rt5) << 16) |
           (static_cast<uint32_t>(rd5) << 11) | (sel3 & 0b111);
}
inline uint32_t build_cache_inst(uint8_t base5, uint8_t op3, uint8_t target2,
                                 uint16_t offset9) {
    return (static_cast<uint32_t>(0b011111) << 26) |
           ((static_cast<uint32_t>(base5) & 0b11111) << 21) |
           ((static_cast<uint32_t>(op3) & 0b111) << 18) |
           ((static_cast<uint32_t>(target2) & 0b11) << 16) |
           ((static_cast<uint32_t>(offset9) & 0x1ff) << 7) | 0b100101;
}
#endif // CORE_TEST_HPP