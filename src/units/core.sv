// core: execute a series of MIPS instructions from an instruction cache

import structures::IF_regs_t;
import structures::ID_regs_t;
import structures::EX_regs_t;
import structures::MEM_regs_t;
import structures::forward_type_t;
import structures::mem_bus_req_t;
import structures::mem_bus_resp_t;

module core #(
    parameter PERIPHERAL_BASE = 64'h2000_0000
) (
    input logic clock,
    input logic reset,

    // --- L2/memory interface ---
    output mem_bus_req_t  mem_bus_req,
    input  mem_bus_resp_t mem_bus_resp,

    // --- data ---
    output logic [63:0] d_addr,  // peripheral data addr
    output logic [63:0] d_wdata,  // peripheral data W_data send
    input logic [63:0] d_rdata,  // peripheral data R_data return
    output mem_store_type_t d_store_type,  // peripheral data store type
    output logic d_valid,  // ask for peripheral data
    input logic d_ready,  // peripheral data ready

    // --- outside interrupt source ---
    input logic [7:0] interrupt_sources
);
    // pipeline
    logic stall  /* verilator public */, flush  /* verilator public */, B_is_reg;
    IF_regs_t  IF_regs  /* verilator public */;
    ID_regs_t  ID_regs  /* verilator public */;
    EX_regs_t  EX_regs  /* verilator public */;
    MEM_regs_t MEM_regs  /* verilator public */;

    logic [63:0] next_fetch_pc, EX_A_data_forwarded;
    logic [31:0] inst  /* verilator public */;
    forward_type_t forward_A  /* verilator public */, forward_B  /* verilator public */;
    logic hazard_d_valid;

    core_forward forward_unit (
        .ID_rs(ID_regs.inst[25:21]),
        .ID_rt(ID_regs.inst[20:16]),
        .ID_B_is_reg(ID_regs.B_is_reg),
        .EX_rd(EX_regs.W_regnum),
        .EX_alu_writeback(EX_regs.write_enable && !(|EX_regs.mem_load_type)),
        .MEM_rd(MEM_regs.W_regnum),
        .MEM_mem_writeback(MEM_regs.write_enable),
        .forward_A(forward_A),
        .forward_B(forward_B)
    );

    core_hazard #(PERIPHERAL_BASE) hazard_unit (
        .IF_rs(inst[25:21]),
        .IF_rt(inst[20:16]),
        .IF_B_is_reg(B_is_reg),
        .ID_W_regnum(ID_regs.W_regnum),
        .ID_mem_read(|ID_regs.mem_load_type),
        .stall(stall),

        // --- peripherals ---
        .addr(EX_regs.out),
        .EX_mem_read(|EX_regs.mem_load_type),
        .EX_mem_write(|EX_regs.mem_store_type),
        .d_ready(d_ready || mem_bus_resp.mem_ready),
        .d_valid(hazard_d_valid)
    );

    core_branch branch_unit (
        .ID_regs(ID_regs),
        .EX_regs(EX_regs),
        .forward_A(forward_A),
        .MEM_data(MEM_regs.W_data),
        .fetch_pc4(IF_regs.fetch_pc4),
        .EPC(MEM_regs.EPC),
        .takenHandler(MEM_regs.takenHandler),
        .reset(reset),
        .next_fetch_pc(next_fetch_pc),
        .flush(flush)
    );

    core_IF IF_stage (
        .clock(clock),
        .reset(reset),
        .next_fetch_pc(next_fetch_pc),
        .stall(stall),
        .flush(flush),
        .IF_regs(IF_regs)
    );

    core_ID ID_stage (
        .clock(clock),
        .reset(reset),
        .IF_regs(IF_regs),
        .inst(inst),
        .stall(stall),
        .flush(flush),
        .MEM_regs(MEM_regs),
        .ID_regs(ID_regs),
        .B_is_reg(B_is_reg)
    );

    core_EX EX_stage (
        .clock(clock),
        .reset(reset),
        .ID_regs(ID_regs),
        .flush(flush),
        .EX_regs(EX_regs),
        .MEM_data(MEM_regs.W_data),
        .forward_A(forward_A),
        .forward_B(forward_B),
        .takenHandler(MEM_regs.takenHandler)
    );

    core_MEM MEM_stage (
        .clock(clock),
        .reset(reset),
        .fetch_pc(IF_regs.fetch_pc),
        .ID_pc(ID_regs.pc),
        .ID_reserved_inst_E(ID_regs.reserved_inst_E),
        .interrupt_sources(interrupt_sources),
        .flush(flush),  // for memory fetch
        .ID_ERET(ID_regs.ERET),
        .d_valid(d_valid),
        .d_ready(d_ready),
        .d_rdata(d_rdata),
        .inst(inst),
        .EX_regs(EX_regs),
        .MEM_regs(MEM_regs),
        .mem_bus_req(mem_bus_req),
        .mem_bus_resp(mem_bus_resp)
    );

    // -- peripheral --
    always_comb begin
        d_store_type = EX_regs.mem_store_type;
        d_addr = EX_regs.out;
        d_wdata = EX_regs.B_data;
        d_valid = hazard_d_valid || mem_bus_req.mem_req_load || mem_bus_req.mem_req_store;
    end
endmodule  // core
