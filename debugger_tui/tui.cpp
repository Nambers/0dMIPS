#include <ftxui/component/component.hpp>
#include <ftxui/component/screen_interactive.hpp>
#include <ftxui/dom/elements.hpp>
#include <ftxui/dom/node.hpp>

#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>
#include <array>

#include <SOC_sim.h>
#include <SOC_sim_core.h>
#include <SOC_sim_SOC.h>
#include <SOC_sim_stdout.h>
#include <SOC_sim_core_MEM.h>
#include <SOC_sim_data_mem__D40.h>
#include <SOC_sim_cp0.h>
#include <SOC_sim_core_ID.h>
#include <SOC_sim_regfile__W40.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#define TICK_HALF                                                                                  \
    do {                                                                                           \
        machine->clk = !machine->clk;                                                              \
        machine->eval();                                                                           \
        ctx->timeInc(1);                                                                           \
    } while (0)
#define TICK                                                                                       \
    TICK_HALF;                                                                                     \
    TICK_HALF

using namespace ftxui;

uint64_t mem_center    = 0x0;
uint64_t last_mem_read = 0, last_mem_write = 0;

std::map<std::string, std::string> pipeline;

std::array<uint64_t, 32> RF;

std::map<std::string, bool>               flags;
std::unordered_map<uint32_t, std::string> inst_map;

SOC_sim*          machine = nullptr;
VerilatedContext* ctx     = nullptr;

std::string reg_name(int i) {
    static const char* names[] = {"r0", "at", "v0", "v1", "a0", "a1", "a2", "a3", "t0", "t1", "t2",
                                  "t3", "t4", "t5", "t6", "t7", "s0", "s1", "s2", "s3", "s4", "s5",
                                  "s6", "s7", "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"};
    if (i >= 0 && i < 32) return names[i];
    return "reg";
}

template <typename Wide> uint64_t vlwide_get(const Wide& wide, int idx /* low_bit */, int width) {
    int high_bit  = idx + width - 1;
    int low_bit   = idx;
    int low_word  = low_bit / 32;
    int high_word = high_bit / 32;
    int offset    = low_bit % 32;

    auto get32 = [&](int w) -> uint32_t { return static_cast<uint32_t>(wide.at(w)); };

    if (high_word == low_word) {
        uint32_t word = get32(low_word);
        uint64_t mask = (width == 32 ? 0xFFFFFFFFull : ((1ull << width) - 1));
        return (word >> offset) & mask;
    }

    int      low_width = 32 - offset;
    uint64_t low_part  = get32(low_word) >> offset;
    uint64_t high_part = uint64_t(get32(high_word)) << low_width;

    uint64_t mask = (width == 64 ? ~0ull : ((1ull << width) - 1));
    return (high_part | low_part) & mask;
}

std::string fmt_inst(uint64_t pc) {
    auto it = inst_map.find((uint32_t)pc);
    if (it != inst_map.end()) return it->second;
    return "nop";
}

void update_state_from_sim() {
    TICK;
    pipeline["IF"]  = fmt_inst(machine->SOC->core->pc);
    pipeline["ID"]  = fmt_inst(vlwide_get(machine->SOC->core->IF_regs, 0, 64));
    pipeline["EX"]  = fmt_inst(vlwide_get(machine->SOC->core->ID_regs, 0, 64));
    pipeline["MEM"] = fmt_inst(vlwide_get(machine->SOC->core->EX_regs, 0, 64));
    pipeline["WB"]  = fmt_inst(vlwide_get(machine->SOC->core->MEM_regs, 0, 64));

    auto& R = machine->SOC->core->ID_stage->rf->__PVT__reg_out; // VlWide<64>，2048 bits

    // reg0 = bits [63:0]，reg1 = bits [127:64], ..., reg31 = bits [2047:1984]
    for (int i = 0; i < 32; ++i) {
        // idx = i*64； width = 64
        RF[i] = vlwide_get(R, i * 64, 64);
    }

    // // TODO
    // last_mem_read  = 0x2000;
    // last_mem_write = 0x2004;

    flags.clear();
    flags["I"]  = machine->SOC->interrupt_sources;
    flags["S"]  = machine->SOC->core->stall;
    flags["F"]  = machine->SOC->core->flush;
    flags["R"]  = machine->SOC->reset;
    flags["D"]  = machine->SOC->core->__PVT__d_valid;
    flags["AA"] = (machine->SOC->core->forward_A == 1);
    flags["AM"] = (machine->SOC->core->forward_A == 2);
    flags["BA"] = (machine->SOC->core->forward_B == 1);
    flags["BM"] = (machine->SOC->core->forward_B == 2);
    flags["DR"] = machine->SOC->__PVT__d_ready;
    switch (machine->SOC->core->MEM_stage->cp->exc_code) {
    case 0:
        break;
    case 0xc:
        flags["IE"] = true;
        break;
    case 0xa:
        flags["OE"] = true;
        break;
    }
}

