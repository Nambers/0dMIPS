import structures::IF_regs_t;
import structures::ID_regs_t;
import structures::MEM_regs_t;
import structures::control_type_t;
import structures::mem_load_type_t;
import structures::mem_store_type_t;
import structures::slt_type_t;
import structures::ext_src_t;
import structures::alu_cut_t;
import structures::alu_a_src_t;
import structures::alu_b_src_t;
import structures::EX_out_src_t;
import structures::BranchAddr_src_t;
import structures::cut_barrel_out32_t;

module core_ID (
    input logic clock,
    input logic reset,
    input IF_regs_t IF_regs,
    input logic [31:0] inst,
    input logic stall,
    input logic flush,
    /* verilator lint_off UNUSEDSIGNAL */
    input MEM_regs_t MEM_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    output ID_regs_t ID_regs,
    output logic B_is_reg
);
    logic [63:0]
        A_data,
        B_data,
        A_data_forwarded,
        B_data_forwarded,
        B_data_badinst,
        BranchAddrFinal,
        PCRelAddr;
    logic [4:0] W_regnum, rs, rt, rd, shamt;
    logic [2:0] alu_op;
    logic [1:0] barrel_plus32, rd_src;
    control_type_t control_type;
    mem_load_type_t mem_load_type;
    mem_store_type_t mem_store_type;
    slt_type_t slt_type;
    ext_src_t ext_src;
    alu_cut_t alu_cut;
    alu_a_src_t alu_a_src;
    alu_b_src_t alu_b_src;
    EX_out_src_t ex_out_src;
    BranchAddr_src_t branchAddr_src;
    cut_barrel_out32_t cut_barrel_out32;
    logic
        reserved_inst_E,
        write_enable,
        lui,
        linkpc,
        barrel_right,
        shift_arith,
        barrel_src,
        MFC0,
        MTC0,
        ERET,
        syscall,
        BEQ,
        BNE,
        BC,
        BAL,
        signed_mem_out,
        ignore_overflow;
    logic [63:0] BranchAddr, CompactBranchAddr, JumpAddr;

    // -- decoder --
    mips_decoder decoder (
        .alu_op(alu_op),
        .writeenable(write_enable),
        .rd_src(rd_src),
        .except(reserved_inst_E),
        .control_type(control_type),
        .mem_store_type(mem_store_type),
        .mem_load_type(mem_load_type),
        .slt_type(slt_type),
        .ext_src(ext_src),
        .lui_out(lui),
        .linkpc(linkpc),
        .barrel_right(barrel_right),
        .shift_arith(shift_arith),
        .barrel_plus32(barrel_plus32),
        .ex_out_src(ex_out_src),
        .alu_a_src(alu_a_src),
        .alu_b_src(alu_b_src),
        .barrel_src(barrel_src),
        .cut_barrel_out32(cut_barrel_out32),
        .cut_alu_out32(alu_cut),
        .MFC0(MFC0),
        .MTC0(MTC0),
        .ERET(ERET),
        .syscall(syscall),
        .beq(BEQ),
        .bne(BNE),
        .bc(BC),
        .bal(BAL),
        .signed_mem_out(signed_mem_out),
        .ignore_overflow(ignore_overflow),
        .branchAddr_src(branchAddr_src),
        .rs(rs),
        .rt(rt),
        .rd(rd),
        .shamt(shamt),
        .B_is_reg(B_is_reg),
        .inst(inst)
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
        {32'b0, inst},
        syscall || reserved_inst_E
    );

    mux4v #(5) rd_mux (
        W_regnum,
        rd,
        rt,
        rs,  // e.g. lsa
        5'd31,  // $ra
        rd_src
    );

    mux3v #(64) BranchAddr_mux (
        BranchAddrFinal,
        IF_regs.fetch_pc4 + BranchAddr,
        IF_regs.fetch_pc4 + CompactBranchAddr,
        IF_regs.fetch_pc + PCRelAddr,  // e.g. addiupc
        branchAddr_src
    );

    always_comb begin
        BranchAddr = {{46{inst[15]}}, inst[15:0], 2'b0};
        PCRelAddr = {{43{inst[18]}}, inst[18:0], 2'b0};
        CompactBranchAddr = {{36{inst[25]}}, inst[25:0], 2'b0};
        JumpAddr = {IF_regs.fetch_pc[63:28], inst[25:0], 2'b0};
    end

    always_ff @(posedge clock, posedge reset) begin
`ifdef DEBUG
        if (MEM_regs.write_enable) begin
            $display("writeback regnum = %d, data = %h", MEM_regs.W_regnum,
                     MEM_regs.W_data);
        end
        if (reserved_inst_E) begin
            $display("reserved instruction detected op=0x%h, inst=0x%h",
                     inst[31:26], inst);
        end
`endif
        // add bubble for load-use hazard instead of freeze-like stall
        if (reset || flush || stall) begin
            ID_regs <= '0;
        end else begin
            ID_regs.W_regnum <= W_regnum;
            ID_regs.shamt <= shamt;
            ID_regs.reserved_inst_E <= reserved_inst_E;
            ID_regs.alu_op <= alu_op;
            ID_regs.write_enable <= write_enable;
            ID_regs.mem_store_type <= mem_store_type;
            ID_regs.mem_load_type <= mem_load_type;
            ID_regs.slt_type <= slt_type;
            ID_regs.ext_src <= ext_src;
            ID_regs.cut_barrel_out32 <= cut_barrel_out32;
            ID_regs.cut_alu_out32 <= alu_cut;
            ID_regs.barrel_right <= barrel_right;
            ID_regs.shift_arith <= shift_arith;
            ID_regs.ex_out_src <= ex_out_src;
            ID_regs.barrel_src <= barrel_src;
            ID_regs.MFC0 <= MFC0;
            ID_regs.MTC0 <= MTC0;
            ID_regs.ERET <= ERET;
            ID_regs.syscall <= syscall;
            ID_regs.BEQ <= BEQ;
            ID_regs.BNE <= BNE;
            ID_regs.BC <= BC;
            ID_regs.BAL <= BAL;
            ID_regs.alu_a_src <= alu_a_src;
            ID_regs.alu_b_src <= alu_b_src;
            ID_regs.control_type <= control_type;
            ID_regs.barrel_plus32 <= barrel_plus32;
            ID_regs.A_data <= A_data_forwarded;
            ID_regs.B_data <= B_data_badinst;
            ID_regs.inst <= inst;
            ID_regs.pc4 <= IF_regs.fetch_pc4;
            ID_regs.pc_branch <= BranchAddrFinal;
            ID_regs.jumpAddr <= JumpAddr;
            ID_regs.lui <= lui;
            ID_regs.linkpc <= linkpc;
            ID_regs.signed_mem_out <= signed_mem_out;
            ID_regs.ignore_overflow <= ignore_overflow;
            ID_regs.B_is_reg <= B_is_reg;
            ID_regs.cp0_rd <= inst[15:11];
        end
        // for setting EPC
        ID_regs.pc <= IF_regs.fetch_pc;
    end
endmodule
