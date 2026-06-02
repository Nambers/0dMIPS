#ifndef CACHE_L1_HELPER_HPP
#define CACHE_L1_HELPER_HPP

#define IDX_BITS 5 // log2(32)
#define IDX_MASK ((1 << IDX_BITS) - 1)
#define OFS_BITS 6 // log2(64)
#define OFS_MASK ((1 << OFS_BITS) - 1)

#include <endian.h>
#include <gtest/gtest.h>

// for cache L1
inline uint64_t getTag(uint64_t addr) {
    return (addr >> (IDX_BITS + OFS_BITS));
}

inline unsigned int getIndex(uint64_t addr) {
    return (addr >> OFS_BITS) & IDX_MASK;
}

inline unsigned int getOffset(uint64_t addr) { return addr & OFS_MASK; }

#define CACHE_DATA(way, word)                                                  \
    cache                                                                      \
        ->way_bank__BRA__##way##__KET____DOT__word_bank__BRA__##word##__KET____DOT__data
template <typename T>
auto &cacheDataBank(T *cache, unsigned int way, unsigned int word) {
    assert(way < 2);
    assert(word < 8);

    if (way == 0) {
        switch (word) {
        case 0:
            return CACHE_DATA(0, 0);
        case 1:
            return CACHE_DATA(0, 1);
        case 2:
            return CACHE_DATA(0, 2);
        case 3:
            return CACHE_DATA(0, 3);
        case 4:
            return CACHE_DATA(0, 4);
        case 5:
            return CACHE_DATA(0, 5);
        case 6:
            return CACHE_DATA(0, 6);
        case 7:
            return CACHE_DATA(0, 7);
        }
    }

    switch (word) {
    case 0:
        return CACHE_DATA(1, 0);
    case 1:
        return CACHE_DATA(1, 1);
    case 2:
        return CACHE_DATA(1, 2);
    case 3:
        return CACHE_DATA(1, 3);
    case 4:
        return CACHE_DATA(1, 4);
    case 5:
        return CACHE_DATA(1, 5);
    case 6:
        return CACHE_DATA(1, 6);
    case 7:
        return CACHE_DATA(1, 7);
    }

    __builtin_unreachable();
}

#undef CACHE_DATA

template <typename T>
uint64_t readCacheDWord(T *cache, unsigned int way, uint64_t addr) {
    const auto offset = getOffset(addr);
    assert((offset % sizeof(uint32_t)) == 0);

    const auto index = getIndex(addr);
    const auto word_idx = offset / sizeof(uint64_t);
    const auto byte_idx = offset % sizeof(uint64_t);
    const auto low_word = cacheDataBank(cache, way, word_idx)[index];

    if (byte_idx == 0)
        return low_word;

    assert(word_idx + 1 < 8);
    const auto high_word = cacheDataBank(cache, way, word_idx + 1)[index];
    const auto shift = byte_idx * 8;
    return (low_word >> shift) | (high_word << (64 - shift));
}

#endif