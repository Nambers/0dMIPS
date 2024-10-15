// full_machine: execute a series of MIPS instructions from an instruction cache
//
// except (output) - set to 1 when an unrecognized instruction is to be executed.
// clock   (input) - the clock signal
// reset   (input) - set to 1 to set all registers to zero, set to 0 for normal execution.
`define ALU_ADD    3'b010

module full_machine(
    output wire except,
    input wire clock,
    input wire reset,
    output wire [31:0][63:0] debug_reg_out
);
    // decoder def
    wire [31:0] inst;
    wire [2:0] alu_op;
    wire write_enable, rd_src, mem_read, word_we, byte_we, byte_load, slt, lui, zero, cut_shifter_out32, cut_alu_out32, shift_right, alu_shifter_src, shifter_plus32;
    wire [1:0] alu_src2, control_type;
    // pc counter def
    wire [63:0] pc, next_pc, pc4, pc_branch;
    // reg def
    wire [63:0] A_data, B_data, out, W_data;
    wire [4:0] W_addr;
    // mem def
    wire [7:0] byte_load_out;
    wire [63:0] data_out, mem_out, alu_mem_out, mem_addr;
    // ALU def
    wire negative, overflow;
    wire [63:0] B_in, A_in, slt_out, alu_tmp_out, alu_out;
    // shifter def
    wire [63:0] shifter_out, shifter_tmp_out, shifter_plus32_out;

    // utiles
    wire [63:0] SignExtImm = { {48{inst[15]}}, inst[15:0] };
    wire [63:0] ZeroExtImm = { {48{1'b0}}, inst[15:0] };
    wire [63:0] BranchAddr = { {46{inst[15]}}, inst[15:0], 2'b0 };
    wire [63:0] JumpAddr = {{32{1'b0}}, pc4[63:60], inst[25:0], 2'b0};

    // -- PC counter --
    register #(64) PC_reg(pc, next_pc, clock, 1'b1, reset);
    alu #(64) pc_4alu (pc4, , , , pc, 64'd4, `ALU_ADD);
    alu #(64) pc_branch_alu (pc_branch, , , , pc4, BranchAddr, `ALU_ADD);
    mux4v #(64) pc_mux(next_pc, pc4, pc_branch, JumpAddr, A_data, control_type);

    // -- inst mem --
    instruction_memory im(inst, pc[63:2]);

    // -- reg --
    wire [31:0][63:0] tmp_reg_out;
    regfile #(64) rf (A_data, B_data, inst[25:21], inst[20:16], W_addr, W_data, write_enable, clock, reset, tmp_reg_out);
    `ifdef SIMULATION
        assign debug_reg_out = tmp_reg_out;
    `endif
    mux2v #(5) rd_mux(W_addr, inst[15:11], inst[20:16], rd_src);
    mux2v #(64) lui_mux(W_data, alu_mem_out, {{32{inst[15]}}, inst[15:0], 16'b0 }, lui);

    // -- ALU --
    alu #(64) alu_ (alu_tmp_out, overflow, zero, negative, A_data, B_in, alu_op);
    mux3v #(64) B_in_mux(B_in, B_data, SignExtImm, ZeroExtImm, alu_src2);
    mux2v #(64) slt_mux(slt_out, out, {63'b0, (~A_in[63] & B_in[63]) | ((A_in[63] == B_in[63]) & negative)}, slt);
    mux2v #(64) cut_alu_out(alu_out, alu_tmp_out, {{32{alu_tmp_out[31]}}, alu_tmp_out[31:0]}, cut_alu_out32);

    // -- shifter --
    barrel_shifter32 #(64) shifter(shifter_tmp_out, B_data, inst[10:6], shift_right);
    mux2v #(64) cut_shifter_out(shifter_out, shifter_tmp_out, {{32{shifter_tmp_out[31]}}, shifter_tmp_out[31:0]}, cut_shifter_out32);
    mux2v #(64) shifter_plus32_mux(shifter_plus32_out, shifter_out, {shifter_out[31:0], {32{1'b0}}}, shifter_plus32);

    mux2v #(64) alu_shifter_mux(out, alu_out, shifter_plus32_out, alu_shifter_src);

    // -- mem --
    // {out[63:3], 3'b000} to align the data to the memory
    data_mem #(64) mem(data_out, {out[63:3], 3'b000}, B_data, word_we, byte_we, clock, reset);
    mux8v #(8) byte_load_mux(byte_load_out,
        data_out[7:0], data_out[15:8], data_out[23:16], data_out[31:24],
        data_out[39:32], data_out[47:40], data_out[55:48], data_out[63:56],
        out[2:0]);
    mux2v #(64) mem_out_mux(mem_out, data_out, {{56{byte_load_out[7]}}, byte_load_out}, byte_load);
    mux2v #(64) alu_mem_mux(alu_mem_out, slt_out, mem_out, mem_read);

    // -- decoder --
    mips_decode decoder(alu_op, write_enable, rd_src, alu_src2, except, control_type, mem_read, word_we, byte_we, byte_load, slt, lui, shift_right, shifter_plus32, alu_shifter_src, cut_shifter_out32, cut_alu_out32, inst[31:26], inst[5:0], zero);
    
endmodule // full_machine
