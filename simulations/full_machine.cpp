#include <Full_machine.h>
#include <Full_machine_data_mem__D40.h>
#include <Full_machine_full_machine.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <fstream>
#include <iomanip>
#include <iostream>

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

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    VerilatedContext *ctx = new VerilatedContext;
    Full_machine *machine = new Full_machine{ctx};
    VerilatedVcdC *tfp = new VerilatedVcdC;
    ctx->debug(0);
    ctx->randReset(2);
    ctx->timeunit(-9);
    ctx->timeprecision(-12);

    Verilated::traceEverOn(true);
    machine->trace(tfp, 99);
    tfp->open("full_machine.vcd");
    if (!tfp->isOpen()) {
        std::cerr << "Failed to create VCD file!" << std::endl;
        return -1;
    }

    machine->clock = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;
    while (ctx->time() < 60 * 2) {
        std::cout << "time = \t" << ctx->time() << "\treset = \t"
                  << (bool)machine->reset << "\tpc = \t" << std::hex
                  << std::setfill('0') << std::setw(8)
                  << machine->full_machine->pc << "\tinst = \t"
                  << std::setfill('0') << std::setw(8)
                  << machine->full_machine->inst << std::dec << "\texcept = \t"
                  << (bool)machine->except << std::endl;
        TICK;
    }

    std::ofstream mem_out("memory_after.txt");
    for (int i = 0; i < MEM_WORD; i++) {
        mem_out << std::hex << std::setfill('0') << std::setw(16)
                << machine->full_machine->mem->data_seg[i] << std::endl;
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