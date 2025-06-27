#ifndef SOC_UTILS_HPP
#define SOC_UTILS_HPP

#include "common.hpp"
#include <iomanip>
#include <iostream>
#include <unordered_map>

template <class T, class C>
void mainLoop(T *machine, C *ctx, unsigned int cycle_max, csh &cs_handle,
              std::unordered_map<uint64_t, DisasmEntry> &disasm_cache,
              bool isDebug = false) {
    std::cout << "Control: I - interrupt, F - flush, R - reset\n"
                 "Data:    S - stall, [A/B][A/M] - forward A/B from EX/MEM in "
                 "EX stage, D - peripheral data access\n"
              << "         IE - instruction exception, OE - operation exception"
              << std::endl;
    std::cout << "simulation starting" << std::endl;
    while (ctx->time() < cycle_max * 2) {
        if (machine->SOC->stdout->stdout_taken) {
            printf("stdout: %s \n",
                   (const char *)&machine->SOC->stdout->buffer);
        }
        std::cout << "time = " << ctx->time() << "\tpc = " << std::hex
                  << std::right << std::setfill('0') << std::setw(8)
                  << machine->SOC->core->pc << std::dec << std::left
                  << "\t flags = ";
        std::string flags;
        if (machine->SOC->interrupt_sources)
            flags += "I|";
        if (machine->SOC->core->stall)
            flags += "S|";
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
        switch (machine->SOC->core->MEM_stage->cp->exc_code) {
        case 0:
            break;
        case 0xc:
            flags += "IE|";
            break;
        case 0xa:
            flags += "OE|";
            break;
        }

        if (!flags.empty()) {
            flags.pop_back();
        }

        std::cout << std::left << std::setfill(' ') << std::setw(16) << flags;
        std::cout << "IF_inst = "
                  << get_disasm(machine->SOC->core->pc,
                                machine->SOC->core->inst, disasm_cache,
                                cs_handle);
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

#endif // SOC_UTILS_HPP