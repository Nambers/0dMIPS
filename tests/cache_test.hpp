#ifndef CACHE_TEST_HPP
#define CACHE_TEST_HPP

#include "common.hpp"

template <class C> class CacheTest : public TestBase<C> {
  protected:
    // ==================== Request Getters ====================

    inline bool getLoad() {
        return (this->inst_->req[0] >> 1) & 1; // bit 1
    }

    inline bool getStore() {
        return this->inst_->req[0] & 1; // bit 0
    }

    inline uint64_t getMemAddr() {
        // bits 514-571 (58 bits)
        // bit 514 is at req[16] bit 2
        uint64_t addr = 0;

        // bits 514-543 (30 bits) from req[16] bits 2-31
        addr |= (uint64_t)(this->inst_->req[16] >> 2);

        // bits 544-571 (28 bits) from req[17] bits 0-27
        addr |= (uint64_t)(this->inst_->req[17] & 0x0FFFFFFF) << 30;

        return addr;
    }

    // ==================== Data Out Methods (bits 2-513) ====================

    char getDataOutByte(int index) {
        if (index < 0 || index >= 64)
            return 0;

        // Byte at index starts at bit (index*8 + 2)
        int start_bit = index * 8 + 2;
        uint8_t *base =
            reinterpret_cast<uint8_t *>(&this->inst_->req.m_storage[0]);
        int byte_offset =
            start_bit / 8; // This gives us the byte containing start_bit
        int bit_offset = start_bit % 8; // Bit position within that byte

        // Load 2 bytes to handle potential misalignment
        uint16_t temp;
        std::memcpy(&temp, base + byte_offset, sizeof(temp));

        return (temp >> bit_offset) & 0xFF;
    }

    // ==================== Response Methods ====================

    void setReady(bool ready) {
        if (ready) {
            this->inst_->resp[0] |= 1U;
        } else {
            this->inst_->resp[0] &= ~1U;
        }
    }

    void setDataByte(int index, char byte) {
        if (index < 0 || index >= 64)
            return;

        int start_bit = index * 8 + 1;
        uint8_t *base =
            reinterpret_cast<uint8_t *>(&this->inst_->resp.m_storage[0]);
        int byte_offset = start_bit / 8;
        int bit_offset = start_bit % 8;

        // Load existing data
        uint16_t temp;
        std::memcpy(&temp, base + byte_offset, sizeof(temp));

        // Clear and set the byte
        uint16_t mask = 0xFF << bit_offset;
        temp = (temp & ~mask) |
               (static_cast<uint16_t>((uint8_t)byte) << bit_offset);

        // Write back
        std::memcpy(base + byte_offset, &temp, sizeof(temp));
    }

    void SetUp() override {
        TestBase<C>::SetUp();
        this->inst_->clear = 0;
        this->inst_->enable = 1;
        this->inst_->signed_type = 1;
    }
};

#endif // CACHE_TEST_HPP