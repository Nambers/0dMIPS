#ifndef SOC_UTILS_HPP
#define SOC_UTILS_HPP

// Shared by the soc_tb-based harnesses (SOC_sim, SOC_debug): everything is read
// from soc_tb's probe_* ports or the DPI inspectors in soc_inspect.hpp.
#include "common.hpp"
#include "soc_inspect.hpp"
#include <fstream>
#include <iomanip>
#include <iostream>
#include <unordered_map>

template <class T, class C>
void mainLoop(T *machine, C *ctx, unsigned int cycle_max, csh &cs_handle,
              std::unordered_map<uint64_t, DisasmEntry> &disasm_cache,
              bool isDebug = false) {
    std::cout << "Control: I - interrupt, F - flush, R - reset\n"
                 "Data:    [I/D]S - inst/data cache miss or normal stall, "
                 "[A/B][A/M] - forward A/B from EX/MEM in "
                 "EX stage, D - peripheral data access\n"
              << "         IE - instruction exception, SC - syscall, OE - "
                 "overflow exception"
              << std::endl;
    std::cout << "simulation starting" << std::endl;
    while (ctx->time() < cycle_max * 2) {
        if (machine->probe_stdout_taken) {
            uint64_t data = be64toh(machine->probe_stdout_buffer);
            printf("stdout: %s \n", reinterpret_cast<char *>(&data));
        }
        std::cout << "time = " << ctx->time() << "\tpc = " << std::hex
                  << std::right << std::setfill('0') << std::setw(8)
                  << machine->probe_ID_pc << std::dec << std::left
                  << "\t flags = ";
        std::string flags;
        if (machine->probe_interrupt_sources)
            flags += "I|";
        if (machine->probe_stall)
            flags += "S|";
        if (machine->probe_inst_cache_miss_stall)
            flags += "IS|";
        if (machine->probe_data_cache_miss_stall)
            flags += "DS|";
        if (machine->probe_flush)
            flags += "F|";
        if (machine->probe_reset)
            flags += "R|";
        if (machine->probe_d_valid)
            flags += "D|";
        if (machine->probe_forward_A == 1)
            flags += "AA|";
        if (machine->probe_forward_A == 2)
            flags += "AM|";
        if (machine->probe_forward_B == 1)
            flags += "BA|";
        if (machine->probe_forward_B == 2)
            flags += "BM|";
        switch (machine->probe_exc_code) {
        case 0:
            break;
        case 0xc:
            flags += "OE|";
            break;
        case 0xa:
            flags += "IE|";
            break;
        case 0x8:
            flags += "SC|";
            break;
        }

        if (!flags.empty()) {
            flags.pop_back();
        }

        std::cout << std::left << std::setfill(' ') << std::setw(16) << flags;
        std::cout << "ID_inst = "
                  << get_disasm(machine->probe_ID_pc, machine->probe_ID_inst,
                                disasm_cache, cs_handle);
        if (machine->probe_d_valid) {
            std::cout << "\td_addr = " << std::hex << std::right
                      << std::setfill('0') << std::setw(8)
                      << machine->probe_d_addr << " d_wdata = " << std::setw(8)
                      << machine->probe_d_wdata << " d_rdata = " << std::setw(8)
                      << machine->probe_d_rdata << std::dec << std::left;
        }
        if (machine->probe_interrupt_sources) {
            std::cout << "\tinterrupt_sources = " << std::hex << std::right
                      << std::setfill('0') << std::setw(2)
                      << (int)machine->probe_interrupt_sources << std::dec;
        }
        std::cout << std::endl;
        TICK;
        if (isDebug)
            getchar();
    }
}

// memory_after.txt: one line per 4 bytes, in address order
inline void dumpMem() {
    std::ofstream mem_out("memory_after.txt");
    const soc_inspect::MemView mem;
    for (uint64_t addr = 0; addr < mem.size_bytes(); addr += 4) {
        mem_out << std::hex << std::setfill('0');
        for (uint64_t b = 0; b < 4; ++b)
            mem_out << std::setw(2) << int(mem.byte(addr + b));
        mem_out << "\n";
    }
    mem_out.close();
}

#endif // SOC_UTILS_HPP
