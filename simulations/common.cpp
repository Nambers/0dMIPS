#include "common.hpp"

#include <sstream>
#include <iomanip>
#include <iostream>

std::string fallback_disasm(uint64_t pc, uint32_t inst, const csh& cs_handle) {
    uint8_t opcode = (inst >> 26) & 0x3F;
    if (opcode == 0x37) { // 0b110111 = 0x37 = ld
        uint8_t base = (inst >> 21) & 0x1F;
        uint8_t rt   = (inst >> 16) & 0x1F;
        int16_t imm  = inst & 0xFFFF;

        std::ostringstream oss;
        oss << "ld " << "r" << (int)rt << ", " << imm << "(r" << (int)base << ")";
        return oss.str();
    }

    cs_err             err = cs_errno(cs_handle);
    std::ostringstream oss;
    oss << "invalid: " << cs_strerror(err) << " [";
    oss << std::hex << std::setw(8) << std::setfill('0') << inst;
    oss << "]";
    return oss.str();
}

std::string get_disasm(uint64_t pc, uint32_t inst,
                       std::unordered_map<uint64_t, DisasmEntry> disasm_cache,
                       const csh&                                cs_handle) {
    if (inst == 0) return "nop";

    auto it = disasm_cache.find(pc);
    if (it != disasm_cache.end() && it->second.inst == inst) {
        return it->second.text;
    }

    cs_insn*    insn;
    size_t      count = cs_disasm(cs_handle, (uint8_t*)&inst, 4, pc, 1, &insn);
    std::string result;

    if (count > 0) {
        result = std::string(insn[0].mnemonic) + " " + insn[0].op_str;
        cs_free(insn, count);
    } else
        result = fallback_disasm(pc, inst, cs_handle);

    disasm_cache[pc] = DisasmEntry{inst, result};
    return result;
}

int init_capstone(csh* cs_handle) {
    if (cs_open(CS_ARCH_MIPS,
                static_cast<cs_mode>(CS_MODE_MIPS64 | CS_MODE_MIPS32R6 | CS_MODE_LITTLE_ENDIAN),
                cs_handle) != CS_ERR_OK) {
        std::cerr << "Failed to open Capstone" << std::endl;
        return 1;
    }
    return 0;
}

// // first is addr, second is instruction format string
// std::unordered_map<uint32_t, std::string> parseInst(FILE* f) {
//     std::unordered_map<uint32_t, std::string> insts;
//     char                                      buffer[256];

//     while (fgets(buffer, sizeof(buffer), f)) {
//         uint32_t addr;
//         uint32_t inst;
//         char     mnemonic[128];

//         if (sscanf(buffer, " %x: %x %[^\n]", &addr, &inst, mnemonic) == 3) {
//             std::string fmtStr(mnemonic);
//             for (char& c : fmtStr) {
//                 if (c == '\t') c = ' ';
//             }
//             insts[addr] = fmtStr;
//         }
//     }

//     return insts;
// }
