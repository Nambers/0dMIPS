#include <ftxui/component/component.hpp>
#include <ftxui/component/screen_interactive.hpp>
#include <ftxui/dom/elements.hpp>
#include <ftxui/dom/node.hpp>

#include <array>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <unordered_map>

#include <SOC_sim.h>
#include <SOC_sim_SOC.h>
#include <SOC_sim_cache_L1.h>
#include <SOC_sim_core.h>
#include <SOC_sim_core_ID.h>
#include <SOC_sim_core_IF.h>
#include <SOC_sim_core_MEM.h>
#include <SOC_sim_cp0.h>
#include <SOC_sim_data_mem.h>
#include <SOC_sim_regfile__W40.h>
#include <SOC_sim_stdout.h>
#include <SOC_sim_timer.h>
#include <SOC_sim_xpm_memory_sdpram__pi1.h>
#include <capstone/capstone.h>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "../tests/cache_L1_helper.hpp"
#include "common.hpp"

enum class MemType { NO = 0, BYTE, WORD, DWORD };

using namespace ftxui;

class RingBuffer {
  public:
    explicit RingBuffer(size_t capacity)
        : buffer_(capacity), capacity_(capacity), head_(0), count_(0) {
        buffer_[0] = "";
    }

    void append_char(char c) {
        if (c == '\n') {
            push_line("");
        } else {
            if (count_ == 0) {
                push_line(std::string(1, c));
            } else {
                size_t tail = (head_ + count_ - 1) % capacity_;
                buffer_[tail] += c;
            }
        }
    }

    void push_line(const std::string &line) {
        if (capacity_ == 0)
            return;
        size_t idx = (head_ + count_) % capacity_;
        buffer_[idx] = line;
        if (count_ < capacity_) {
            ++count_;
        } else {
            head_ = (head_ + 1) % capacity_;
        }
    }

    std::string str() const {
        std::ostringstream oss;
        for (size_t i = 0; i < count_; ++i) {
            size_t idx = (head_ + i) % capacity_;
            oss << buffer_[idx] << '\n';
        }
        return oss.str();
    }

  private:
    std::vector<std::string> buffer_;
    size_t capacity_;
    size_t head_;
    size_t count_;
};

uint64_t mem_center = 0x0;
uint64_t last_mem_read = -1, last_mem_write = -1;
MemType readType = MemType::NO, writeType = MemType::NO;
std::array typeBytes = {0, 1, 4, 8}; // NO, BYTE, WORD, DWORD

std::map<std::string, std::string> pipeline;

std::array<uint64_t, 32> RF;

std::map<std::string, bool> flags;

SOC_sim *machine = nullptr;
VerilatedContext *ctx = nullptr;
csh cs_handle;

std::string reg_name(int i) {
    constexpr static std::array names = {
        "r0", "at", "v0", "v1", "a0", "a1", "a2", "a3", "t0", "t1", "t2",
        "t3", "t4", "t5", "t6", "t7", "s0", "s1", "s2", "s3", "s4", "s5",
        "s6", "s7", "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"};
    if (i >= 0 && i < 32)
        return names[i];
    return "reg";
}

std::unordered_map<uint64_t, DisasmEntry> disasm_cache;

