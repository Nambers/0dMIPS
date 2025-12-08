import structures::ID_regs_t;
import structures::EX_regs_t;
import structures::forward_type_t;

module core_EX (
    input logic clock,
    input logic reset,
    input logic stall_t2,
    /* verilator lint_off UNUSEDSIGNAL */
    input ID_regs_t ID_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic flush,
    input logic [63:0] MEM_data,
    // -- forward --
    input forward_type_t forward_A,
    input forward_type_t forward_B,
    input logic takenHandler,
    output EX_regs_t EX_regs
);
    logic negative, overflow, zero, borrow_out;
    logic [ 4:0] barrel_sa;
    logic [31:0] rotator32_tmp_out;
    logic [63:0]
        B_in_barrel,
        A_in_barrel,
        barrel_in,
        slt_out,
        ext_out,
        alu_tmp_out,
        alu_out,
        out,
        lui_out,
        shifter_tmp_out,
        rotator_tmp_out,
        rotator_len_out,
        barrel_out,
        barrel_plus32_out,
        forwarded_A,
        forwarded_B,
        SignExtImm,
        ZeroExtImm,
        SEH_out,
        SEB_out;

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

    mux4v #(64) B_in_barrel_mux (
        B_in_barrel,
        forwarded_B,
        barrel_out,
        SignExtImm,
        ZeroExtImm,
        ID_regs.alu_b_src
    );

    mux3v #(64) A_in_barrel_mux (
        A_in_barrel,
        forwarded_A,
        barrel_out,
        ID_regs.pc,
        ID_regs.alu_a_src
    );

    mux2v #(64) barrel_in_mux (
        barrel_in,
        forwarded_B,
        forwarded_A,
        ID_regs.barrel_src
    );

    mux2v #(5) barrel_sa_mux (
        barrel_sa,
        ID_regs.shamt,
        forwarded_A[4:0],
        ID_regs.barrel_sa_src
    );

    // -- ALU --
    alu #(64) alu_ (
        .out(alu_tmp_out),
        .overflow(overflow),
        .zero(zero),
        .negative(negative),
        .borrow_out(borrow_out),
        .a(A_in_barrel),
        .b(B_in_barrel),
        .alu_op(ID_regs.alu_op)
    );
    mux3v #(64) cut_alu_out (
        alu_out,
        alu_tmp_out,
        {{32{alu_tmp_out[31]}}, alu_tmp_out[31:0]},
        {32'b0, alu_tmp_out[31:0]},
        ID_regs.cut_alu_out32
    );

    // -- barrel --
    barrel_shifter32 #(64) shifter (
        shifter_tmp_out,
        barrel_in,
        barrel_sa,
        ID_regs.barrel_right,
        ID_regs.shift_arith
    );
    barrel_rotator32 #(64) rotator (
        rotator_tmp_out,
        barrel_in,
        barrel_sa,
        ID_regs.barrel_right
    );
    barrel_rotator32 #(32) rotator32 (
        rotator32_tmp_out,
        barrel_in[31:0],
        barrel_sa,
        ID_regs.barrel_right
    );
    mux2v #(64) rotator_len_mux (
        rotator_len_out,
        rotator_tmp_out,
        {32'b0, rotator32_tmp_out},
        ID_regs.rotator_src
    );
    mux4v #(64) cut_barrel_out (
        barrel_out,
        shifter_tmp_out,
        rotator_tmp_out,
        {{32{shifter_tmp_out[31]}}, shifter_tmp_out[31:0]},
        {{32{rotator_len_out[31]}}, rotator_len_out[31:0]},
        ID_regs.cut_barrel_out32
    );
    mux4v #(64) barrel_plus32_mux (
        barrel_plus32_out,
        barrel_out,
        {barrel_out[31:0], {32{1'b0}}},
        {{32{1'b0}}, barrel_out[63:32]},
        {barrel_out[31:0], barrel_out[63:32]},
        ID_regs.barrel_plus32
    );

    mux3v #(64) alu_barrel_mux (
        out,
        alu_out,
        barrel_plus32_out,
        ID_regs.pc_branch,
        ID_regs.ex_out_src
    );

    mux2v #(64) lui_mux (
        lui_out,
        out,
        {{32{ID_regs.inst[15]}}, ID_regs.inst[15:0], 16'b0},
        ID_regs.lui
    );
    mux3v #(64) slt_mux (
        slt_out,
        lui_out,
        {
            63'b0,
            // if different sign, check if A < 0, else check negative flag from alu
            ((forwarded_A[63] ^ forwarded_B[63]) & forwarded_A[63]) | (~(forwarded_A[63] ^ forwarded_B[63]) & negative)
        },
        {63'b0, borrow_out},
        ID_regs.slt_type
    );

    mux3v #(64) ext_mux (
        ext_out,
        slt_out,
        SEB_out,
        SEH_out,
        ID_regs.ext_src
    );

    always_comb begin
        SignExtImm = {{48{ID_regs.inst[15]}}, ID_regs.inst[15:0]};
        ZeroExtImm = {{48{1'b0}}, ID_regs.inst[15:0]};
        SEH_out = {{48{ID_regs.B_data[15]}}, ID_regs.B_data[15:0]};
        SEB_out = {{56{ID_regs.B_data[7]}}, ID_regs.B_data[7:0]};
    end

    EX_regs_t EX_regs_cache;

    always_ff @(posedge clock, posedge reset) begin
        if (reset || (flush && (!ID_regs.linkpc || takenHandler))) begin
            EX_regs <= '0;
        end else if (stall_t2) begin
            EX_regs <= EX_regs_cache;
        end else begin
            EX_regs_cache <= EX_regs;
            EX_regs.out <= ext_out;
            EX_regs.B_data <= forwarded_B;
            EX_regs.W_regnum <= ID_regs.W_regnum;
            EX_regs.pc4 <= ID_regs.pc4;
            EX_regs.overflow <= overflow && (!ID_regs.ignore_overflow);
            EX_regs.zero <= zero;
            EX_regs.sel <= ID_regs.inst[2:0];
            EX_regs.mem_load_type <= ID_regs.mem_load_type;
            EX_regs.mem_store_type <= ID_regs.mem_store_type;
            EX_regs.MFC0 <= ID_regs.MFC0;
            EX_regs.MTC0 <= ID_regs.MTC0;
            EX_regs.break_ <= ID_regs.break_;
            EX_regs.syscall <= ID_regs.syscall;
            EX_regs.BEQ <= ID_regs.BEQ;
            EX_regs.BNE <= ID_regs.BNE;
            EX_regs.BC <= ID_regs.BC;
            EX_regs.BAL <= ID_regs.BAL;
            EX_regs.pc_branch <= ID_regs.pc_branch;
            EX_regs.write_enable <= ID_regs.write_enable;
            EX_regs.signed_mem_out <= ID_regs.signed_mem_out;
            EX_regs.linkpc <= ID_regs.linkpc;
            EX_regs.cp0_rd <= ID_regs.cp0_rd;
`ifdef DEBUGGER
            EX_regs.inst <= ID_regs.inst;
            EX_regs.pc   <= ID_regs.pc;
`endif
        end
    end
endmodule
