#include <Core_sim.h>
#include <Core_sim_core.h>
#include <Core_sim_core_MEM.h>
#include <Core_sim_cp0.h>
#include <Core_sim_data_mem__D40.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <fstream>
#include <iomanip>
#include <iostream>
#include <unordered_map>

#define TICK_HALF                         \
    do {                                  \
        machine->clock = !machine->clock; \
        machine->eval();                  \
        tfp->dump(ctx->time());           \
        ctx->timeInc(1);                  \
    } while (0)
#define TICK   \
    TICK_HALF; \
    TICK_HALF

std::unordered_map<uint32_t, std::string> parseInst(FILE *f) {
    std::unordered_map<uint32_t, std::string> insts;
    char buffer[256];

    while (fgets(buffer, sizeof(buffer), f)) {
        if (buffer[0] == ' ' && buffer[1] == ' ') {
            uint64_t addr;
            uint32_t inst;
            char format[128];

            if (sscanf(buffer, " %lx: %8x %[^\n]", &addr, &inst, format) == 3) {
                insts[inst] = "";
                for (char c : std::string(format)) {
                    insts[inst] += (c == '\t') ? ' ' : c;
                }
            }
        }
    }
    return insts;
}

// ./Core_sim [cycle_max]
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    unsigned int cycle_max = argc > 1 ? std::stoi(argv[1]) : 200;
    VerilatedContext *ctx = new VerilatedContext;
    Core_sim *machine = new Core_sim{ctx};
    VerilatedVcdC *tfp = new VerilatedVcdC;
    ctx->debug(0);
    ctx->randReset(2);
    ctx->timeunit(-9);
    ctx->timeprecision(-12);

    FILE *text_seg = fopen("memory_dump.text.dat", "r");
    if (!text_seg) {
        std::cerr << "Failed to open memory_dump.text.dat!" << std::endl;
        return -1;
    }
    auto inst_map = parseInst(text_seg);
    fclose(text_seg);

    Verilated::traceEverOn(true);
    machine->trace(tfp, 99);
    tfp->open("core.vcd");
    if (!tfp->isOpen()) {
        std::cerr << "Failed to create VCD file!" << std::endl;
        return -1;
    }

    machine->clock = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;
    std::cout << "flags: I - interrupt, S - stall, F - flush, A - forward A, B "
                 "-forward B, R - reset, D - "
                 "ask peripheral data access\n"
              << "IE - instruction exception, OE - operation exception"
              << std::endl;
    std::cout << "simulation starting" << std::endl;
    while (ctx->time() < cycle_max * 2) {
        std::cout << "time = " << ctx->time() << "\tpc = " << std::hex
                  << std::right << std::setfill('0') << std::setw(8)
                  << machine->core->pc << std::dec << std::left
                  << "\t flags = ";
        std::string flags;
        if (machine->core->MEM_stage->takenHandler) flags += "I|";
        if (machine->core->stall) flags += "S|";
        if (machine->core->flush) flags += "F|";
        if (machine->core->reset) flags += "R|";
        if (machine->core->d_valid) flags += "D|";
        if (machine->core->forward_A == 1) flags += "AA|";
        if (machine->core->forward_A == 2) flags += "AM|";
        if (machine->core->forward_B == 1) flags += "BA|";
        if (machine->core->forward_B == 2) flags += "BM|";
        switch (machine->core->MEM_stage->cp->exc_code) {
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

        std::cout << std::left << std::setfill(' ') << std::setw(15) << flags;
        std::cout << "IF_inst = " << inst_map[machine->core->inst];
        if (machine->core->d_valid) {
            std::cout << "\td_addr = " << std::hex << std::right
                      << std::setfill('0') << std::setw(8)
                      << machine->core->d_addr << std::dec << std::left;
        }
        std::cout << std::endl;
        TICK;
    }

    std::ofstream mem_out("memory_after.txt");
    for (int i = 0; i < machine->core->MEM_stage->mem->data_seg.size(); i++) {
        mem_out << std::hex << std::setfill('0') << std::setw(16)
                << machine->core->MEM_stage->mem->data_seg[i] << std::endl;
    }
    mem_out.close();

    tfp->flush();
    tfp->close();
    delete tfp;
    machine->final();
    delete machine;
    ctx->gotFinish(1);
    delete ctx;
    return 0;
}