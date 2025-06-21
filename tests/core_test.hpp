#ifndef CORE_TEST_HPP
#define CORE_TEST_HPP

#include "common.hpp"
#include <Core.h>
#include <Core_core.h>

#include <array>

#define MASK5 0b11111
#define MASK6 0b111111
#define MASK16 0xffff
#define MASK32 0xffffffff
#define WORD_SIGN_MASK 0x80000000
#define WORD_HIGH_FULL 0xffffffff00000000
#define BYTE_HIGH_FULL 0xffffffffffffff00

#define MASKED(val, mask) ((val##mask) & (MASK##mask))
#define u64(a, b) ((uint64_t(a) << 32) | uint64_t(b))

template <class T, class... U>
constexpr std::array<T, sizeof...(U)> make_array(U &&...u) {
    return {static_cast<T>(u)...};
};

constexpr static auto common_boundary_cases = make_array<uint64_t>(
    0, 1, 0x7fffffffffffffff, 0x8000000000000000, 0xffffffffffffffff);

#define MEM_SEG inst_->core->MEM_stage->mem->data_seg
#define RF inst_->core->ID_stage->rf

inline void reset_pc(Core *inst_, uint64_t pc) {
    inst_->core->pc = pc;
    inst_->core->__PVT__next_pc = pc + 4;
    inst_->core->__PVT__IF_regs[0] = 0;
    inst_->core->__PVT__IF_regs[2] = (uint32_t)((pc + 4) & 0xffffffff);
    inst_->core->__PVT__IF_regs[1] = (uint32_t)(((pc + 4) >> 32) & 0xffffffff);
    inst_->core->__PVT__IF_regs[4] = (uint32_t)((pc) & 0xffffffff);
    inst_->core->__PVT__IF_regs[3] = (uint32_t)(((pc) >> 32) & 0xffffffff);
}

#define SET_PC(pc) reset_pc(inst_, pc)
#define RESET_PC() reset_pc(inst_, 0)

#define WRITE_RF(addr, data)                                                   \
    RF->W_data = data;                                                         \
    RF->wr_enable = 1;                                                         \
    RF->W_addr = addr;                                                         \
    tick();                                                                    \
    RF->wr_enable = 0

class CoreTest : public TestBase<Core> {
  protected:
    void SetUp() override {
        std::system("mkdir -p test_tmp >> /dev/null");
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

#endif // CORE_TEST_HPP