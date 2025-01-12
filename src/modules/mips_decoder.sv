// mips_decode: a decoder for MIPS arithmetic instructions
//
// alu_op       (output) - control signal to be sent to the ALU
// writeenable  (output) - should a new value be captured by the register file
// rd_src       (output) - should the destination register be rd (0) or rt (1)
// alu_src2     (output) - should the 2nd ALU source be a register (0) or an immediate (1)
// except       (output) - set to 1 when we don't recognize an opdcode & funct combination
// control_type (output) - 00 = fallthrough, 01 = branch_target, 10 = jump_target, 11 = jump_register 
// mem_read     (output) - the register value written is coming from the memory
// word_we      (output) - we're writing a word's worth of data
// byte_we      (output) - we're only writing a byte's worth of data
// byte_load    (output) - we're doing a byte load
// slt          (output) - the instruction is an slt
// lui          (output) - the instruction is a lui
// shift_right  (output) - the instruction is a right shift
// shifter_plus32(output) - the shifter output should be added to 32
// alu_shifter_src (output) - the shifter source is the ALU output
// cut_shifter_out32(output) - the shifter output should be cut to 32 bits
// cut_alu_out32(output) - the ALU output should be cut to 32 bits then sign extended
// opcode        (input) - the opcode field from the instruction
// funct         (input) - the function field from the instruction
// zero          (input) - from the ALU
//
// for definitions of the opcodes and functs, see mips_define.v
`include "src/modules/mips_define.sv"
import structures::control_type_t;

module mips_decoder (
    output logic          [ 2:0] alu_op,
    output logic                 writeenable,
    output logic                 rd_src,
    output logic          [ 1:0] alu_src2,
    output logic                 except,
    output control_type_t        control_type,
    output logic                 mem_read,
    output logic                 word_we,
    output logic                 byte_we,
    output logic                 byte_load,
    output logic                 slt_out,
    output logic                 lui_out,
    output logic                 shift_right,
    output logic          [ 1:0] shifter_plus32,
    output logic                 alu_shifter_src,
    output logic                 cut_shifter_out32,
    output logic                 cut_alu_out32,
    output logic                 MFC0,
    output logic                 MTC0,
    output logic                 ERET,
    output logic                 beq,
    output logic                 bne,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic          [31:0] inst
    /* verilator lint_on UNUSEDSIGNAL */
);

    logic op0, addu_inst, add_inst, sub_inst, and_inst, or_inst, xor_inst, nor_inst;
    logic addi_inst, addiu_inst, andi_inst, ori_inst, xori_inst;
    wire [5:0] opcode = inst[31:26];
    wire [5:0] funct = inst[5:0];

    assign op0 = (opcode == `OP_OTHER0);
    assign addu_inst = op0 & (funct == `OP0_ADDU | funct == `OP0_64_DADDU);
    assign add_inst = op0 & (funct == `OP0_ADD);
    assign sub_inst = op0 & (funct == `OP0_SUB);
    assign and_inst = op0 & (funct == `OP0_AND);
    assign or_inst = op0 & (funct == `OP0_OR);
    assign xor_inst = op0 & (funct == `OP0_XOR);
    assign nor_inst = op0 & (funct == `OP0_NOR);
    wire jr = op0 & (funct == `OP0_JR);
    wire slt = op0 & (funct == `OP0_SLT);
    wire sll = op0 & (funct == `OP0_SLL | funct == `OP0_64_DSLL | funct == `OP0_64_DSLL32);
    wire srl = op0 & (funct == `OP0_SRL | funct == `OP0_64_DSRL | funct == `OP0_64_DSRL32);


    assign addi_inst = (opcode == `OP_ADDI);
    assign addiu_inst = (opcode == `OP_ADDIU) | (opcode == `OP_64_DADDIU);
    assign andi_inst = (opcode == `OP_ANDI);
    assign ori_inst = (opcode == `OP_ORI);
    assign xori_inst = (opcode == `OP_XORI);
    assign beq = (opcode == `OP_BEQ);
    assign bne = (opcode == `OP_BNE);
    wire j = (opcode == `OP_J);
    wire lui = (opcode == `OP_LUI);
    wire lw = (opcode == `OP_LW);
    wire lbu = (opcode == `OP_LBU);
    wire sw = (opcode == `OP_SW);
    wire sb = (opcode == `OP_SB);
    wire nop = (opcode == 6'h00 && funct == 6'h00);

    assign alu_op[0] = sub_inst | or_inst | xor_inst | ori_inst | xori_inst | beq | bne | slt;
    assign alu_op[1] = add_inst | sub_inst | xor_inst | nor_inst | addi_inst | xori_inst | beq | bne | slt | lw | lbu | sw | sb;
    assign alu_op[2] = and_inst | or_inst | xor_inst | nor_inst | andi_inst | ori_inst | xori_inst;

    assign except = ~(add_inst | addu_inst | sub_inst | and_inst | or_inst | xor_inst | nor_inst | addi_inst | addiu_inst | andi_inst | ori_inst | xori_inst | beq | bne | j | jr | lui | slt | lw | lbu | sw | sb | nop | sll | srl);
    assign rd_src = (addi_inst | addiu_inst | andi_inst | ori_inst | xori_inst | lui | lw | lbu) & ~MFC0 & ~except;

    assign alu_src2[0] = (addi_inst | addiu_inst | lw | lbu | sw | sb) & ~except;
    assign alu_src2[1] = (andi_inst | ori_inst | xori_inst) & ~except;

    assign writeenable = (add_inst | addu_inst | sub_inst | and_inst | or_inst | xor_inst | nor_inst | addi_inst | addiu_inst | andi_inst | ori_inst | xori_inst | lui | slt | lw | lbu) & ~MTC0 & ~ERET & ~beq & ~except;
    assign control_type[1] = jr & ~except;
    assign control_type[0] = j & ~except;
    assign mem_read = (lw | lbu) & ~except;
    assign word_we = sw & ~except;
    assign byte_we = sb & ~except;
    assign byte_load = lbu & ~except;
    assign lui_out = lui & ~except;
    assign slt_out = slt & ~except;
    assign alu_shifter_src = sll | srl;
    assign shift_right = srl;

    assign cut_alu_out32 = ~(opcode == `OP_64_DADDIU | (op0 & funct == `OP0_64_DADDU)) & ~except;
    assign cut_shifter_out32 = ~(op0 & (funct == `OP0_64_DSRL | funct == `OP0_64_DSLL | funct == `OP0_64_DSRL32)) & ~except;
    assign shifter_plus32[0] = op0 & (funct == `OP0_64_DSLL32) & ~except;
    assign shifter_plus32[1] = op0 & (funct == `OP0_64_DSRL32) & ~except;

    wire [4:0] rs = inst[25:21];
    wire co = inst[25];
    assign MFC0 = opcode == `OP_Z0 && rs == `OPZ_MFCZ;
    assign MTC0 = opcode == `OP_Z0 && rs == `OPZ_MTCZ;
    assign ERET = opcode == `OP_Z0 && co == `OP_CO && funct == `OPC_ERET;
endmodule  // mips_decode
