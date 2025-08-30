#ifndef CORE_TEST_HPP
#define CORE_TEST_HPP

#include "common.hpp"
#include <Core.h>
#include <Core_core.h>
#include <Core_core_MEM.h>
#include <Core_core_branch.h>
#include <Core_cp0.h>

#include <array>

#define MASK5 0b11111
#define MASK6 0b111111
#define MASK16 0xffff
#define MASK32 0xffffffff
#define WORD_SIGN_MASK 0x80000000
#define WORD_HIGH_FULL 0xffffffff00000000
#define BYTE_HIGH_FULL 0xffffffffffffff00

#define MASKED(val, mask) ((val##mask) & (MASK##mask))

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

template <class C>
void write_mem_seg(C &data_seg, size_t addr, uint64_t value) {
    *reinterpret_cast<uint64_t *>(&data_seg[addr]) = value;
}
template <class C> uint64_t read_mem_seg(const C &data_seg, size_t addr) {
    return *reinterpret_cast<const uint64_t *>(&data_seg[addr]);
}

constexpr static auto common_boundary_cases = make_array<uint64_t>(
    0, 1, 0x7fffffffffffffff, 0x8000000000000000, 0xffffffffffffffff);

#define MEM_SEG inst_->core->MEM_stage->mem->data_seg
#define RF inst_->core->ID_stage->rf
#define FETCH_PC vlwide_get(inst_->core->IF_regs, 0, 64)

inline void reset_pc(Core *inst_, uint64_t pc) {
    inst_->core->branch_unit->next_fetch_pc = pc;
    pc = (pc == 0) ? 0 : pc - 4;

    // inst = NOP
    inst_->core->inst = 0;

    // fetch_pc4
    inst_->core->IF_regs.at(2) = (uint32_t)((pc + 4) & 0xffffffff); // low
    inst_->core->IF_regs.at(3) =
        (uint32_t)(((pc + 4) >> 32) & 0xffffffff); // high

    // fetch_pc
    inst_->core->IF_regs.at(0) = (uint32_t)((pc) & 0xffffffff);         // low
    inst_->core->IF_regs.at(1) = (uint32_t)(((pc) >> 32) & 0xffffffff); // high
}

#define SET_PC(pc) reset_pc(inst_, pc)
#define RESET_PC() reset_pc(inst_, 0)

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

#define TestGenMemCycle(name, init_test, check_result, cycle)                  \
    TEST_F(CoreTest, name) {                                                   \
        for (const uint64_t val : common_boundary_cases) {                         \
            reset();                                                           \
            init_test;                                                         \
            RESET_PC();                                                        \
            for (auto i = 0; i < cycle; ++i) {                                 \
                ASSERT_EQ(inst_->core->MEM_stage->cp0_->exc_code, 0);          \
                tick();                                                        \
            }                                                                  \
            check_result;                                                      \
        }                                                                      \
    }
#define TestGenMemOnceCycle(name, init_test, check_result, cycle)              \
    TEST_F(CoreTest, name) {                                                   \
        reset();                                                               \
        init_test;                                                             \
        RESET_PC();                                                            \
        for (auto i = 0; i < cycle; ++i) {                                     \
            tick();                                                            \
            ASSERT_EQ(inst_->core->MEM_stage->cp0_->exc_code, 0);              \
        }                                                                      \
        check_result;                                                          \
    }
#define TestGenMemOnceCycleNoCheck(name, init_test, check_result, cycle)       \
    TEST_F(CoreTest, name) {                                                   \
        reset();                                                               \
        init_test;                                                             \
        RESET_PC();                                                            \
        for (auto i = 0; i < cycle; ++i)                                       \
            tick();                                                            \
        check_result;                                                          \
    }

/*
    IF Stage
    ID Stage
    /EX Stage
    MEM Stage
*/
#define TestGenMem(name, init_test, check_result)                              \
    TestGenMemCycle(name, init_test, check_result, 3)
#define TestGenMemOnce(name, init_test, check_result)                          \
    TestGenMemOnceCycle(name, init_test, check_result, 3)

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
#endif // CORE_TEST_HPP