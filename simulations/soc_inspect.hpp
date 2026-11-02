// Typed C++ views over the DPI inspectors in simulations/sv/soc_inspect.sv.
//
// This is the only C++ that calls dbg_* directly: geometry, address decoding
// and bit layout always come from the SV side, and every index is
// range-checked. Construct views only after the Verilated model exists.
#ifndef SIMULATIONS_SOC_INSPECT_HPP
#define SIMULATIONS_SOC_INSPECT_HPP

// set per target by simulations/CMakeLists.txt to the model's "<prefix>__Dpi.h"
#ifndef ODMIPS_DPI_HEADER
#error                                                                         \
    "ODMIPS_DPI_HEADER is not defined; build through simulations/CMakeLists.txt"
#endif
#include ODMIPS_DPI_HEADER
#include <svdpi.h>

#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

namespace soc_inspect {

// Instance paths inside soc_tb; each has an inspector bound as ".insp".
inline constexpr const char *RF_PATH = "TOP.soc_tb.dut.core.ID_stage.rf";
inline constexpr const char *ICACHE_PATH =
    "TOP.soc_tb.dut.core.IF_stage.inst_cache";
inline constexpr const char *DCACHE_PATH =
    "TOP.soc_tb.dut.core.MEM_stage.data_cache";
inline constexpr const char *MEM_PATH = "TOP.soc_tb.dut.data_mem.data_seg_xpm";

inline svScope open_scope(const std::string &inst) {
    svScope s = svGetScopeFromName((inst + ".insp").c_str());
    if (!s)
        throw std::runtime_error("no DPI inspector bound at " + inst);
    return s;
}

class RegFileView {
  public:
    explicit RegFileView(const std::string &inst = RF_PATH)
        : scope_(open_scope(inst)) {}

    static constexpr int size() { return 32; }

    uint64_t operator[](int i) const {
        svSetScope(scope_);
        unsigned long long v;
        if (dbg_rf_read(i, &v) != 0)
            throw std::out_of_range("register " + std::to_string(i));
        return v;
    }

  private:
    svScope scope_;
};

struct CacheLine {
    bool valid, dirty, lru;
    uint64_t tag;
    std::vector<uint64_t> words;
};

struct CacheAddr {
    int index;
    uint64_t tag;
    int word;
};

class CacheView {
  public:
    explicit CacheView(const std::string &inst) : scope_(open_scope(inst)) {
        svSetScope(scope_);
        dbg_cache_geometry(&ways_, &entries_, &words_);
    }

    int ways() const { return ways_; }
    int entries() const { return entries_; }
    int words() const { return words_; }

    // tag/valid/dirty/LRU only
    CacheLine meta(int way, int idx) const {
        svSetScope(scope_);
        svBit v, d, l;
        unsigned long long t;
        if (dbg_cache_meta(way, idx, &v, &d, &l, &t) != 0)
            throw std::out_of_range("cache line (" + std::to_string(way) +
                                    ", " + std::to_string(idx) + ")");
        return CacheLine{bool(v), bool(d), bool(l), t, {}};
    }

    uint64_t word(int way, int word, int idx) const {
        svSetScope(scope_);
        unsigned long long x;
        if (dbg_cache_word(way, word, idx, &x) != 0)
            throw std::out_of_range("cache word (" + std::to_string(way) +
                                    ", " + std::to_string(word) + ", " +
                                    std::to_string(idx) + ")");
        return x;
    }

    CacheLine line(int way, int idx) const {
        CacheLine l = meta(way, idx);
        l.words.resize(words_);
        for (int w = 0; w < words_; ++w)
            l.words[w] = word(way, w, idx);
        return l;
    }

    // address split exactly as the RTL does it
    CacheAddr decode(uint64_t addr) const {
        svSetScope(scope_);
        CacheAddr a{};
        unsigned long long t;
        dbg_cache_decode(addr, &a.index, &t, &a.word);
        a.tag = t;
        return a;
    }

  private:
    svScope scope_;
    int ways_ = 0, entries_ = 0, words_ = 0;
};

class MemView {
  public:
    explicit MemView(const std::string &inst = MEM_PATH)
        : scope_(open_scope(inst)) {
        svSetScope(scope_);
        dbg_mem_geometry(&lines_, &line_bytes_);
    }

    int lines() const { return lines_; }
    int line_bytes() const { return line_bytes_; }
    uint64_t size_bytes() const { return uint64_t(lines_) * line_bytes_; }
    bool contains(uint64_t addr) const { return addr < size_bytes(); }

    // little-endian 64-bit word at an 8-byte-aligned byte address
    uint64_t dword(uint64_t addr) const {
        if (!contains(addr) || addr % 8 != 0)
            throw std::out_of_range("memory dword at " + std::to_string(addr));
        svSetScope(scope_);
        unsigned long long x;
        dbg_mem_word(int(addr / line_bytes_), int(addr % line_bytes_ / 8), &x);
        return x;
    }

    uint8_t byte(uint64_t addr) const {
        return uint8_t(dword(addr & ~uint64_t(7)) >> (addr % 8 * 8));
    }

  private:
    svScope scope_;
    int lines_ = 0, line_bytes_ = 0;
};

} // namespace soc_inspect

#endif // SIMULATIONS_SOC_INSPECT_HPP
