#ifndef SOC_UTILS_HPP
#define SOC_UTILS_HPP

#include "common.hpp"
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
        if (machine->SOC->stdout->stdout_taken) {
            uint64_t data = be64toh(machine->SOC->stdout->buffer);
            printf("stdout: %s \n", reinterpret_cast<char *>(&data));
        }
        std::cout << "time = " << ctx->time() << "\tpc = " << std::hex
                  << std::right << std::setfill('0') << std::setw(8)
                  << vlwide_get(machine->SOC->core->IF_regs, 32, 64) << std::dec
                  << std::left << "\t flags = ";
        std::string flags;
        if (machine->SOC->interrupt_sources)
            flags += "I|";
        if (machine->SOC->core->stall)
            flags += "S|";
        if (machine->SOC->core->IF_stage->inst_cache_miss_stall)
            flags += "IS|";
        if (machine->SOC->core->data_cache_miss_stall)
            flags += "DS|";
        if (machine->SOC->core->flush)
            flags += "F|";
        if (machine->SOC->reset)
            flags += "R|";
        if (machine->SOC->core->__PVT__d_valid)
            flags += "D|";
        if (machine->SOC->core->forward_A == 1)
            flags += "AA|";
        if (machine->SOC->core->forward_A == 2)
            flags += "AM|";
        if (machine->SOC->core->forward_B == 1)
            flags += "BA|";
        if (machine->SOC->core->forward_B == 2)
            flags += "BM|";
        switch (machine->SOC->core->MEM_stage->cp0_->exc_code) {
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
                  << get_disasm(vlwide_get(machine->SOC->core->IF_regs, 32, 64),
                                vlwide_get(machine->SOC->core->IF_regs, 0, 32),
                                disasm_cache, cs_handle);
        if (machine->SOC->d_valid) {
            std::cout << "\td_addr = " << std::hex << std::right
                      << std::setfill('0') << std::setw(8)
                      << machine->SOC->d_addr << " d_wdata = " << std::setw(8)
                      << machine->SOC->d_wdata << " d_rdata = " << std::setw(8)
                      << machine->SOC->d_rdata << std::dec << std::left;
        }
        if (machine->SOC->interrupt_sources) {
            std::cout << "\tinterrupt_sources = " << std::hex << std::right
                      << std::setfill('0') << std::setw(2)
                      << (int)machine->SOC->interrupt_sources << std::dec;
        }
        std::cout << std::endl;
        TICK;
        if (isDebug)
            getchar();
    }
}

template <class T> void dumpMem(T *machine) {
    std::ofstream mem_out("memory_after.txt");
    auto &mem = machine->SOC->data_mem->data_seg;
    for (size_t i = 0; i < mem.size() - 3; i += 4) {
        mem_out << std::hex << std::setfill('0') << std::setw(2) << (int)mem[i]
                << std::setw(2) << (int)mem[i + 1] << std::setw(2)
                << (int)mem[i + 2] << std::setw(2) << (int)mem[i + 3] << "\n";
    }
    mem_out.close();
}

#endif // SOC_UTILS_HPP