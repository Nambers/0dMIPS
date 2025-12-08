#include <SOC_run_sim.h>
#include <SOC_run_sim_SOC.h>
#include <SOC_run_sim_core.h>
#include <SOC_run_sim_core_MEM.h>
#include <SOC_run_sim_cp0.h>
#include <SOC_run_sim_stdout.h>
#include <verilated.h>

#include <endian.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <unordered_map>

#ifdef TRACE
#include <verilated_vcd_c.h>
#define TICK_TRACE                                                             \
    if (tfp) {                                                                 \
        tfp->dump(ctx->time());                                                \
    }
#else
#define TICK_TRACE
#endif

#define TICK_HALF                                                              \
    do {                                                                       \
        machine->clk = !machine->clk;                                          \
        machine->eval();                                                       \
        TICK_TRACE                                                             \
        ctx->timeInc(1);                                                       \
    } while (0)
#define TICK                                                                   \
    TICK_HALF;                                                                 \
    TICK_HALF;

int main(int argc, char **argv) {
    VerilatedContext *ctx = nullptr;
    // Verilated::commandArgs(argc, argv);
    ctx = new VerilatedContext;
    SOC_run_sim *machine = new SOC_run_sim{ctx};
#ifdef TRACE
    VerilatedVcdC *tfp = nullptr;
    tfp = new VerilatedVcdC;
    machine->trace(tfp, 99);
    ctx->traceEverOn(true);
    tfp->open("trace.vcd");
#endif

    machine->clk = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;

    while (1) {
        if (machine->SOC->stdout->stdout_taken) {
            uint64_t data = be64toh(machine->SOC->stdout->buffer);
            char buf[9];
            memmove(buf, &data, 8);
            std::cout << buf << std::flush;
            if (strcmp("HALT\n", buf) == 0) {
                break;
            }
        }
        TICK;
    }

#ifdef TRACE
    if (tfp) {
        tfp->close();
        delete tfp;
    }
#endif
    machine->final();
    delete machine;
    delete ctx;
    return 0;
}