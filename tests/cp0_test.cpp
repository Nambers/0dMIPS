#include <Cp0.h>

#include "common.hpp"

#define STATUS_REGISTER 12
#define CAUSE_REGISTER 13
#define EPC_REGISTER 14

class CP0Test : public TestBase<Cp0> {};

TEST_F(CP0Test, MTC0MFC0) {
    inst_->MTC0 = 1;
    inst_->regnum = STATUS_REGISTER;
    inst_->sel = 0;
    inst_->wr_data = 0xFFFFFFFFDEADBEEF;
    tick();
    inst_->MTC0 = 0;
    inst_->regnum = CAUSE_REGISTER;
    tick();
    EXPECT_EQ(inst_->rd_data, 0x0);
    inst_->regnum = STATUS_REGISTER;
    tick();
    // status is 32-bit register
    EXPECT_EQ(inst_->rd_data, 0xDEADBEEF);
};

TEST_F(CP0Test, ERET) {
    inst_->MTC0 = 1;
    inst_->regnum = EPC_REGISTER;
    inst_->wr_data = 0x1234567890ABCDEF;
    tick();
    inst_->regnum = STATUS_REGISTER;
    inst_->sel = 0;
    // set ERL
    inst_->wr_data = 0b10;
    tick();
    inst_->MTC0 = 0;
    inst_->ERET = 1;
    EXPECT_EQ(inst_->EPC, 0x1234567890ABCDEF);
    tick();
    EXPECT_EQ(inst_->rd_data, 0x0);
};
