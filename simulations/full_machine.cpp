#include <verilated.h>
#include <Full_machine.h>

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
        std::cout << "time = \t" << i << "\treset = \t" << machine->reset
                  << "\tpc = \t" << machine->PC_reg.Q << "\tinst = \t"
                  << machine->mem.inst << "\texcept = \t" << machine->except
                  << std::endl;
        TICK;
    }
    machine->final();
    delete machine;
    return 0;
}