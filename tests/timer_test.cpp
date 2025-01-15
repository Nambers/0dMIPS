#include <Timer.h>

#include "common.hpp"

#define CYCLE_ADDR 0x20000000
#define ACK_ADDR 0x20000004

class TimerTest : public TestBase<Timer> {};

TEST_F(TimerTest, ReadCycleTest) {
    inst_->address = CYCLE_ADDR;
    inst_->MemRead = 1;
    inst_->MemWrite = 0;
    DIST_TYPE dist(0, 10);
    int clockCnt = 0;
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < getRandomInt(dist); j++) {
            tick();
            clockCnt++;
            EXPECT_FALSE(inst_->TimerInterrupt);
        }
        EXPECT_EQ(inst_->cycle, clockCnt);
    }
}

TEST_F(TimerTest, InterruptTest) {
    DIST_TYPE dist(1, 20);
    inst_->address = CYCLE_ADDR;
    inst_->MemRead = 0;
    inst_->MemWrite = 1;
    auto interruptCycle = getRandomInt(dist);
    inst_->data = interruptCycle;
    tick();
    inst_->MemWrite = 0;
    inst_->MemRead = 1;
    for (int i = 0; i < interruptCycle; i++) {
        EXPECT_FALSE(inst_->TimerInterrupt);
        tick();
    }
    // currect cycle is one behind the interrupt cycle
    EXPECT_EQ(inst_->cycle, interruptCycle + 1);
    EXPECT_TRUE(inst_->TimerInterrupt);
}

TEST_F(TimerTest, AcknowledgeTest) {
    DIST_TYPE dist(1, 20);
    inst_->address = CYCLE_ADDR;
    inst_->MemRead = 0;
    inst_->MemWrite = 1;
    inst_->data = 1;
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