Element render_pipeline() {
    std::vector<Element> lines;
    lines.push_back(text("🚀 Pipeline") | bold);
    for (const auto& stage : std::array<std::string, 5>{"IF", "ID", "EX", "MEM", "WB"}) {
        std::string inst_str = pipeline.count(stage) ? pipeline[stage] : "N/A";
        lines.push_back(hbox({text(stage + ": ") | bold, text(inst_str)}));
    }

    std::vector<std::pair<std::string, bool>> persistent = {
        {"Interrupt", flags["I"]}, {"Stall", flags["S"]},        {"Flush", flags["F"]},
        {"Reset", flags["R"]},     {"PeriphAccess", flags["D"]}, {"fA-EX", flags["AA"]},
        {"fA-MEM", flags["AM"]},   {"fB-EX", flags["BA"]},       {"fB-MEM", flags["BM"]},
    };
    std::vector<std::pair<std::string, bool>> transients = {
        {"InstExc", flags["IE"]}, {"OpExc", flags["OE"]}, {"PeriphReady", flags["DR"]}};

    std::vector<Element> flag_elems;
    auto                 push_flag = [&](const std::string& name, bool on) {
        std::string label = name.substr(0, 10);
        auto        style = on ? color(Color::Green) : color(Color::Red);
        flag_elems.push_back(text(label) | style);
        flag_elems.push_back(text("  "));
    };

    for (auto& p : persistent) push_flag(p.first, p.second);
    for (auto& p : transients)
        if (p.second) push_flag(p.first, p.second);

    lines.push_back(hbox(flag_elems));

    return vbox(lines) | border | flex | size(WIDTH, GREATER_THAN, 30);
}

Element render_registers() {
    std::vector<Element> lines;
    lines.push_back(text("🧠 Registers") | bold);
    for (int i = 0; i < 32; i += 4) {
        std::ostringstream oss;
        oss << reg_name(i) << ": 0x" << std::hex << RF[i];
        std::string s0 = oss.str();
        oss.str("");
        oss.clear();
        oss << reg_name(i + 1) << ": 0x" << std::hex << RF[i + 1];
        std::string s1 = oss.str();
        oss.str("");
        oss.clear();
        oss << reg_name(i + 2) << ": 0x" << std::hex << RF[i + 2];
        std::string s2 = oss.str();
        oss.str("");
        oss.clear();
        oss << reg_name(i + 3) << ": 0x" << std::hex << RF[i + 3];
        std::string s3 = oss.str();
        lines.push_back(
            hbox({text(s0) | size(WIDTH, EQUAL, 24), text(s1) | size(WIDTH, EQUAL, 24),
                  text(s2) | size(WIDTH, EQUAL, 24), text(s3) | size(WIDTH, EQUAL, 24)}));
    }
    return vbox(lines) | border;
}

