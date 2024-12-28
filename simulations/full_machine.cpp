#include <Full_machine.h>
#include <Full_machine_full_machine.h>
#include <verilated.h>

#include <iomanip>
#include <iostream>

#define TICK                          \
    machine->clock = !machine->clock; \
    machine->eval();                  \
    machine->clock = !machine->clock; \
    machine->eval()

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Full_machine *machine = new Full_machine;
    machine->clock = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;
    for (int i = 0; i < 60; i++) {
        std::cout << "time = \t" << i << "\treset = \t" << (bool)machine->reset
                  << "\tpc = \t" << std::hex << std::setfill('0')
                  << std::setw(8) << machine->full_machine->pc << "\tinst = \t"
                  << std::setfill('0') << std::setw(8)
                  << machine->full_machine->inst << std::dec << "\texcept = \t"
                  << (bool)machine->except << std::endl;
        TICK;
    }
    machine->final();
    delete machine;
    return 0;
}