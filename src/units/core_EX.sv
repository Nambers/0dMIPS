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
    input logic stall,
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
        lu_out,
        shifter_tmp_out,
        shifter_out,
        shifter_plus32_out,
        forwarded_A_WB,
        forwarded_A_EX,
        forwarded_B_WB,
        forwarded_B_EX;

    mux3v #(64) A_data_fwd_WB (
        forwarded_A_WB,
        ID_regs.A_data,
        'z,
        MEM_data,
        forward_A
    );
    mux2v #(64) A_data_fwd_EX (
        forwarded_A_EX,
        forwarded_A_WB,
        EX_regs.out,
        EX_regs.write_enable & (EX_regs.W_regnum == ID_regs.rs)
    );

    mux3v #(64) B_data_fwd_WB (
        forwarded_B_WB,
        ID_regs.B_data,
        'z,
        MEM_data,
        forward_B
    );
    mux2v #(64) B_data_fwd_EX (
        forwarded_B_EX,
        forwarded_B_WB,
        EX_regs.B_data,
        EX_regs.write_enable & (EX_regs.W_regnum == ID_regs.rt) & ID_regs.B_is_reg
    );
    mux2v #(64) mux2v_0 (
        alu_tmp_out,
        ID_regs.AU_out,
        lu_out,
        ID_regs.alu_op[2]
    );
    lu #(64) lu_0 (
        forwarded_A_EX,
        forwarded_B_EX,
        ID_regs.alu_op[1:0],
        lu_out
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
        forwarded_B_EX,
        ID_regs.shamt,
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

    mux3v #(64) slt_mux (
        slt_out,
        out,
        {
            63'b0,
            // if different sign, check if A < 0, else check negative flag from alu
            ((forwarded_A_EX[63] ^ forwarded_B_EX[63]) & forwarded_A_EX[63]) | (~(forwarded_A_EX[63] ^ forwarded_B_EX[63]) & ID_regs.negative)
        },
        {63'b0, ID_regs.borrow_out},
        ID_regs.slt_type
    );

    always_ff @(posedge clock, posedge reset) begin
        // linkerpc is set when jal etc. they need to write back pc4
        if (reset || (flush & !ID_regs.linkpc) || stall) begin
            EX_regs <= '0;
        end else begin
            EX_regs.out <= slt_out;
            EX_regs.B_data <= forwarded_B_EX;
            EX_regs.W_regnum <= ID_regs.W_regnum;
            EX_regs.pc4 <= ID_regs.pc4;
            EX_regs.overflow <= ID_regs.overflow;
            EX_regs.zero <= ID_regs.zero;
            EX_regs.sel <= ID_regs.sel;
            EX_regs.mem_load_type <= ID_regs.mem_load_type;
            EX_regs.mem_store_type <= ID_regs.mem_store_type;
            EX_regs.MFC0 <= ID_regs.MFC0;
            EX_regs.MTC0 <= ID_regs.MTC0;
            EX_regs.ERET <= ID_regs.ERET;
            EX_regs.write_enable <= ID_regs.write_enable;
            EX_regs.reserved_inst_E <= ID_regs.reserved_inst_E;
            EX_regs.signed_byte <= ID_regs.signed_byte;
            EX_regs.signed_word <= ID_regs.signed_word;
            EX_regs.linkpc <= ID_regs.linkpc;
`ifdef DEBUGGER
            EX_regs.pc   <= ID_regs.pc;
            EX_regs.inst <= ID_regs.inst;
`endif
        end
    end
endmodule