Element render_memory(uint64_t center_addr) {
    const int bytes_per_row = 16;
    const int row_radius    = 8;
    uint64_t  base_row      = (center_addr / bytes_per_row) * bytes_per_row;

    auto load_byte = [&](uint64_t addr) -> uint8_t {
        uint32_t word     = machine->SOC->core->MEM_stage->mem->data_seg[addr >> 2];
        int      byte_off = addr & 0x3;
        return (word >> ((3 - byte_off) * 8)) & 0xFF;
    };

    std::vector<Element> lines;
    lines.push_back(text("📦 Memory") | bold);

    for (int dr = -row_radius; dr <= row_radius; ++dr) {
        uint64_t row_addr;
        if (dr < 0) {
            uint64_t abs_offset = uint64_t(-dr) * bytes_per_row;
            if (base_row < abs_offset) {
                lines.push_back(text("   ...") | dim);
                continue;
            }
            row_addr = base_row - abs_offset;
        } else {
            row_addr = base_row + uint64_t(dr) * bytes_per_row;
        }

        std::vector<Element> hex_cells;
        std::string          ascii;
        for (int b = 0; b < bytes_per_row; ++b) {
            if (b == 8) {
                hex_cells.push_back(text("  "));
            }

            uint64_t addr = row_addr + b;
            uint8_t  val  = load_byte(addr);

            std::ostringstream h;
            h << std::hex << std::setw(2) << std::setfill('0') << (int)val;
            auto cell = text(h.str());

            if (addr == center_addr) cell |= bgcolor(Color::Blue) | color(Color::White);

            hex_cells.push_back(cell);
            ascii += (val >= 32 && val <= 126) ? char(val) : '.';
            if ((b + 1) % 4 == 0 && b != 7 && b != 15) {
                hex_cells.push_back(text(" "));
            }
        }

        std::ostringstream addr_s;
        addr_s << std::hex << std::setw(8) << std::setfill('0') << row_addr;
        auto row = hbox({
            text(addr_s.str()) | dim,
            text(": "),
            hbox(hex_cells) | flex,
            text("  "),
            text(ascii) | dim,
        });

        lines.push_back(row);
    }

    return vbox(lines) | border | flex;
}

std::unordered_map<uint32_t, std::string> parseInst(FILE* f) {
    std::unordered_map<uint32_t, std::string> insts;
    char                                      buffer[256];

    while (fgets(buffer, sizeof(buffer), f)) {
        uint32_t addr;
        uint32_t inst;
        char     mnemonic[128];

        if (sscanf(buffer, " %x: %x %[^\n]", &addr, &inst, mnemonic) == 3) {
            std::string fmtStr(mnemonic);
            for (char& c : fmtStr) {
                if (c == '\t') c = ' ';
            }
            insts[addr] = fmtStr;
        }
    }

    return insts;
}

Element render_perip() {
    std::vector<Element> lines;
    lines.push_back(text("🔌 Peripherals") | bold);
    lines.push_back(text(" TODO ") | dim | border);
    return vbox(lines) | border | flex | size(WIDTH, GREATER_THAN, 30);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    ctx     = new VerilatedContext;
    machine = new SOC_sim(ctx);

    // 读入指令映射
    FILE* text_seg = fopen("memory_dump.text.dat", "r");
    if (!text_seg) {
        std::cerr << "Failed to open memory_dump.text.dat!" << std::endl;
        return -1;
    }
    inst_map = parseInst(text_seg);
    fclose(text_seg);

    machine->clk   = 1;
    machine->reset = 1;
    TICK;
    machine->reset = 0;

    auto screen = ScreenInteractive::TerminalOutput();

    Component ui = Renderer([&] {
        auto footer = text("[→] Step [↑/↓] Scroll Memory  [q] Quit") | dim;

        return vbox({render_pipeline(),
                     hbox({render_registers() | flex, render_perip()}) |
                         size(HEIGHT, GREATER_THAN, 10),
                     render_memory(mem_center) | flex, footer}) |
               flex;
    });

    ui = CatchEvent(ui, [&](Event e) {
        if (e == Event::Character('q')) {
            screen.Exit();
            return true;
        }
        if (e == Event::ArrowRight || e == Event::Character('s')) {
            update_state_from_sim();
        }
        if (e == Event::ArrowUp && mem_center > 0) mem_center -= 4;
        if (e == Event::ArrowDown) mem_center += 4;
        return true;
    });

    screen.Loop(ui);
    return 0;
}
