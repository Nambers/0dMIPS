#ifndef SIMULATIONS_COMMON_HPP
#define SIMULATIONS_COMMON_HPP

#include <cstdint>
#include <string>
#include <unordered_map>
#include <capstone/capstone.h>

#define TICK_HALF                                                                                  \
    do {                                                                                           \
        machine->clk = !machine->clk;                                                              \
        machine->eval();                                                                           \
        ctx->timeInc(1);                                                                           \
    } while (0)
#define TICK                                                                                       \
    TICK_HALF;                                                                                     \
    TICK_HALF

template <typename Wide> uint64_t vlwide_get(const Wide& wide, int idx /* low_bit */, int width) {
    int high_bit  = idx + width - 1;
    int low_bit   = idx;
    int low_word  = low_bit / 32;
    int high_word = high_bit / 32;
    int offset    = low_bit % 32;

    auto get32 = [&](int w) -> uint32_t { return static_cast<uint32_t>(wide.at(w)); };

    if (high_word == low_word) {
        uint32_t word = get32(low_word);
        uint64_t mask = (width == 32 ? 0xFFFFFFFFull : ((1ull << width) - 1));
        return (word >> offset) & mask;
    }

    int      low_width = 32 - offset;
    uint64_t low_part  = get32(low_word) >> offset;
    uint64_t high_part = uint64_t(get32(high_word)) << low_width;

    uint64_t mask = (width == 64 ? ~0ull : ((1ull << width) - 1));
    return (high_part | low_part) & mask;
}

struct DisasmEntry {
    uint32_t    inst;
    std::string text;
};

int init_capstone(csh* cs_handle);

std::string fallback_disasm(uint64_t pc, uint32_t inst, const csh& cs_handle);

std::string get_disasm(uint64_t pc, uint32_t inst,
                       std::unordered_map<uint64_t, DisasmEntry> disasm_cache,
                       const csh&                                cs_handle);

#endif