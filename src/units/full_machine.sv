// full_machine: execute a series of MIPS instructions from an instruction cache
//
// reserved_inst_E (output) - set to 1 when an unrecognized instruction is to be executed.
// clock   (input) - the clock signal
// reset   (input) - set to 1 to set all registers to zero, set to 0 for normal execution.
`define ALU_ADD    3'b010
// these didn't limit by ROM size bc they are virtually mapped
`define currentTimeAddr 63'hFFFF001C
`define acknowledgeInterruptAddr 63'hFFFF006C
// need to < ROM size
`define interrupeHandlerAddr 64'h200

module full_machine(
    input logic clock,
    input logic reset
);
    // decoder def
    logic reserved_inst_E;
    logic [31:0] inst /*verilator public*/;
    logic [2:0] alu_op;
    logic write_enable, rd_src, mem_read, word_we, byte_we, byte_load, slt, lui, zero, cut_shifter_out32, cut_alu_out32, shift_right, alu_shifter_src;
    logic [1:0] alu_src2, control_type, shifter_plus32;
    // pc counter def
    logic [63:0] pc /*verilator public*/;
    logic [63:0] next_pc, pc4, pc_branch;
    // reg def
    logic [63:0] A_data, B_data, out, W_data;
    logic [4:0] W_addr;
    // mem def
    logic [7:0] byte_load_out;
    logic [63:0] data_out, mem_out, alu_mem_out, alu_mem_timer_out;
    // ALU def
    /* verilator lint_off UNUSEDSIGNAL */
    logic negative, overflow; // TODO overflow to cp0
    /* verilator lint_on UNUSEDSIGNAL */
    logic [63:0] B_in, A_in, slt_out, alu_tmp_out, alu_out;
    // shifter def
    logic [63:0] shifter_out, shifter_tmp_out, shifter_plus32_out;
    // timer def
    logic        TimerInterrupt, TimerAddress;
    logic [63:0] cycle;
    // cp0 def
    logic [63:0] EPC, c0_rd_data, new_next_pc, new_next_pc_final, new_W_data;
    logic MFC0, MTC0, ERET;
    logic TakenInterrupt /* verilator public */;

    // utiles
    wire [63:0] SignExtImm = { {48{inst[15]}}, inst[15:0] };
    wire [63:0] ZeroExtImm = { {48{1'b0}}, inst[15:0] };
    wire [63:0] BranchAddr = { {46{inst[15]}}, inst[15:0], 2'b0 };
    wire [63:0] JumpAddr = {{32{1'b0}}, pc4[63:60], inst[25:0], 2'b0};

    // -- PC counter --
    register #(64) PC_reg(pc, new_next_pc_final, clock, 1'b1, reset);
    /* verilator lint_off PINNOCONNECT */
    alu #(64) pc_4alu (pc4, , , , pc, 64'd4, `ALU_ADD);
    alu #(64) pc_branch_alu (pc_branch, , , , pc4, BranchAddr, `ALU_ADD);
    /* verilator lint_on PINNOCONNECT */
    mux4v #(64) pc_mux(next_pc, pc4, pc_branch, JumpAddr, A_data, control_type);

    // -- reg --
    regfile #(64) rf (A_data, B_data, inst[25:21], inst[20:16], W_addr, new_W_data, write_enable, clock, reset);
    mux2v #(5) rd_mux(W_addr, inst[15:11], inst[20:16], rd_src);
    mux2v #(64) lui_mux(W_data, alu_mem_timer_out, {{32{inst[15]}}, inst[15:0], 16'b0 }, lui);

    // -- ALU --
    assign A_in = A_data;
    alu #(64) alu_ (alu_tmp_out, overflow, zero, negative, A_in, B_in, alu_op);
    mux3v #(64) B_in_mux(B_in, B_data, SignExtImm, ZeroExtImm, alu_src2);
    mux2v #(64) slt_mux(slt_out, out, {63'b0, (~A_in[63] & B_in[63]) | ((A_in[63] == B_in[63]) & negative)}, slt);
    mux2v #(64) cut_alu_out(alu_out, alu_tmp_out, {{32{alu_tmp_out[31]}}, alu_tmp_out[31:0]}, cut_alu_out32);

    // -- shifter --
    barrel_shifter32 #(64) shifter(shifter_tmp_out, B_data, inst[10:6], shift_right);
    mux2v #(64) cut_shifter_out(shifter_out, shifter_tmp_out, {{32{shifter_tmp_out[31]}}, shifter_tmp_out[31:0]}, cut_shifter_out32);
    mux3v #(64) shifter_plus32_mux(shifter_plus32_out, shifter_out, {shifter_out[31:0], {32{1'b0}}}, {{32{1'b0}}, shifter_out[63:32]}, shifter_plus32);

    mux2v #(64) alu_shifter_mux(out, alu_out, shifter_plus32_out, alu_shifter_src);

    // -- timer --
    timer #(64) t(TimerInterrupt, cycle, TimerAddress, B_data, out[63:0], 1'b1, word_we | byte_we, clock, reset);
    mux2v #(64) alu_mem_timer_mux(alu_mem_timer_out, alu_mem_out, cycle, TimerAddress);

    // -- mem --
    // {out[63:3], 3'b000} to align the data to the memory
    data_mem #(64) mem(data_out, out[63:0], B_data, word_we & ~TimerAddress, byte_we & ~TimerAddress, clock, reset, inst, pc[63:0]);
    mux8v #(8) byte_load_mux(byte_load_out,
        data_out[7:0], data_out[15:8], data_out[23:16], data_out[31:24],
        data_out[39:32], data_out[47:40], data_out[55:48], data_out[63:56],
        out[2:0]);
    mux2v #(64) mem_out_mux(mem_out, data_out, {{56{byte_load_out[7]}}, byte_load_out}, byte_load);
    mux2v #(64) alu_mem_mux(alu_mem_out, slt_out, mem_out, mem_read);

    // -- cp0 --
    cp0 cp(c0_rd_data, EPC, TakenInterrupt, B_data, W_addr, inst[2:0], next_pc, MTC0, ERET, TimerInterrupt, clock, reset, overflow, reserved_inst_E, 0, 0); // TODO syscall, break
    mux2v #(64) ERET_next_pc_mux(new_next_pc, next_pc, EPC, ERET);
    mux2v #(64) Interrupt_pc_mux(new_next_pc_final, new_next_pc, `interrupeHandlerAddr, TakenInterrupt);
    mux2v #(64) mfc0_mux(new_W_data, W_data, c0_rd_data, MFC0);

    // -- decoder --
    mips_decoder decoder(alu_op, write_enable, rd_src, alu_src2, reserved_inst_E, control_type, mem_read, word_we, byte_we, byte_load, slt, lui, shift_right, shifter_plus32, alu_shifter_src, cut_shifter_out32, cut_alu_out32, MFC0, MTC0, ERET, inst, zero);
    
endmodule // full_machine
