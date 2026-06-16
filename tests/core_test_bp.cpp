#include "core_test.hpp"
#include <Core_core_ID.h>
#include <Core_regfile__W40.h>

// Tests for the dynamic branch predictor (src/modules/core_branch_predictor.sv).
//
// The predictor never changes results -- a misprediction is always caught and
// flushed in EX by core_branch -- so these tests assert on its *performance*
// effect: a trained, taken branch is predicted taken to the correct target, so
// fetch follows the branch with 0 bubbles instead of paying the
// predict-not-taken misprediction penalty every iteration.
//
// `pred_npc` (the speculative next fetch PC produced in IF1) is verilator-public
// on core, so we read it directly to see what the predictor decided for the
// instruction currently sitting in IF1 (whose PC is FETCH_PC).

// A self-looping always-taken branch:
//   PC 0: beq $1, $1, -1   ; $1==$1 always, target = (0+4) + (-1<<2) = 0
//
// Untrained, the predictor says "not taken" (pred_npc = PC+4) and fetch slips
// forward until EX resolves the branch and flushes back -- the misprediction
// penalty. Once trained it predicts taken to PC 0, turning the branch into a
// tight 0-bubble loop (FETCH_PC and pred_npc both pinned at 0).
TEST_F(CoreTest, BranchPredictor_LearnsSelfLoopBranch) {
    reset();
    preloadCacheLine(ICACHE, 0, 0xff);
    preloadCacheLine(DCACHE, 0, 0xff);
    setAddrDWord(ICACHE, 0, inst_comb(build_I_inst(0x4, 1, 1, -1), 0));
    tick();
    RESET_PC();

    // First time the branch is in IF1: nothing learned yet -> predict not taken.
    tick();
    EXPECT_EQ(FETCH_PC, 0);
    EXPECT_EQ(inst_->core->pred_npc, 4);

    // Let the one-time misprediction resolve in EX and train BHT+BTB.
    for (int i = 0; i < 5; ++i)
        tick();

    // Now steady state: every cycle the branch is re-fetched at PC 0 and
    // predicted taken back to PC 0 -- a 0-bubble loop with no further flushes.
    for (int i = 0; i < 4; ++i) {
        EXPECT_EQ(FETCH_PC, 0);
        EXPECT_EQ(inst_->core->pred_npc, 0);
        tick();
    }
}

// Two distinct always-taken branches that jump to each other, to show the BTB
// tracks more than one branch PC (each indexed/tagged independently):
//   PC 0 : beq $1, $1, +15  ; target = (0+4)  + ( 15<<2) = 64
//   PC 64: beq $1, $1, -17  ; target = (64+4) + (-17<<2) = 0
//
// Once both are trained the pipeline ping-pongs 0 <-> 64 with no bubbles, and
// each branch's predicted target is its own correct destination.
TEST_F(CoreTest, BranchPredictor_TracksTwoBranches) {
    reset();
    preloadCacheLine(ICACHE, 0, 0xff);
    preloadCacheLine(DCACHE, 0, 0xff);
    setAddrDWord(ICACHE, 0, inst_comb(build_I_inst(0x4, 1, 1, 15), 0));
    setAddrDWord(ICACHE, 64, inst_comb(build_I_inst(0x4, 1, 1, -17), 0));
    tick();
    RESET_PC();

    // Warm up both branches (each pays its misprediction once).
    for (int i = 0; i < 9; ++i)
        tick();

    // Steady ping-pong: whichever branch is in IF1 is predicted taken to the
    // other one. Two full round trips, no flush in between.
    for (int i = 0; i < 2; ++i) {
        EXPECT_EQ(FETCH_PC, 0);
        EXPECT_EQ(inst_->core->pred_npc, 64);
        tick();
        EXPECT_EQ(FETCH_PC, 64);
        EXPECT_EQ(inst_->core->pred_npc, 0);
        tick();
    }
}

// A finite counted loop -- the realistic case -- to confirm prediction never
// changes the result: the loop must still exit correctly and run the code after
// it, even though the last (not-taken) iteration mispredicts and is flushed.
//   $1 = 3
//   PC 0: addiu $1, $1, -1    ; $1--
//   PC 4: bne   $1, $0, 0     ; loop while $1 != 0, target = (4+4) + (-2<<2) = 0
//   PC 8: ori   $5, $0, 0x123 ; sentinel executed only after the loop exits
TEST_F(CoreTest, BranchPredictor_CountedLoopStillCorrect) {
    reset();
    preloadCacheLine(ICACHE, 0, 0xff);
    preloadCacheLine(DCACHE, 0, 0xff);
    WRITE_RF(1, 3);
    setAddrDWord(ICACHE, 0, inst_comb(build_I_inst(0x9, 1, 1, -1),
                                      build_I_inst(0x5, 1, 0, -2)));
    setAddrDWord(ICACHE, 8, inst_comb(build_I_inst(0xd, 0, 5, 0x123), 0));
    tick();
    RESET_PC();

    bool sentinel_ran = false;
    for (int i = 0; i < 24; ++i) {
        tick();
        if (RF->wr_enable && RF->W_addr == 5 && RF->W_data == 0x123)
            sentinel_ran = true;
    }
    // Loop exited and the post-loop instruction wrote $5 = 0x123.
    EXPECT_TRUE(sentinel_ran);
}
