import structures::control_type_t;
import structures::mem_load_type_t;
import structures::mem_store_type_t;
import structures::slt_type_t;
import structures::alu_cut_t;
import structures::alu_shifter_as_inp_t;
import structures::A;
import structures::ORIGIN;

module mips_decoder (
    output logic                [ 2:0] alu_op,
    output logic                       writeenable,
    output logic                [ 1:0] rd_src,
    output logic                [ 1:0] alu_src2,
    output logic                       except,
    output control_type_t              control_type,
    output mem_store_type_t            mem_store_type,
    output mem_load_type_t             mem_load_type,
    output slt_type_t                  slt_type,
    output logic                       lui_out,
    output logic                       linkpc,
    output logic                       shift_right,
    output logic                       shift_arith,
    output logic                [ 1:0] shifter_plus32,
    output logic                       ex_out_src,
    output alu_shifter_as_inp_t        alu_shifter_as_inp,
    output logic                       shift_src,
    output logic                       cut_shifter_out32,
    output alu_cut_t                   cut_alu_out32,
    output logic                       MFC0,
    output logic                       MTC0,
    output logic                       ERET,
    output logic                       syscall,
    output logic                       beq,
    output logic                       bne,
    output logic                       bc,
    output logic                       bal,
    output logic                       signed_byte,
    output logic                       signed_word,
    output logic                       ignore_overflow,
    output logic                [ 4:0] rs,
    output logic                [ 4:0] rt,
    output logic                [ 4:0] rd,
    output logic                [ 4:0] shamt,
    output logic                       B_is_reg,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic                [31:0] inst
    /* verilator lint_on UNUSEDSIGNAL */
);
    import mips_define::*;

    // extract
    logic [5:0] opcode, funct;
    logic op0, opr, co, no_shamt;
    logic ehb_inst;
    // add family
    logic daddu_inst, dadd_inst, addu_inst, add_inst, add_family;
    // addi family
    logic daddiu_inst, addiu_inst, daddi_inst, addi_inst, addi_family;
    // sub family
    logic sub_inst, subu_inst, dsub_inst, sub_family;
    // LU ops
    logic or_inst, ori_inst, xor_inst, xori_inst, and_inst, andi_inst, nor_inst, LU_family;
    // slt family
    logic sltu_inst, slt_inst, slti_inst, sltiu_inst, slt_family;
    // sll family
    logic dsll32_inst, dsll_inst, sll_inst, sll_family;
    // srl family
    logic dsrl_inst, dsrl32_inst, srl_inst, srl_family;
    // sra family
    logic dsra_inst, sra_inst, sra_family;
    // jump family
    logic jalr_inst, jr_inst, jal_inst, j_inst, j_family;
    logic bal_inst;
    // branch family
    logic beq_inst, bne_inst, bc_inst, branch_family;
    // LSA
    logic lsa_inst, dlsa_inst, lsa_family;

    logic lui_inst;
    // load family
    logic ld_inst, lw_inst, lwu_inst, lw_family;
    // load byte family
    logic lb_inst, lbu_inst, lb_family;
    // store family
    logic sd_inst, sw_inst, sb_inst, store_family;
    logic nop_inst;
    logic CP0_RES, MFC0_inst, MTC0_inst, ERET_inst, CP0_family;

    always_comb begin
        // --- extracting fields ---
        opcode = inst[31:26];
        funct = inst[5:0];
        op0 = (opcode == OP_OTHER0);
        opr = (opcode == OP_REGIMM);
        co = inst[25];
        // lsa was need to + 1 but seems compiler already did it
        shamt = inst[10:6];
        no_shamt = (inst[10:6] == '0);
        rs = inst[25:21];
        rt = inst[20:16];
        rd = inst[15:11];

        // designed to clear hazard but rn no need
        ehb_inst = (inst == 'b11000000);  // SLL but shamt = 3, other are 0
        nop_inst = (inst == '0) || ehb_inst;

        // --- Instruction decode ---
        daddu_inst = op0 && (funct == OP0_DADDU) && no_shamt;
        dadd_inst = op0 && (funct == OP0_DADD) && no_shamt;
        addu_inst = op0 && (funct == OP0_ADDU) && no_shamt;
        add_inst = op0 && (funct == OP0_ADD) && no_shamt;
        add_family = add_inst || addu_inst || dadd_inst || daddu_inst;

        daddiu_inst = (opcode == OP_DADDIU);
        addiu_inst = (opcode == OP_ADDIU);
        daddi_inst = (opcode == OP_DADDI);
        addi_inst = (opcode == OP_ADDI);
        addi_family = addi_inst || addiu_inst || daddi_inst || daddiu_inst;

        sub_inst = op0 && (funct == OP0_SUB) && no_shamt;
        subu_inst = op0 && (funct == OP0_SUBU) && no_shamt;
        dsub_inst = op0 && (funct == OP0_DSUB) && no_shamt;
        sub_family = sub_inst || subu_inst || dsub_inst;

        or_inst = op0 && (funct == OP0_OR) && no_shamt;
        ori_inst = (opcode == OP_ORI);
        xori_inst = (opcode == OP_XORI);
        xor_inst = op0 && (funct == OP0_XOR) && no_shamt;
        and_inst = op0 && (funct == OP0_AND) && no_shamt;
        andi_inst = (opcode == OP_ANDI);
        nor_inst = op0 && (funct == OP0_NOR);
        LU_family = or_inst || ori_inst || xor_inst || xori_inst || and_inst || andi_inst || nor_inst;

        sltu_inst = op0 && (funct == OP0_SLTU) && no_shamt;
        slt_inst = op0 && (funct == OP0_SLT) && no_shamt;
        slti_inst = (opcode == OP_SLTI);
        sltiu_inst = (opcode == OP_SLTIU);
        slt_family = slt_inst || sltu_inst || slti_inst || sltiu_inst;

        dsll32_inst = op0 && (funct == OP0_DSLL32);
        dsll_inst = op0 && (funct == OP0_DSLL) && (rs == '0);
        // sll $0, $0, 0 is NOP
        // sll $0, $0, 1 is SSNOP
        // so we need to specifically avoid nop
        sll_inst = op0 && (funct == OP0_SLL) && (rs == '0) && (|shamt);
        sll_family = dsll_inst || dsll32_inst || sll_inst;

        dsrl_inst = op0 && (funct == OP0_DSRL) && (rs == '0);
        dsrl32_inst = op0 && (funct == OP0_DSRL32) && (rs == '0);
        srl_inst = op0 && (funct == OP0_SRL) && (rs == '0);
        srl_family = dsrl_inst || dsrl32_inst || srl_inst;

        sra_inst = op0 && (funct == OP0_SRA) && (rs == '0);
        dsra_inst = op0 && (funct == OP0_DSRA) && (rs == '0);
        sra_family = sra_inst || dsra_inst;

        jalr_inst = op0 && (funct == OP0_JALR) && (rt == '0);
        jr_inst = op0 && (funct == OP0_JR) && (rt == '0) && (rd == '0);
        jal_inst = (opcode == OP_JAL);
        j_inst = (opcode == OP_J);
        j_family = j_inst || jr_inst || jal_inst || jalr_inst;

        bal_inst = opr && (rs == '0) && (rt == OPR_BAL);

        lui_inst = (opcode == OP_LUI) && (rs == '0);
        ld_inst = (opcode == OP_LD);

        lw_inst = (opcode == OP_LW);
        lwu_inst = (opcode == OP_LWU);
        lw_family = ld_inst || lwu_inst || lw_inst;

        lb_inst = (opcode == OP_LB);
        lbu_inst = (opcode == OP_LBU);
        lb_family = lbu_inst || lb_inst;

        sd_inst = (opcode == OP_SD);
        sw_inst = (opcode == OP_SW);
        sb_inst = (opcode == OP_SB);
        store_family = sd_inst || sw_inst || sb_inst;

        beq_inst = (opcode == OP_BEQ);
        bne_inst = (opcode == OP_BNE);
        bc_inst = (opcode == OP_BC);
        branch_family = beq_inst || bne_inst || bc_inst;

        // idk why but seems compiler don't clear about sa are 2 bits and it already + 1
        // e.g.  007d1895        dlsa    v1,v1,sp,0x3
        lsa_inst = op0 && (funct == OP0_LSA) && (inst[10:9] == '0);
        dlsa_inst = op0 && (funct == OP0_DLSA) && (inst[10:9] == '0);
        lsa_family = lsa_inst || dlsa_inst;
        // ALU shifter as A input
        alu_shifter_as_inp = lsa_family ? A : ORIGIN;
        // 0 = B data, 1 = A data
        shift_src = lsa_family;

        CP0_RES = inst[10:3] == '0;
        MFC0_inst = (opcode == OP_Z0) && (rs == OPZ_MFCZ) && CP0_RES;
        MTC0_inst = (opcode == OP_Z0) && (rs == OPZ_MTCZ) && CP0_RES;
        ERET_inst = (opcode == OP_Z0) && (co == OP_CO) && (funct == OPC_ERET) && (inst[24:6] == '0);
        syscall = op0 && (funct == OP0_SYSCALL);
        CP0_family = MFC0_inst || MTC0_inst || ERET_inst;

        // --- control signal decoding ---
        // --- stage ID ---
        except = !(add_family || addi_family || sub_family || LU_family || branch_family || j_family || lui_inst || slt_family || lw_family || lb_family || ld_inst || store_family || nop_inst || sll_family || sra_family || srl_family || CP0_family || bal_inst || lsa_family);
        // branch unit resolved in ID stage
        // jump to register
        control_type[1] = (jr_inst || jalr_inst) && !except;
        // jump to imm
        control_type[0] = (j_inst || jal_inst || bal_inst) && !except;

        // --- stage EX ---
        // branch unit resolved in EX stage
        beq = beq_inst && !except;
        bne = bne_inst && !except;
        bc = bc_inst && !except;
        bal = bal_inst && !except;

        signed_byte = lb_inst && !except;
        signed_word = lw_inst && !except;

        alu_op[0] = sub_family || or_inst || xor_inst || ori_inst || xori_inst || branch_family || slt_family;
        alu_op[1] = sub_family || xor_inst || nor_inst || add_family || addi_family || lsa_family || xori_inst || branch_family || bal_inst || slt_family || lw_family || lb_family || ld_inst || store_family;
        // lu switch
        alu_op[2] = LU_family;

        // write into which: 0 = rd, 1 = rt, 2 = 31
        rd_src[0] = (addi_family || andi_inst || ori_inst || xori_inst || lui_inst || lw_family || lb_family || ld_inst || slti_inst || sltiu_inst || MFC0_inst) && !except;
        rd_src[1] = (jal_inst || bal_inst) && !except;

        // 1 = signed immediate
        alu_src2[0] = (addiu_inst || daddiu_inst || sltiu_inst || slti_inst || addi_inst || daddi_inst || lw_family || lb_family || ld_inst || store_family || bal_inst) && !except;
        // 2 = unsigned immediate
        alu_src2[1] = (andi_inst || ori_inst || xori_inst) && !except;
        ignore_overflow = (addu_inst || addiu_inst || subu_inst || daddu_inst || daddiu_inst || sltu_inst || sltiu_inst) && !except;

        lui_out = lui_inst && !except;
        // write back data = pc4
        linkpc = (jal_inst || jalr_inst || bal_inst) && !except;
        slt_type[1:0] = {(sltu_inst || sltiu_inst) && !except, (slt_inst || slti_inst) && !except};
        // 0 = EX_stage out is alu, 1 = EX_stage out is shifter
        ex_out_src = sll_family || srl_family || sra_family;
        shift_right = srl_family || sra_family;
        shift_arith = sra_family;

        // 0 = no cut, 1 = cut with sign extend, 2 = cut with zero extend
        cut_alu_out32[0] = (add_inst || addi_inst || sub_inst || lsa_inst) && !except;
        cut_alu_out32[1] = (addu_inst || addiu_inst || subu_inst) && !except;

        cut_shifter_out32 = (srl_inst || sll_inst) && !except;
        // shifter output regroup: 0 = no change, 1 = move low 32 to high, 2 = move high 32 to low (fill with 0, no sign extend)
        shifter_plus32[0] = op0 && dsll32_inst && !except;
        shifter_plus32[1] = op0 && dsrl32_inst && !except;

        // --- stage MEM ---
        mem_store_type[0] = (sb_inst || sd_inst) && !except;
        mem_store_type[1] = (sw_inst || sd_inst) && !except;
        mem_load_type[0] = (lb_family || ld_inst || MFC0_inst) && !except;
        mem_load_type[1] = (lw_family || ld_inst || MFC0_inst) && !except;
        // cp0
        MFC0 = MFC0_inst && !except;
        MTC0 = MTC0_inst && !except;
        ERET = ERET_inst && !except;

        B_is_reg = ((alu_src2 == 0) || store_family) && !except;

        // --- stage WB ---
        writeenable = (add_family || addi_family || sub_family || LU_family || lui_inst || slt_family || lw_family || lb_family || ld_inst || jal_inst || (jalr_inst && (rd != 0)) || bal_inst || sll_family || srl_family || sra_family || MFC0_inst || lsa_family) && !except;
    end

endmodule  // mips_decode
