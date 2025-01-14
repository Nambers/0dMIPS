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
    output logic            [63:0] d_addr,        // peripheral data addr
    output logic            [63:0] d_wdata,       // peripheral data W_data send
    input  logic            [63:0] d_rdata,       // peripheral data R_data return
    output mem_store_type_t        d_store_type,  // peripheral data store type
    output logic                   d_valid,       // ask for peripheral data
    input  logic                   d_ready,       // peripheral data ready

    // // --- outside interrupt source ---
    input logic [7:0] interrupt_sources
);
    // pipeline
    logic stall  /* verilator public */, flush  /* verilator public */;
    IF_regs_t  IF_regs;
    ID_regs_t  ID_regs;
    EX_regs_t  EX_regs;
    MEM_regs_t MEM_regs;

    logic [63:0] pc  /* verilator public */, next_pc;
    logic [31:0] inst  /* verilator public */;
    forward_type_t forward_A  /* verilator public */, forward_B  /* verilator public */;

    core_forward forward_unit (
        .ID_rs(ID_regs.inst[25:21]),
        .ID_rt(ID_regs.inst[20:16]),
        .EX_rd(EX_regs.W_regnum),
        .EX_alu_writeback(EX_regs.write_enable & ~(|EX_regs.mem_load_type)),
        .MEM_rd(MEM_regs.W_regnum),
        .MEM_mem_writeback(MEM_regs.write_enable),
        .forward_A(forward_A),
        .forward_B(forward_B)
    );

    // TODO in mem stage, redirect d_data to WB
    core_hazard hazard_unit (
        .IF_rs(IF_regs.inst[25:21]),
        .IF_rt(IF_regs.inst[20:16]),
        .ID_W_regnum(ID_regs.W_regnum),
        .ID_mem_read(|ID_regs.mem_load_type),
        .stall(stall),

        // --- peripherals ---
        .addr(EX_regs.out),
        .EX_mem_read(|EX_regs.mem_load_type),
        .EX_mem_write(|EX_regs.mem_store_type),
        .d_ready(d_ready),
        .d_valid(d_valid)
    );

    core_branch branch_unit (
        .ID_regs(ID_regs),
        .EX_regs(EX_regs),
        .pc4(IF_regs.pc4),
        .EPC(MEM_regs.EPC),
        .takenHandler(MEM_regs.takenHandler),
        .next_pc(next_pc),
        .flush(flush)
    );

    core_IF IF_stage (
        .clock(clock),
        .reset(reset),
        .next_pc(next_pc),
        .inst(inst),
        .stall(stall),
        .flush(flush),
        .pc(pc),
        .IF_regs(IF_regs)
    );

    core_ID ID_stage (
        .clock(clock),
        .reset(reset),
        .IF_regs(IF_regs),
        .stall(stall),
        .flush(flush),
        .MEM_regs(MEM_regs),
        .ID_regs(ID_regs)
    );

    core_EX EX_stage (
        .clock(clock),
        .reset(reset),
        .ID_regs(ID_regs),
        .flush(flush),
        .EX_regs(EX_regs),
        .MEM_data(MEM_regs.W_data),
        .forward_A(forward_A),
        .forward_B(forward_B)
    );

    core_MEM MEM_stage (
        .clock(clock),
        .reset(reset),
        .inst_addr(pc),
        .interrupt_sources(interrupt_sources),
        .next_pc(next_pc),
        .d_valid(d_valid),
        .d_ready(d_ready),
        .d_rdata(d_rdata),
        .inst(inst),
        .EX_regs(EX_regs),
        .MEM_regs(MEM_regs)
    );

    // -- peripheral --
    assign d_store_type = EX_regs.mem_store_type;
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