void update_state_from_sim() {
    TICK;
    pipeline["IF"] = "N/A";
    pipeline["ID"] = get_disasm(vlwide_get(machine->SOC->core->IF_regs, 32, 64),
                                vlwide_get(machine->SOC->core->IF_regs, 0, 32),
                                disasm_cache, cs_handle);
    pipeline["EX"] = get_disasm(vlwide_get(machine->SOC->core->ID_regs, 0, 64),
                                vlwide_get(machine->SOC->core->ID_regs, 64, 32),
                                disasm_cache, cs_handle);
    pipeline["MEM"] =
        get_disasm(vlwide_get(machine->SOC->core->EX_regs, 0, 64),
                   vlwide_get(machine->SOC->core->EX_regs, 64, 32),
                   disasm_cache, cs_handle);
    pipeline["WB"] =
        get_disasm(vlwide_get(machine->SOC->core->MEM_regs, 0, 64),
                   vlwide_get(machine->SOC->core->MEM_regs, 64, 32),
                   disasm_cache, cs_handle);

    auto &R = machine->SOC->core->ID_stage->rf
                  ->__PVT__reg_out; // VlWide<64>，2048 bits

    // reg0 = bits [63:0]，reg1 = bits [127:64], ..., reg31 = bits [2047:1984]
    for (int i = 0; i < 32; ++i) {
        // idx = i*64； width = 64
        RF[i] = vlwide_get(R, i * 64, 64);
    }

    const auto &readTmp =
        vlwide_get(machine->SOC->core->EX_regs, 64 + 32 + 10, 2);
    const auto &memAddr = vlwide_get(machine->SOC->core->EX_regs,
                                     64 + 32 + 10 + 2 * 2 + 3 + 5 + 3 * 64, 64);
    if (readTmp) {
        // load
        readType = static_cast<MemType>(readTmp);
        last_mem_read = memAddr;
    }
    const auto &writeTmp =
        vlwide_get(machine->SOC->core->EX_regs, 64 + 32 + 10 + 2, 2);
    if (writeTmp) {
        // store
        writeType = static_cast<MemType>(writeTmp);
        last_mem_write = memAddr;
    }

    flags["I"] = machine->SOC->interrupt_sources;
    flags["S"] = machine->SOC->core->stall;
    flags["F"] = machine->SOC->core->flush;
    flags["R"] = machine->SOC->reset;
    flags["D"] = machine->SOC->core->__PVT__d_valid;
    flags["AA"] = (machine->SOC->core->forward_A == 1);
    flags["AM"] = (machine->SOC->core->forward_A == 2);
    flags["BA"] = (machine->SOC->core->forward_B == 1);
    flags["BM"] = (machine->SOC->core->forward_B == 2);
    flags["DR"] = machine->SOC->core->__PVT__d_ready;
    flags["OE"] = (machine->SOC->core->MEM_stage->cp0_->exc_code == 0xc);
    flags["IE"] = (machine->SOC->core->MEM_stage->cp0_->exc_code == 0xa);
    flags["SC"] = (machine->SOC->core->MEM_stage->cp0_->exc_code == 0x8);
}

Element render_pipeline() {
    std::vector<Element> lines;
    lines.push_back(text("🚀 Pipeline") | bold);

    for (const auto &stage :
         std::array<std::string, 5>{"IF", "ID", "EX", "MEM", "WB"}) {
        std::string inst_str = pipeline.count(stage) ? pipeline[stage] : "N/A";
        lines.push_back(hbox({text(stage + ": ") | bold, text(inst_str)}));
    }

    std::vector<std::pair<std::string, bool>> persistent = {
        {"Interrupt", flags["I"]},    {"Stall", flags["S"]},
        {"Flush", flags["F"]},        {"Reset", flags["R"]},
        {"PeriphAccess", flags["D"]},
    };
    std::vector<std::pair<std::string, bool>> transients = {
        {"InstExc", flags["IE"]}, {"Overflow", flags["OE"]},
        {"Syscall", flags["SC"]}, {"PeriphReady", flags["DR"]},
        {"fA-EX", flags["AA"]},   {"fA-MEM", flags["AM"]},
        {"fB-EX", flags["BA"]},   {"fB-MEM", flags["BM"]}};

    std::vector<Element> flag_elems;
    auto push_flag = [&](const std::string &name, bool on) {
        std::string label = name.substr(0, 10);
        auto style = on ? color(Color::Green) : color(Color::Red);
        flag_elems.push_back(text(label) | style);
        flag_elems.push_back(text("  "));
    };

    for (auto &p : persistent)
        push_flag(p.first, p.second);
    for (auto &p : transients)
        if (p.second)
            push_flag(p.first, p.second);

    lines.push_back(hbox(flag_elems));

    auto left_panel = vbox(lines) | border | flex;

    // Timer peripheral
    auto timer_panel =
        vbox({
            text("⏱ Peripheral: Timer") | bold,
            text("Cycle: " + std::to_string(machine->SOC->timer->cycle_D)),
        }) |
        border | size(WIDTH, EQUAL, 22);

    // PC indicator
    std::ostringstream pc_hex;
    pc_hex << "0x" << std::hex << std::setw(8) << std::setfill('0')
           << vlwide_get(machine->SOC->core->IF_regs, 32, 64);

    auto pc_panel = vbox({
                        text("📍 PC") | bold,
                        text("Value: " + pc_hex.str()),
                    }) |
                    border | size(WIDTH, EQUAL, 22);

    return hbox({left_panel, vbox({timer_panel, pc_panel})}) | flex;
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
        lines.push_back(hbox({text(s0) | size(WIDTH, EQUAL, 24),
                              text(s1) | size(WIDTH, EQUAL, 24),
                              text(s2) | size(WIDTH, EQUAL, 24),
                              text(s3) | size(WIDTH, EQUAL, 24)}));
    }
    return vbox(lines) | border;
}

