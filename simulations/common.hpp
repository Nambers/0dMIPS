#ifndef SIMULATIONS_COMMON_HPP
#define SIMULATIONS_COMMON_HPP

#include <capstone/capstone.h>
#include <cstdint>
#include <string>
#include <unordered_map>

#define TICK_HALF                                                              \
    do {                                                                       \
        machine->sys_clk = !machine->sys_clk;                                  \
        machine->eval();                                                       \
        ctx->timeInc(1);                                                       \
    } while (0)
#define TICK                                                                   \
    TICK_HALF;                                                                 \
    TICK_HALF

struct DisasmEntry {
    uint32_t inst;
    std::string text;
};

int init_capstone(csh *cs_handle);

std::string fallback_disasm(uint64_t pc, uint32_t inst, const csh &cs_handle);

std::string get_disasm(uint64_t pc, uint32_t inst,
                       std::unordered_map<uint64_t, DisasmEntry> disasm_cache,
                       const csh &cs_handle);

#endif