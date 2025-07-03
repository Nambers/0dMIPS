#include <SOC_debug.h>
#include <SOC_debug_SOC.h>
#include <SOC_debug_core.h>
#include <SOC_debug_core_MEM.h>
#include <SOC_debug_cp0.h>
#include <SOC_debug_data_mem__D800.h>
#include <SOC_debug_stdout.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include <fstream>
#include <iomanip>
#include <iostream>
#include <termios.h>
#include <unordered_map>

#include "SOC_utils.hpp"
#include "common.hpp"

// ./Core_sim [cycle_max]
int main(int argc, char **argv) {
    termios oldt, newt;
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);

    Verilated::commandArgs(argc, argv);
    unsigned int cycle_max = argc > 1 ? std::stoi(argv[1]) : 200;
    VerilatedContext *ctx = new VerilatedContext;
    SOC_debug *machine = new SOC_debug{ctx};
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
    //     std::cerr << "Failed to create VCD file!" << std::endl;
    //     return -1;
    // }

    machine->clk = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;
    std::cout << "Press any key to step." << std::endl;
    mainLoop(machine, ctx, cycle_max, cs_handle, disasm_cache, true);
    dumpMem(machine);

    // tfp->flush();
    // tfp->close();
    // delete tfp;
    machine->final();
    delete machine;
    ctx->gotFinish(1);
    delete ctx;
    Verilated::defaultContextp()->statsPrintSummary();
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    return 0;
}