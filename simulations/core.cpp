#include <Core.h>
#include <Core_core.h>
#include <Core_core_MEM.h>
#include <Core_data_mem__D40.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <fstream>
#include <iomanip>
#include <iostream>
#include <unordered_map>

#define MEM_WORD 1000

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

std::unordered_map<uint64_t, std::string> parseInst(FILE *f) {
    std::unordered_map<uint64_t, std::string> insts;
    char buffer[256];

    while (fgets(buffer, sizeof(buffer), f)) {
        if (buffer[0] == ' ' && buffer[1] == ' ') {
            uint64_t addr;
            char inst[9], format[128];

            if (sscanf(buffer, " %lx: %8s %[^\n]", &addr, inst, format) == 3) {
                insts[addr] = "";
                for (char c : std::string(format)) {
                    insts[addr] += (c == '\t') ? ' ' : c;
                }
            }
        }
    }
    return insts;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    VerilatedContext *ctx = new VerilatedContext;
    Core *machine = new Core{ctx};
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
                 "ask peripheral data access"
              << std::endl;
    std::cout << "simulation starting" << std::endl;
    while (ctx->time() < 60 * 2) {
        std::cout << "time = " << ctx->time() << "\tpc = " << std::hex
                  << std::setfill('0') << std::setw(8) << std::dec
                  << machine->core->pc << "\t flags = ";
        std::string flags;
        if (machine->core->MEM_stage->takenInterrupt) flags += "I|";
        if (machine->core->stall) flags += "S|";
        if (machine->core->flush) flags += "F|";
        if (machine->core->reset) flags += "R|";
        if (machine->core->d_valid) flags += "D|";
        if (machine->core->forward_A) flags += "A|";
        if (machine->core->forward_B) flags += "B|";

        if (!flags.empty()) {
            flags.pop_back();
        }

        std::cout << std::left << std::setfill(' ') << std::setw(13) << flags;
        std::cout << "inst = " << inst_map[machine->core->pc] << std::endl;
        TICK;
    }

    std::ofstream mem_out("memory_after.txt");
    for (int i = 0; i < MEM_WORD; i++) {
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