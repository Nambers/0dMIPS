#include <SOC_run_sim.h>
#include <SOC_run_sim_SOC.h>
#include <SOC_run_sim_core.h>
#include <SOC_run_sim_core_MEM.h>
#include <SOC_run_sim_cp0.h>
#include <SOC_run_sim_data_mem__D100.h>
#include <SOC_run_sim_stdout.h>
#include <verilated.h>

#include <endian.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <unordered_map>

#define TICK_HALF                                                              \
    do {                                                                       \
        machine->clk = !machine->clk;                                          \
        machine->eval();                                                       \
    } while (0)
#define TICK                                                                   \
    TICK_HALF;                                                                 \
    TICK_HALF

int main(int argc, char **argv) {
    // Verilated::commandArgs(argc, argv);
    SOC_run_sim *machine = new SOC_run_sim;

    machine->clk = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;

    while (1) {
        if (machine->SOC->stdout->stdout_taken) {
            uint64_t data = be64toh(machine->SOC->stdout->buffer);
            std::cout << reinterpret_cast<char *>(&data) << std::flush;
            if (strcmp("HALT\n", reinterpret_cast<char *>(&data)) == 0) {
                break;
            }
        }
        TICK;
    }

    machine->final();
    delete machine;
    return 0;
}