Element render_cache(SOC_sim_cache_L1 *cache, const std::string &label,
                     bool miss_stall) {
    constexpr int num_entries = 32;
    uint64_t cur_addr = cache->addr;
    unsigned int cur_idx = getIndex(cur_addr);
    uint64_t cur_tag = getTag(cur_addr);
    uint8_t way_hit_bits = cache->way_hit;

    std::ostringstream addr_oss;
    addr_oss << "0x" << std::hex << std::setw(8) << std::setfill('0')
             << (uint32_t)cur_addr;

    std::vector<Element> rows;
    rows.push_back(hbox({
        text(label) | bold,
        text("  addr:") | dim,
        text(addr_oss.str()) | color(Color::Cyan),
        text("  idx:" + std::to_string(cur_idx)) | color(Color::Yellow),
        text(miss_stall ? "  MISS-STALL" : "") | color(Color::Red) | bold,
    }));

    rows.push_back(hbox({
        text("Idx") | size(WIDTH, EQUAL, 3) | bold | dim,
        text(" LRU") | bold | dim,
        text(" | ") | dim,
        text("W0 V D Tag    Data[0]          ") | bold | dim,
        text("| ") | dim,
        text("W1 V D Tag    Data[0]         ") | bold | dim,
    }));

    auto make_way_elem = [&](int w, int i, bool is_lru) -> Element {
        bool valid = (bool)cache->valid_array[w][i];
        bool dirty = (bool)cache->dirty_array[w][i];
        uint64_t tag = cache->tag_array[w][i];
        uint64_t data0 = cacheDataBank(cache, w, 0)[i];
        bool is_hit = (way_hit_bits >> w) & 1;
        bool tag_match = (i == (int)cur_idx) && valid && (tag == cur_tag);

        std::ostringstream tag_oss, data_oss;
        tag_oss << std::hex << std::setw(6) << std::setfill('0')
                << (tag & 0x1FFFFF);
        data_oss << std::hex << std::setw(16) << std::setfill('0') << data0;

        auto v_elem = text(valid ? "V" : ".") |
                      color(valid ? (is_lru ? Color::GrayLight : Color::Green)
                                  : Color::GrayDark);
        auto d_elem = text(dirty ? "D" : ".") |
                      color(dirty ? Color::Red : Color::GrayDark);
        auto tag_elem = text(tag_oss.str()) | size(WIDTH, EQUAL, 6);
        if (tag_match || is_hit)
            tag_elem = tag_elem | color(Color::Yellow) | bold;
        auto data_elem = text(data_oss.str()) | dim | size(WIDTH, EQUAL, 16);

        return hbox({v_elem, text(" "), d_elem, text("  "), tag_elem,
                     text("  "), data_elem});
    };

    for (int i = 0; i < num_entries; ++i) {
        bool is_cur = (i == (int)cur_idx);
        uint8_t lru = cache->__PVT__LRU_way_array[i];

        std::ostringstream idx_oss;
        idx_oss << std::setw(2) << std::setfill(' ') << i;

        auto lru_elem = text(lru == 0 ? " W0 " : " W1 ") | color(Color::Blue);

        auto row_elem = hbox({
            text(idx_oss.str()) | size(WIDTH, EQUAL, 3),
            lru_elem,
            text("| ") | dim,
            make_way_elem(0, i, lru == 0) | size(WIDTH, EQUAL, 30),
            text(" | ") | dim,
            make_way_elem(1, i, lru == 1),
        });

        if (is_cur)
            row_elem = row_elem | bgcolor(Color::DarkBlue);

        rows.push_back(row_elem);
    }

    return vbox(rows) | border | flex;
}

