// core: execute a series of MIPS instructions from an instruction cache
//
// clock   (input) - the clock signal
// reset   (input) - set to 1 to set all registers to zero, set to 0 for normal execution.
`define ALU_ADD 3'b010
// these didn't limit by ROM size bc they are virtually mapped
`define currentTimeAddr 63'hFFFF001C
`define acknowledgeInterruptAddr 63'hFFFF006C
// need to < ROM size
`define interrupeHandlerAddr 64'h200

import structures::IF_regs_t;
import structures::ID_regs_t;
import structures::EX_regs_t;
import structures::MEM_regs_t;
import structures::WB_regs_t;
import structures::forward_type_t;

module core (
    input logic clock,
    input logic reset,
    // // --- inst ---
    // output logic [63:0] i_addr,   // PC
    // // input  logic [31:0] i_data,   // inst
    // output logic        i_valid,  // sent req
    // input  logic        i_ready,  // 

    // // --- data ---
    output logic [63:0] d_addr,     // peripheral data addr
    output logic [63:0] d_wdata,    // peripheral data W_data send
    input  logic [63:0] d_rdata,    // peripheral data R_data return
    output logic        d_word_we,  // peripheral data word enable
    output logic        d_byte_we,  // peripheral data byte enable
    output logic        d_valid,    // ask for peripheral data
    input  logic        d_ready,    // peripheral data ready

    // // --- outside interrupt source ---
    input logic [7:0] interrupt_sources
);
    // pipeline
    logic stall  /* verilator public */, flush  /* verilator public */;
    IF_regs_t  IF_regs;
    ID_regs_t  ID_regs;
    EX_regs_t  EX_regs;
    MEM_regs_t MEM_regs;
    WB_regs_t  WB_regs;

    logic [63:0] pc  /* verilator public */, next_pc;
    logic [31:0] inst;
    forward_type_t forward_A  /* verilator public */, forward_B  /* verilator public */;

    core_forward forward_unit (
        ID_regs.inst[25:21],
        ID_regs.inst[20:16],
        MEM_regs.W_regnum,
        MEM_regs.write_enable,
        WB_regs.W_regnum,
        WB_regs.write_enable,
        forward_A,
        forward_B
    );

    // TODO in mem stage, redirect d_data to WB
    core_hazard hazard_unit (
        ID_regs.inst[25:21],
        ID_regs.inst[20:16],
        EX_regs.W_regnum,
        EX_regs.mem_read,
        stall,
        EX_regs.out,
        EX_regs.byte_we | EX_regs.word_we,
        d_ready,
        d_valid
    );

    core_branch branch_unit (
        ID_regs,
        MEM_regs.EPC,
        MEM_regs.takenInterrupt,
        next_pc,
        flush
    );

    core_IF IF_stage (
        clock,
        reset,
        next_pc,
        inst,
        stall,
        flush,
        pc,
        IF_regs
    );

    core_ID ID_stage (
        clock,
        reset,
        IF_regs,
        WB_regs,
        EX_regs.zero,
        stall,
        flush,
        ID_regs,
        forward_A,
        forward_B,
        MEM_regs.W_data
    );

    core_EX EX_stage (
        clock,
        reset,
        ID_regs,
        stall,
        flush,
        d_valid,
        EX_regs
    );

    core_MEM MEM_stage (
        clock,
        reset,
        EX_regs,
        pc,
        interrupt_sources,
        next_pc,
        d_valid,
        d_ready,
        d_rdata,
        inst,
        MEM_regs
    );

    core_WB WB_stage (
        clock,
        reset,
        MEM_regs.W_regnum,
        MEM_regs.W_data,
        MEM_regs.write_enable,
        WB_regs
    );

    // -- peripheral --
    assign d_word_we = EX_regs.word_we;
    assign d_byte_we = EX_regs.byte_we;
    assign d_addr = EX_regs.out;
    assign d_wdata = EX_regs.B_data;

    // // TODO peripheral device
    // // -- timer --
    // timer #(64) t (
    //     TimerInterrupt,
    //     cycle,
    //     TimerAddress,
    //     B_data,
    //     out,
    //     1'b1,
    //     word_we | byte_we,
    //     clock,
    //     reset
    // );
    // mux2v #(64) alu_mem_timer_mux (
    //     alu_mem_timer_out,
    //     alu_mem_out,
    //     cycle,
    //     TimerAddress
    // );

endmodule  // core
