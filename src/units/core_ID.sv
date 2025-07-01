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
    input logic [63:0] next_pc,
    output ID_regs_t ID_regs,
    output logic B_is_reg
);
    logic [63:0]
        A_data, B_data, A_data_forwarded, B_data_forwarded, B_data_badinst, BranchAddrFinal;
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
        syscall,
        BEQ,
        BNE,
        BC,
        BAL,
        signed_byte,
        signed_word,
        ignore_overflow;

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
        .syscall(syscall),
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
        .B_is_reg(B_is_reg),
        .inst(IF_regs.inst)
    );

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

    mux2v #(64) forwarded_A_mux (
        A_data_forwarded,
        A_data,
        MEM_regs.W_data,
        MEM_regs.write_enable & (MEM_regs.W_regnum == rs)
    );

    mux2v #(64) forwarded_B_mux (
        B_data_forwarded,
        B_data,
        MEM_regs.W_data,
        B_is_reg & MEM_regs.write_enable & (MEM_regs.W_regnum == rt)
    );

    mux2v #(64) badinstr_B (
        B_data_badinst,
        B_data_forwarded,
        {32'b0, IF_regs.inst},
        syscall || reserved_inst_E
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
            ID_regs.syscall <= syscall;
            ID_regs.BEQ <= BEQ;
            ID_regs.BNE <= BNE;
            ID_regs.BC <= BC;
            ID_regs.BAL <= BAL;
            ID_regs.alu_src2 <= alu_src2;
            ID_regs.control_type <= control_type;
            ID_regs.shifter_plus32 <= shifter_plus32;
            ID_regs.A_data <= A_data_forwarded;
            ID_regs.B_data <= B_data_badinst;
            ID_regs.inst <= IF_regs.inst;
            ID_regs.pc4 <= IF_regs.pc4;
            ID_regs.pc_branch <= BranchAddrFinal;
            ID_regs.jumpAddr <= JumpAddr;
            ID_regs.lui <= lui;
            ID_regs.linkpc <= linkpc;
            ID_regs.signed_byte <= signed_byte;
            ID_regs.signed_word <= signed_word;
            ID_regs.ignore_overflow <= ignore_overflow;
            ID_regs.B_is_reg <= B_is_reg;
            ID_regs.cp0_rd <= IF_regs.inst[15:11];
        end
        // for setting EPC
        ID_regs.pc <= flush ? next_pc : IF_regs.pc;
    end
endmodule