Element render_cache_L1() {
    bool dcache_miss =
        (bool)machine->SOC->core->MEM_stage->data_cache_miss_stall;
    return hbox({
        render_cache(machine->SOC->core->IF_stage->inst_cache, "⚡ ICache L1",
                     false),
        render_cache(machine->SOC->core->MEM_stage->data_cache, "⚡ DCache L1",
                     dcache_miss),
    });
}

Element render_memory(uint64_t &center_addr) {
    constexpr int bytes_per_row = 16;
    constexpr int row_radius = 8;
    uint64_t base_row = (center_addr / bytes_per_row) * bytes_per_row;

    // mem_bus_req packed fields (572 bits total, little-endian in VlWide):
    //   [0]      = mem_req_load
    //   [1]      = mem_req_store
    //   [513:2]  = mem_data_out (512 bits)
    //   [571:514]= mem_addr (58 bits = physical_addr >> 6, cache-line aligned)
    bool bus_load = vlwide_get(machine->SOC->mem_bus_req, 0, 1);
    bool bus_store = vlwide_get(machine->SOC->mem_bus_req, 1, 1);
    uint64_t bus_lo = vlwide_get(machine->SOC->mem_bus_req, 512 + 2, 58) << 6;
    uint64_t bus_hi = bus_lo + 64;

    if (bus_load || bus_store) {
        // if there's an ongoing bus request, center the view on the requested
        // cache line
        center_addr = bus_lo;
        base_row = bus_lo;
    }

    auto load_byte = [&](uint64_t addr) -> uint8_t {
        constexpr size_t W = 16; // VlWide<16>
        auto &row = machine->SOC->data_mem->data_seg_xpm
                        ->mem[addr / (sizeof(EData) * W)];
        EData word = row[(addr / sizeof(EData)) % W];
        return word >> ((addr % sizeof(EData)) * 8);
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
        std::string ascii;
        for (int b = 0; b < bytes_per_row; ++b) {
            if (b == 8) {
                hex_cells.push_back(text("  "));
            }

            uint64_t addr = row_addr + b;
            uint8_t val = load_byte(addr);

            std::ostringstream h;
            h << std::hex << std::setw(2) << std::setfill('0') << (int)val;
            auto cell = text(h.str());

            // bus request highlight: dim background for the 64-byte cache line
            if ((bus_load || bus_store) && addr >= bus_lo && addr < bus_hi)
                cell = cell |
                       bgcolor(bus_store ? Color::DarkRed : Color::DarkMagenta);

            if (addr == center_addr) {
                cell |= bgcolor(Color::Blue) | color(Color::White);
            } else if (writeType != MemType::NO && addr >= last_mem_write &&
                       addr < last_mem_write +
                                  typeBytes[static_cast<int>(writeType)]) {
                cell |= color(Color::Cyan);
            } else if (readType != MemType::NO && addr >= last_mem_read &&
                       addr < last_mem_read +
                                  typeBytes[static_cast<int>(readType)]) {
                cell |= color(Color::Yellow);
            }

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

std::unordered_map<uint32_t, std::string> parseInst(FILE *f) {
    std::unordered_map<uint32_t, std::string> insts;
    char buffer[256];

    while (fgets(buffer, sizeof(buffer), f)) {
        uint32_t addr;
        uint32_t inst;
        char mnemonic[128];

        if (sscanf(buffer, " %x: %x %[^\n]", &addr, &inst, mnemonic) == 3) {
            std::string fmtStr(mnemonic);
            for (char &c : fmtStr) {
                if (c == '\t')
                    c = ' ';
            }
            insts[addr] = fmtStr;
        }
    }

    return insts;
}

Element render_perip() {
    static RingBuffer stdoutBuffer(6);
    std::vector<Element> lines;
    lines.push_back(text("🔌 Peripheral: STDOUT") | bold);
    static size_t lastCheck = 0;

    if (ctx->time() > lastCheck && machine->SOC->stdout->stdout_taken) {
        lastCheck = ctx->time();
        uint64_t data = be64toh(machine->SOC->stdout->buffer);
        char *buf = reinterpret_cast<char *>(&data);

        for (int i = 0; i < 8; ++i) {
            char c = buf[i];
            if (c == 0)
                break;
            stdoutBuffer.append_char(c);
        }
    }

    std::string output = stdoutBuffer.str();
    if (output.empty()) {
        output = "No output yet.";
    }

    std::istringstream iss(output);
    std::string line;
    while (std::getline(iss, line)) {
        if (!line.empty()) {
            lines.push_back(text(line) | dim);
        }
    }

    return vbox(lines) | border | flex | size(WIDTH, GREATER_THAN, 30);
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    ctx = new VerilatedContext;
    machine = new SOC_sim(ctx);
    if (init_capstone(&cs_handle) != 0) {
        return 1;
    }

    machine->sys_clk = 1;
    machine->sys_rst_n = 0;
    TICK;
    machine->sys_rst_n = 1;

    auto screen = ScreenInteractive::TerminalOutput();

    bool showModal = false;

    Component ui = Renderer([&] {
        auto footer = text("[→] Step [↑/pgUp/↓/pgDown] Scroll Memory  [q] Quit "
                           "[c] jump to cycle") |
                      dim;

        return vbox({render_pipeline(),
                     hbox({render_registers() | flex, render_perip()}) |
                         size(HEIGHT, GREATER_THAN, 10),
                     render_cache_L1() | size(HEIGHT, GREATER_THAN, 10),
                     render_memory(mem_center) | flex, footer}) |
               flex;
    });

    Component jumpModal = ([&] {
        // input box and button
        static std::string cycleStr;
        static std::string errMsg;
        auto cycleInp = Input(&cycleStr, "200");

        auto onClick = [&] {
            errMsg.clear();
            if (cycleStr.empty()) {
                showModal = false;
                return;
            }
            uint64_t cycle = std::stoull(cycleStr, nullptr) *
                             2; // ctx time is for both 2 edges
            if (cycle <= ctx->time()) {
                errMsg = "Err: Cycle already passed.";
                cycleInp->TakeFocus();
                return;
            }
            uint64_t diff = cycle - ctx->time();
            if (diff > 2)
                for (uint64_t i = 0; i < diff - 2; i += 2) {
                    TICK;
                }
            showModal = false;
            update_state_from_sim();
        };

        auto jumpButton = Button("Jump", onClick, ButtonOption::Ascii());
        jumpButton |= CatchEvent([&](Event event) {
            if (event == Event::Return) {
                onClick();
            } else if (event == Event::Tab)
                cycleInp->TakeFocus();
            else
                return false;
            return true;
        });

        cycleInp |= CatchEvent([&](Event event) {
            if (event.is_character() && !std::isxdigit(event.character()[0])) {
            } else if (event == Event::Return) {
                onClick();
            } else if (event == Event::Tab)
                jumpButton->TakeFocus();
            else
                return false;
            return true;
        });

        auto container = Container::Horizontal({
            cycleInp,
            jumpButton,
        });

        return Renderer(container, [&] {
            return vbox({
                       text("Jump to cycle") | bold,
                       text(errMsg) | color(Color::Red),
                       hbox({
                           text("0d") | color(Color::GrayLight),
                           cycleInp->Render(),
                           separator(),
                           jumpButton->Render(),
                       }),
                   }) |
                   border | size(HEIGHT, EQUAL, 5);
        });
    })();

    ui |= Modal(jumpModal, &showModal);

    ui = CatchEvent(ui, [&](Event e) {
        if (e == Event::Character('q'))
            screen.Exit();
        else if (!showModal) {
            if (e == Event::ArrowRight || e == Event::Character('s'))
                update_state_from_sim();
            else if (e == Event::Character('c'))
                showModal = true;
            else if (e == Event::ArrowUp && mem_center > 0)
                mem_center -= 4;
            else if (e == Event::ArrowDown)
                mem_center += 4;
            else if (e == Event::PageDown)
                mem_center += 64;
            else if (e == Event::PageUp && mem_center >= 64)
                mem_center -= 64;
            else
                return false;
        } else
            return false;
        return true;
    });

    screen.Loop(ui);

    delete machine;
    cs_close(&cs_handle);
    delete ctx;
    return 0;
}
