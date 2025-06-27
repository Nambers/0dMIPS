import structures::IF_regs_t;
import structures::ID_regs_t;
import structures::MEM_regs_t;
import structures::control_type_t;
import structures::mem_load_type_t;
import structures::mem_store_type_t;
import structures::slt_type_t;
import structures::alu_cut_t;

module core_ID (
    input logic clock,
    input logic reset,
    input IF_regs_t IF_regs,
    input logic stall,
    input logic flush,
    /* verilator lint_off UNUSEDSIGNAL */
    input MEM_regs_t MEM_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input forward_type_t forward_A,
    input forward_type_t forward_B,
    input logic [63:0] EX_out,
    output ID_regs_t ID_regs,
    output logic B_is_reg  /* verilator public */,
    output logic use_AU
);
    logic [63:0]
        A_data,
        B_data,
        A_data_forwarded,
        B_data_forwarded,
        B_in,
        B_in_raw,
        forwarded_A_EX,
        forwarded_A_WB,
        forwarded_B_EX,
        forwarded_B_WB,
        BranchAddrFinal,
        AU_out,
        lui_out;
    logic [4:0] W_regnum, rs, rt, rd;
    logic [2:0] alu_op;
    logic [1:0] alu_src2, shifter_plus32, rd_src;
    control_type_t control_type;
    mem_load_type_t mem_load_type;
    mem_store_type_t mem_store_type;
    slt_type_t slt_type;
    alu_cut_t alu_cut;
    logic
        reserved_inst_E,
        write_enable,
        lui,
        linkpc,
        cut_shifter_out32,
        shift_right,
        alu_shifter_src,
        MFC0,
        MTC0,
        ERET,
        BEQ,
        BNE,
        BC,
        BAL,
        signed_byte,
        signed_word,
        ignore_overflow,
        overflow,
        zero,
        negative,
        borrow_out;

    wire [63:0] SignExtImm = {{48{IF_regs.inst[15]}}, IF_regs.inst[15:0]};
    wire [63:0] ZeroExtImm = {{48{1'b0}}, IF_regs.inst[15:0]};

    mux3v #(64) forward_mux_A (
        forwarded_A_EX,
        A_data,
        EX_out,
        'z,
        forward_A
    );
    mux2v #(64) forward_mux_A_WB (
        forwarded_A_WB,
        forwarded_A_EX,
        MEM_regs.W_data,
        MEM_regs.write_enable & (MEM_regs.W_regnum == rs)
    );
    mux2v #(64) A_in_mux (
        A_data_forwarded,
        forwarded_A_WB,
        ID_regs.AU_out,
        use_AU & (ID_regs.W_regnum == rs) & ID_regs.write_enable
    );

    mux3v #(64) B_data_fwd_EX_mux (
        forwarded_B_EX,
        B_data,
        EX_out,
        'z,
        forward_B
    );
    mux2v #(64) B_data_fwd_WB_mux (
        forwarded_B_WB,
        forwarded_B_EX,
        MEM_regs.W_data,
        MEM_regs.write_enable & (MEM_regs.W_regnum == rt)
    );
    mux2v #(64) B_data_fwd_ID_mux (
        B_data_forwarded,
        forwarded_B_WB,
        ID_regs.AU_out,
        B_is_reg & use_AU & (ID_regs.W_regnum == rt) & ID_regs.write_enable
    );
    mux3v #(64) B_in_mux (
        B_in,
        B_data_forwarded,
        SignExtImm,
        ZeroExtImm,
        alu_src2
    );
    mux2v #(64) B_in_store_mux (
        B_in_raw,
        B_in,
        B_data_forwarded,
        |mem_store_type  // if store data, need raw B_data
    );
    au #(64) au_ (
        .a(A_data_forwarded),
        .b(B_in),
        .sub(alu_op[0]),
        .out(AU_out),
        .overflow(overflow),
        .zero(zero),
        .negative(negative),
        .borrow_out(borrow_out)
    );
    mux2v #(64) lui_mux (
        lui_out,
        AU_out,
        {{32{IF_regs.inst[15]}}, IF_regs.inst[15:0], 16'b0},
        lui
    );

    // -- decoder --
    mips_decoder decoder (
        .alu_op(alu_op),
        .writeenable(write_enable),
        .rd_src(rd_src),
        .alu_src2(alu_src2),
        .except(reserved_inst_E),
        .control_type(control_type),
        .mem_store_type(mem_store_type),
        .mem_load_type(mem_load_type),
        .slt_type(slt_type),
        .lui_out(lui),
        .linkpc(linkpc),
        .shift_right(shift_right),
        .shifter_plus32(shifter_plus32),
        .alu_shifter_src(alu_shifter_src),
        .cut_shifter_out32(cut_shifter_out32),
        .cut_alu_out32(alu_cut),
        .MFC0(MFC0),
        .MTC0(MTC0),
        .ERET(ERET),
        .beq(BEQ),
        .bne(BNE),
        .bc(BC),
        .bal(BAL),
        .signed_byte(signed_byte),
        .signed_word(signed_word),
        .ignore_overflow(ignore_overflow),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .inst(IF_regs.inst)
    );
    assign B_is_reg = alu_src2 == 0;

    // -- reg --
    regfile #(64) rf (
        A_data,
        B_data,
        rs,
        rt,
        MEM_regs.W_regnum,
        MEM_regs.W_data,
        MEM_regs.write_enable,
        clock,
        reset
    );

    mux3v #(5) rd_mux (
        W_regnum,
        rd,
        rt,
        'h1f,  // $ra
        rd_src
    );

    wire [63:0] BranchAddr = {{46{IF_regs.inst[15]}}, IF_regs.inst[15:0], 2'b0};
    wire [63:0] CompactBranchAddr = {{36{IF_regs.inst[25]}}, IF_regs.inst[25:0], 2'b0};

    wire [63:0] JumpAddr = {{32{1'b0}}, IF_regs.pc4[63:60], IF_regs.inst[25:0], 2'b0};

    mux2v #(64) BranchAddr_mux (
        BranchAddrFinal,
        IF_regs.pc + BranchAddr,
        IF_regs.pc + CompactBranchAddr,
        BC
    );

    always_ff @(posedge clock, posedge reset) begin
`ifdef DEBUG
        if (MEM_regs.write_enable) begin
            $display("writeback regnum = %d, data = %h", MEM_regs.W_regnum, MEM_regs.W_data);
        end
        if (reserved_inst_E) begin
            $display("reserved instruction detected op=0x%h, inst=0x%h", IF_regs.inst[31:26],
                     IF_regs.inst);
        end
`endif
        // add bubble for load-use hazard instead of freeze-like stall
        if (reset || flush || stall) begin
            ID_regs <= '0;
        end else begin
            ID_regs.W_regnum <= W_regnum;
            ID_regs.reserved_inst_E <= reserved_inst_E;
            ID_regs.alu_op <= alu_op;
            ID_regs.write_enable <= write_enable;
            ID_regs.mem_store_type <= mem_store_type;
            ID_regs.mem_load_type <= mem_load_type;
            ID_regs.slt_type <= slt_type;
            ID_regs.cut_shifter_out32 <= cut_shifter_out32;
            ID_regs.cut_alu_out32 <= alu_cut;
            ID_regs.shift_right <= shift_right;
            ID_regs.alu_shifter_src <= alu_shifter_src;
            ID_regs.MFC0 <= MFC0;
            ID_regs.MTC0 <= MTC0;
            ID_regs.ERET <= ERET;
            ID_regs.BEQ <= BEQ;
            ID_regs.BNE <= BNE;
            ID_regs.BC <= BC;
            ID_regs.BAL <= BAL;
            ID_regs.alu_src2 <= alu_src2;
            ID_regs.control_type <= control_type;
            ID_regs.shifter_plus32 <= shifter_plus32;
            ID_regs.A_data <= A_data_forwarded;
            ID_regs.B_data <= B_in_raw;
            ID_regs.shamt <= IF_regs.inst[10:6];
            ID_regs.rs <= rs;
            ID_regs.rt <= rt;
            ID_regs.pc4 <= IF_regs.pc4;
            ID_regs.pc_branch <= BranchAddrFinal;
            ID_regs.jumpAddr <= JumpAddr;
            ID_regs.linkpc <= linkpc;
            ID_regs.signed_byte <= signed_byte;
            ID_regs.signed_word <= signed_word;
            ID_regs.AU_out <= lui_out;
            ID_regs.zero <= zero;
            ID_regs.negative <= negative;
            ID_regs.borrow_out <= borrow_out;
            ID_regs.overflow <= overflow & ~ignore_overflow;
            ID_regs.B_is_reg <= B_is_reg;
`ifdef DEBUGGER
            ID_regs.inst <= IF_regs.inst;
            ID_regs.pc   <= IF_regs.pc;
`endif
        end
    end
endmodule
