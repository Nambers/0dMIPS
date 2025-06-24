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
    // -- forward --
    input forward_type_t forward_A,
    input forward_type_t forward_B,
    output EX_regs_t EX_regs
);
    logic [63:0]
        slt_out,
        alu_tmp_out,
        alu_out,
        out,
        lui_out,
        shifter_tmp_out,
        shifter_out,
        shifter_plus32_out,
        forwarded_A,
        forwarded_B,
        lu_out;

    mux3v #(64) forward_mux_A (
        forwarded_A,
        ID_regs.A_data,
        EX_regs.out,
        MEM_data,
        forward_A
    );

    // mux3v #(64) forward_mux_B (
    //     forwarded_B,
    //     ID_regs.B_data,
    //     EX_regs.out,
    //     MEM_data,
    //     forward_B
    // );
    // Only LU don't need to forward from elsewhere
    // but keep ref for future use
    assign forwarded_B = ID_regs.B_data;
    mux2v #(64) mux2v_0 (
        alu_tmp_out,
        ID_regs.AU_out,
        lu_out,
        ID_regs.alu_op[2]
    );
    lu #(64) lu_0 (
        forwarded_A,
        forwarded_B,
        ID_regs.alu_op[1:0],
        lu_out
    );

    mux3v #(64) slt_mux (
        slt_out,
        out,
        {
            63'b0,
            // if different sign, check if A < 0, else check negative flag from alu
            ((forwarded_A[63] ^ forwarded_B[63]) & forwarded_A[63]) | (~(forwarded_A[63] ^ forwarded_B[63]) & ID_regs.negative)
        },
        {63'b0, ID_regs.borrow_out},
        ID_regs.slt_type
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

    always_ff @(posedge clock, posedge reset) begin
        if (reset || (flush & !ID_regs.linkpc)) begin
            EX_regs <= '0;
        end else begin
            EX_regs.out <= lui_out;
            EX_regs.B_data <= forwarded_B;
            EX_regs.W_regnum <= ID_regs.W_regnum;
            EX_regs.pc4 <= ID_regs.pc4;
            EX_regs.overflow <= ID_regs.overflow;
            EX_regs.zero <= ID_regs.zero;
            EX_regs.sel <= ID_regs.inst[2:0];
            EX_regs.mem_load_type <= ID_regs.mem_load_type;
            EX_regs.mem_store_type <= ID_regs.mem_store_type;
            EX_regs.MFC0 <= ID_regs.MFC0;
            EX_regs.MTC0 <= ID_regs.MTC0;
            EX_regs.ERET <= ID_regs.ERET;
            EX_regs.write_enable <= ID_regs.write_enable;
            EX_regs.reserved_inst_E <= ID_regs.reserved_inst_E;
            EX_regs.slt_out <= slt_out;
            EX_regs.signed_byte <= ID_regs.signed_byte;
            EX_regs.signed_word <= ID_regs.signed_word;
            EX_regs.lui <= ID_regs.lui;
            EX_regs.linkpc <= ID_regs.linkpc;
`ifdef DEBUGGER
            EX_regs.pc   <= ID_regs.pc;
            EX_regs.inst <= ID_regs.inst;
`endif
        end
    end
endmodule
