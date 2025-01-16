import structures::control_type_t;
import structures::mem_load_type_t;
import structures::mem_store_type_t;
import structures::slt_type_t;
import structures::alu_cut_t;

module mips_decoder (
    output logic            [ 2:0] alu_op,
    output logic                   writeenable,
    output logic                   rd_src,
    output logic            [ 1:0] alu_src2,
    output logic                   except,
    output control_type_t          control_type,
    output mem_store_type_t        mem_store_type,
    output mem_load_type_t         mem_load_type,
    output slt_type_t              slt_type,
    output logic                   lui_out,
    output logic                   shift_right,
    output logic            [ 1:0] shifter_plus32,
    output logic                   alu_shifter_src,
    output logic                   cut_shifter_out32,
    output alu_cut_t               cut_alu_out32,
    output logic                   MFC0,
    output logic                   MTC0,
    output logic                   ERET,
    output logic                   beq,
    output logic                   bne,
    output logic                   bc,
    output logic                   signed_byte,
    output logic                   signed_word,
    output logic                   ignore_overflow,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic            [31:0] inst
    /* verilator lint_on UNUSEDSIGNAL */
);
    import mips_define::*;

    wire [5:0] opcode = inst[31:26], funct = inst[5:0];
    wire [4:0] rs = inst[25:21];
    wire op0 = (opcode == OP_OTHER0), co = inst[25];

    // the family means these instruction share same datapath in most stages
    // but only differ in rare places

    // add family
    wire daddu_inst = op0 & (funct == OP0_DADDU);
    wire dadd_inst = op0 & (funct == OP0_DADD);
    wire addu_inst = op0 & (funct == OP0_ADDU);
    wire add_inst = op0 & (funct == OP0_ADD);
    wire add_family = add_inst | addu_inst | dadd_inst | daddu_inst;
    // addi family
    wire daddiu_inst = (opcode == OP_DADDIU);
    wire addiu_inst = (opcode == OP_ADDIU);
    wire daddi_inst = (opcode == OP_DADDI);
    wire addi_inst = (opcode == OP_ADDI);
    wire addi_family = addi_inst | addiu_inst | daddi_inst | daddiu_inst;
    // sub family
    wire sub_inst = op0 & (funct == OP0_SUB);
    wire subu_inst = op0 & (funct == OP0_SUBU);
    wire dsub_inst = op0 & (funct == OP0_DSUB);
    wire sub_family = sub_inst | subu_inst | dsub_inst;
    // LU operations
    wire or_inst = op0 & (funct == OP0_OR);
    wire ori_inst = (opcode == OP_ORI);
    wire xori_inst = (opcode == OP_XORI);
    wire xor_inst = op0 & (funct == OP0_XOR);
    wire and_inst = op0 & (funct == OP0_AND);
    wire nor_inst = op0 & (funct == OP0_NOR);
    // slt family
    wire sltu_inst = op0 & (funct == OP0_SLTU);
    wire slt_inst = op0 & (funct == OP0_SLT);
    wire slti_inst = (opcode == OP_SLTI);
    wire sltiu_inst = (opcode == OP_SLTIU);
    wire slt_family = slt_inst | sltu_inst | slti_inst | sltiu_inst;
    // sll family
    wire dsll32_inst = op0 & (funct == OP0_DSLL32);
    wire dsll_inst = op0 & (funct == OP0_DSLL);
    wire sll_inst = op0 & (funct == OP0_SLL);
    wire sll_family = dsll_inst | dsll32_inst | sll_inst;
    // srl family
    wire dsrl_inst = op0 & (funct == OP0_DSRL);
    wire dsrl32_inst = op0 & (funct == OP0_DSRL32);
    wire srl_inst = op0 & (funct == OP0_SRL);
    wire srl_family = dsrl_inst | dsrl32_inst | srl_inst;

    wire jr_inst = op0 & (funct == OP0_JR);
    wire j_inst = (opcode == OP_J);
    wire lui_inst = (opcode == OP_LUI);
    wire ld_inst = (opcode == OP_LD);

    // lw family
    wire lw_inst = (opcode == OP_LW);
    wire lwu_inst = (opcode == OP_LWU);
    wire lw_family = ld_inst | lwu_inst | lw_inst;
    // lb family
    wire lb_inst = (opcode == OP_LB);
    wire lbu_inst = (opcode == OP_LBU);
    wire lb_family = lbu_inst | lb_inst;

    wire sd_inst = (opcode == OP_SD);
    wire sw_inst = (opcode == OP_SW);
    wire sb_inst = (opcode == OP_SB);
    wire store_family = sd_inst | sw_inst | sb_inst;

    wire nop_inst = (opcode == 6'h00 && funct == 6'h00);

    // branch family
    wire beq_inst = (opcode == OP_BEQ);
    wire bne_inst = (opcode == OP_BNE);
    wire bc_inst = (opcode == OP_BC);
    wire branch_family = beq_inst | bne_inst | bc_inst;

    // CP0
    wire MFC0_inst = opcode == OP_Z0 && rs == OPZ_MFCZ;
    wire MTC0_inst = opcode == OP_Z0 && rs == OPZ_MTCZ;
    wire ERET_inst = opcode == OP_Z0 && co == OP_CO && funct == OPC_ERET;

    always_comb begin
        // --- stage ID ---
        except = ~(add_family | addi_family | sub_family | and_inst | or_inst | xor_inst | nor_inst  | ori_inst | xori_inst | branch_family | j_inst | jr_inst | lui_inst | slt_family| lw_family | lb_family | ld_inst | store_family | nop_inst | sll_family | srl_family);
        // branch unit resolved in ID stage
        control_type[1] = jr_inst & ~except;
        control_type[0] = j_inst & ~except;

        // --- stage EX ---
        // branch unit resolved in EX stage
        beq = beq_inst & ~except;
        bne = bne_inst & ~except;
        bc = bc_inst & ~except;

        signed_byte = lb_inst & ~except;
        signed_word = lw_inst & ~except;

        alu_op[0] = sub_family | or_inst | xor_inst | ori_inst | xori_inst | branch_family | slt_inst;
        alu_op[1] = sub_family | xor_inst | nor_inst | add_family | addi_family | xori_inst | branch_family | slt_family | lw_family | lb_family | ld_inst | store_family;
        // lu switch
        alu_op[2] = and_inst | or_inst | xor_inst | nor_inst | ori_inst | xori_inst;

        rd_src = (addi_family | ori_inst | xori_inst | lui_inst | lw_family | lb_family | ld_inst) & ~MFC0_inst & ~except;

        // signed immediate
        alu_src2[0] = (addiu_inst | daddiu_inst | sltiu_inst | addi_inst | daddi_inst | slti_inst | lw_family | lb_family | ld_inst | store_family) & ~except;
        // unsigned immediate
        alu_src2[1] = (and_inst | ori_inst | xori_inst) & ~except;
        ignore_overflow = (addu_inst | addiu_inst | subu_inst | daddu_inst | daddiu_inst | sltu_inst | sltiu_inst) & ~except;

        lui_out = lui_inst & ~except;
        slt_type[1:0] = {sltu_inst & ~except, slt_inst & ~except};
        alu_shifter_src = sll_inst | srl_inst;
        shift_right = srl_inst;

        cut_alu_out32[0] = (add_inst | addi_inst | sub_inst) & ~except;
        cut_alu_out32[1] = (addu_inst | addiu_inst | subu_inst) & ~except;

        cut_shifter_out32 = ~(dsrl32_inst | dsrl_inst | dsll32_inst | dsll_inst) & ~except;
        shifter_plus32[0] = op0 & dsll32_inst & ~except;
        shifter_plus32[1] = op0 & dsrl32_inst & ~except;

        // --- stage MEM ---
        mem_store_type[0] = (sb_inst | sd_inst) & ~except;
        mem_store_type[1] = (sw_inst | sd_inst) & ~except;
        mem_load_type[0] = (lb_family | ld_inst) & ~except;
        mem_load_type[1] = (lw_family | ld_inst) & ~except;
        // cp0
        MFC0 = MFC0_inst & ~except;
        MTC0 = MTC0_inst & ~except;
        ERET = ERET_inst & ~except;

        // --- stage WB ---
        writeenable = (add_family | addi_family | sub_family | and_inst | or_inst | xor_inst | nor_inst  | ori_inst | xori_inst | lui_inst | slt_family | lw_family | lb_family | ld_inst) & ~MTC0_inst & ~ERET_inst & ~beq_inst & ~except;
    end

endmodule  // mips_decode
