import structures::ID_regs_t;
import structures::EX_regs_t;
import structures::forward_type_t;

module core_EX (
    input logic clock,
    input logic reset,
    input logic data_cache_miss_stall,
    /* verilator lint_off UNUSEDSIGNAL */
    input ID_regs_t ID_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic flush,
    input logic [63:0] MEM_data,
    input logic [63:0] MEM1_data,
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
        ext_out,
        alu_tmp_out,
        alu_out,
        lui_val,
        slt_calc,
        borrow_val,
        shifter_tmp_out,
        shifter_small_tmp_out,
        rotator_tmp_out,
        rotator_len_out,
        barrel_out,
        barrel_plus32_out,
        forwarded_A,
        forwarded_B,
        SignExtImm,
        ZeroExtImm,
        CacheExtImm,
        SEH_out,
        SEB_out;

    mux4v #(64) forward_mux_A (
        forwarded_A,
        ID_regs.A_data,
        EX_regs.out,
        MEM1_data,
        MEM_data,
        forward_A
    );

    mux4v #(64) forward_mux_B (
        forwarded_B,
        ID_regs.B_data,
        EX_regs.out,
        MEM1_data,
        MEM_data,
        forward_B
    );

    mux8v #(64) B_in_barrel_mux (
        B_in_barrel,
        forwarded_B,
        shifter_small_tmp_out,
        SignExtImm,
        ZeroExtImm,
        CacheExtImm,
        'x,
        'x,
        'x,
        ID_regs.alu_b_src
    );

    mux3v #(64) A_in_barrel_mux (
        A_in_barrel,
        forwarded_A,
        shifter_small_tmp_out,
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
        .zero(),
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
    barrel_shifter_left_small #(64) shifter_small (
        shifter_small_tmp_out,
        barrel_in,
        barrel_sa[2:0]
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

    // Flatten the former alu_barrel -> lui -> slt -> ext mux cascade (4 serial
    // muxes, ~7 LUT levels on the 64-bit datapath) into one parallel mux. The
    // select ex_out_src is fully resolved in the decoder and matches the input
    // order below; the data now passes through a single mux level.
    mux8v #(64) out_sel (
        ext_out,
        alu_out,  // ALU_OUT
        barrel_plus32_out,  // SHIFTER_OUT
        ID_regs.pc_branch,  // PC_BRANCH
        lui_val,  // LUI_OUT
        slt_calc,  // SLT_OUT
        borrow_val,  // SLTU_OUT
        SEB_out,  // SEB_OUT
        SEH_out,  // SEH_OUT
        ID_regs.ex_out_src
    );

    always_comb begin
        SignExtImm = {{48{ID_regs.inst[15]}}, ID_regs.inst[15:0]};
        ZeroExtImm = {{48{1'b0}}, ID_regs.inst[15:0]};
        CacheExtImm = {{55{ID_regs.inst[15]}}, ID_regs.inst[15:7]};
        SEH_out = {{48{ID_regs.B_data[15]}}, ID_regs.B_data[15:0]};
        SEB_out = {{56{ID_regs.B_data[7]}}, ID_regs.B_data[7:0]};
        // bypass alu for timing constrain
        // also in MIPS64, nearly only branching or similar semantics
        // using zero signal, transform to equivalently with a equal b
        zero = A_in_barrel == B_in_barrel;

        // output value candidates selected by ex_out_src (see out_sel above)
        lui_val = {{32{ID_regs.inst[15]}}, ID_regs.inst[15:0], 16'b0};
        // if different sign, check if A < 0, else check negative flag from alu
        slt_calc = {
            63'b0,
            ((forwarded_A[63] ^ forwarded_B[63]) & forwarded_A[63]) | (~(forwarded_A[63] ^ forwarded_B[63]) & negative)
        };
        borrow_val = {63'b0, borrow_out};
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset || (flush && (!ID_regs.linkpc || takenHandler))) begin
            EX_regs <= '0;
        end else if (!data_cache_miss_stall) begin
            EX_regs.out <= ext_out;
            EX_regs.B_data <= forwarded_B;
            EX_regs.W_regnum <= ID_regs.W_regnum;
            EX_regs.pc4 <= ID_regs.pc4;
            EX_regs.predicted_npc <= ID_regs.predicted_npc;
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
            EX_regs.cache <= ID_regs.cache;
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
