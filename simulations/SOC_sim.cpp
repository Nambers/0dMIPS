#include <SOC_sim.h>
#include <SOC_sim_SOC.h>
#include <SOC_sim_core.h>
#include <SOC_sim_core_IF.h>
#include <SOC_sim_core_MEM.h>
#include <SOC_sim_cp0.h>
#include <SOC_sim_data_mem.h>
#include <SOC_sim_stdout.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <unordered_map>

#include "SOC_utils.hpp"
#include "common.hpp"

// ./Core_sim [cycle_max]
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    unsigned int cycle_max = argc > 1 ? std::stoi(argv[1]) : 200;
    VerilatedContext *ctx = new VerilatedContext;
    SOC_sim *machine = new SOC_sim{ctx};
    // VerilatedVcdC*    tfp       = new VerilatedVcdC;
    ctx->debug(0);
    ctx->randReset(2);
    ctx->timeunit(-9);
    ctx->timeprecision(-12);

    std::unordered_map<uint64_t, DisasmEntry> disasm_cache;
    csh cs_handle;
    if (init_capstone(&cs_handle) != 0) {
        return -1;
    }

    Verilated::traceEverOn(true);
    // machine->trace(tfp, 99);
    // tfp->open("core.vcd");
    // if (!tfp->isOpen()) {
    // std::cerr << "Failed to create VCD file!" << std::endl;
    // return -1;
    // }

    machine->clk = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;
    mainLoop(machine, ctx, cycle_max, cs_handle, disasm_cache);
    dumpMem(machine);

    // tfp->flush();
    // tfp->close();
    // delete tfp;
    machine->final();
    delete machine;
    ctx->gotFinish(1);
    delete ctx;
    Verilated::defaultContextp()->statsPrintSummary();
    return 0;
}