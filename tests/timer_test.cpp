#include <Timer.h>

#include "common.hpp"

#define CYCLE_ADDR 0x20000000
#define ACK_ADDR 0x20000004

class TimerTest : public TestBase<Timer> {};

TEST_F(TimerTest, ReadCycleTest) {
    inst_->address = CYCLE_ADDR;
    inst_->MemRead = 1;
    inst_->MemWrite = 0;
    inst_->enable = 1;
    std::uniform_int_distribution<int> dist{0, 10};
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < dist(rng); j++) {
            tick();
            EXPECT_FALSE(inst_->TimerInterrupt);
        }
        EXPECT_EQ(inst_->cycle, this->ctx.time() / 2);
    }
}

TEST_F(TimerTest, InterruptTest) {
    std::uniform_int_distribution<int> dist{1, 20};
    inst_->address = CYCLE_ADDR;
    inst_->MemRead = 0;
    inst_->MemWrite = 1;
    inst_->enable = 1;
    const auto interruptCycle = dist(rng);
    inst_->data = interruptCycle;
    tick();
    inst_->MemWrite = 0;
    inst_->MemRead = 1;
    const auto realCycle = interruptCycle - this->ctx.time() / 2;
    for (int i = 0; i < realCycle; i++) {
        EXPECT_FALSE(inst_->TimerInterrupt);
        tick();
    }
    // currect cycle is one behind the interrupt cycle
    EXPECT_EQ(inst_->cycle, interruptCycle);
    tick(); // will delay one more cycle
    EXPECT_TRUE(inst_->TimerInterrupt);
}

TEST_F(TimerTest, AcknowledgeTest) {
    inst_->address = CYCLE_ADDR;
    inst_->MemRead = 0;
    inst_->MemWrite = 1;
    inst_->data = 1;
    inst_->enable = 1;
    tick();
    inst_->MemWrite = 0;
    inst_->MemRead = 1;
    tick();
    EXPECT_TRUE(inst_->TimerInterrupt);
    inst_->address = ACK_ADDR;
    inst_->MemRead = 0;
    inst_->MemWrite = 1;
    tick();
    EXPECT_FALSE(inst_->TimerInterrupt);
}
