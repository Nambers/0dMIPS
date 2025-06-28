import structures::ID_regs_t;
import structures::EX_regs_t;
import structures::forward_type_t;

module core_EX (
    input logic clock,
    input logic reset,
    /* verilator lint_off UNUSEDSIGNAL */
    input ID_regs_t ID_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic flush,
    input logic [63:0] MEM_data,
    input logic [63:0] next_pc,
    // -- forward --
    input forward_type_t forward_A,
    input forward_type_t forward_B,
    output EX_regs_t EX_regs
);
    logic negative, overflow, zero, borrow_out;
    logic [63:0]
        B_in,
        slt_out,
        alu_tmp_out,
        alu_out,
        out,
        lui_out,
        shifter_tmp_out,
        shifter_out,
        shifter_plus32_out,
        forwarded_A,
        forwarded_B;

    wire [63:0] SignExtImm = {{48{ID_regs.inst[15]}}, ID_regs.inst[15:0]};
    wire [63:0] ZeroExtImm = {{48{1'b0}}, ID_regs.inst[15:0]};

    mux3v #(64) forward_mux_A (
        forwarded_A,
        ID_regs.A_data,
        EX_regs.out,
        MEM_data,
        forward_A
    );

    mux3v #(64) forward_mux_B (
        forwarded_B,
        ID_regs.B_data,
        EX_regs.out,
        MEM_data,
        forward_B
    );

    mux3v #(64) B_in_mux (
        B_in,
        forwarded_B,
        SignExtImm,
        ZeroExtImm,
        ID_regs.alu_src2
    );

    // -- ALU --
    alu #(64) alu_ (
        .out(alu_tmp_out),
        .overflow(overflow),
        .zero(zero),
        .negative(negative),
        .borrow_out(borrow_out),
        .a(forwarded_A),
        .b(B_in),
        .alu_op(ID_regs.alu_op)
    );
    mux3v #(64) cut_alu_out (
        alu_out,
        alu_tmp_out,
        {{32{alu_tmp_out[31]}}, alu_tmp_out[31:0]},
        {32'b0, alu_tmp_out[31:0]},
        ID_regs.cut_alu_out32
    );

    // -- shifter --
    barrel_shifter32 #(64) shifter (
        shifter_tmp_out,
        forwarded_B,
        ID_regs.inst[10:6],
        ID_regs.shift_right
    );
    mux2v #(64) cut_shifter_out (
        shifter_out,
        shifter_tmp_out,
        {{32{shifter_tmp_out[31]}}, shifter_tmp_out[31:0]},
        ID_regs.cut_shifter_out32
    );
    mux3v #(64) shifter_plus32_mux (
        shifter_plus32_out,
        shifter_out,
        {shifter_out[31:0], {32{1'b0}}},
        {{32{1'b0}}, shifter_out[63:32]},
        ID_regs.shifter_plus32
    );

    mux2v #(64) alu_shifter_mux (
        out,
        alu_out,
        shifter_plus32_out,
        ID_regs.alu_shifter_src
    );

    mux2v #(64) lui_mux (
        lui_out,
        out,
        {{32{ID_regs.inst[15]}}, ID_regs.inst[15:0], 16'b0},
        ID_regs.lui
    );
    mux4v #(64) slt_mux (
        slt_out,
        lui_out,
        {
            63'b0,
            // if different sign, check if A < 0, else check negative flag from alu
            ((forwarded_A[63] ^ B_in[63]) & forwarded_A[63]) | (~(forwarded_A[63] ^ B_in[63]) & negative)
        },
        {63'b0, borrow_out},
        'z,
        ID_regs.slt_type
    );

    always_ff @(posedge clock, posedge reset) begin
        if (reset || (flush & !ID_regs.linkpc)) begin
            EX_regs <= '0;
        end else begin
            EX_regs.out <= slt_out;
            EX_regs.B_data <= forwarded_B;
            EX_regs.W_regnum <= ID_regs.W_regnum;
            EX_regs.pc4 <= ID_regs.pc4;
            EX_regs.overflow <= overflow & ~ID_regs.ignore_overflow;
            EX_regs.zero <= zero;
            EX_regs.sel <= ID_regs.inst[2:0];
            EX_regs.mem_load_type <= ID_regs.mem_load_type;
            EX_regs.mem_store_type <= ID_regs.mem_store_type;
            EX_regs.MFC0 <= ID_regs.MFC0;
            EX_regs.MTC0 <= ID_regs.MTC0;
            EX_regs.ERET <= ID_regs.ERET;
            EX_regs.BEQ <= ID_regs.BEQ;
            EX_regs.BNE <= ID_regs.BNE;
            EX_regs.BC <= ID_regs.BC;
            EX_regs.BAL <= ID_regs.BAL;
            EX_regs.pc_branch <= ID_regs.pc_branch;
            EX_regs.write_enable <= ID_regs.write_enable;
            EX_regs.reserved_inst_E <= ID_regs.reserved_inst_E;
            EX_regs.signed_byte <= ID_regs.signed_byte;
            EX_regs.signed_word <= ID_regs.signed_word;
            EX_regs.linkpc <= ID_regs.linkpc;
`ifdef DEBUGGER
            EX_regs.inst <= ID_regs.inst;
`endif
        end
        // for setting EPC
        EX_regs.pc <= flush ? next_pc : ID_regs.pc;
    end
endmodule
