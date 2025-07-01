//////
////// MIPS Defines: Numerical parameters of the MIPS processor
//////

package mips_define;
    ////
    //// OPCODES
    ////

    // Main opcodes (op field)
    localparam OP_OTHER0 = 6'h00;
    localparam OP_REGIMM = 6'h01;
    localparam OP_J = 6'h02;
    localparam OP_JAL = 6'h03;
    localparam OP_BEQ = 6'h04;
    localparam OP_BNE = 6'h05;
    localparam OP_ADDI = 6'h08;
    localparam OP_ADDIU = 6'h09;
    localparam OP_SLTI = 6'h0a;
    localparam OP_SLTIU = 6'h0b;
    localparam OP_ORI = 6'h0d;
    localparam OP_XORI = 6'h0e;
    localparam OP_LUI = 6'h0f;
    localparam OP_Z0 = 6'h10;
    localparam OP_DADDI = 6'h18;
    localparam OP_DADDIU = 6'h19;
    localparam OP_LB = 6'h20;
    localparam OP_LW = 6'h23;
    localparam OP_LBU = 6'h24;
    localparam OP_LWU = 6'h27;
    localparam OP_SB = 6'h28;
    localparam OP_SW = 6'h2b;
    localparam OP_BC = 6'h32;
    localparam OP_LD = 6'h37;
    localparam OP_SD = 6'h3f;

    // Secondary opcodes (funct2 field; OP_OTHER0)
    localparam OP0_SLL = 6'h00;
    localparam OP0_SRL = 6'h02;
    // deprecated in mips64r6, equivalent to JALR (w/ rd=0)
    localparam OP0_JR = 6'h08;
    localparam OP0_JALR = 6'h09;
    localparam OP0_ADD = 6'h20;
    localparam OP0_ADDU = 6'h21;
    localparam OP0_SUB = 6'h22;
    localparam OP0_SUBU = 6'h23;
    localparam OP0_AND = 6'h24;
    localparam OP0_OR = 6'h25;
    localparam OP0_XOR = 6'h26;
    localparam OP0_NOR = 6'h27;
    localparam OP0_SLT = 6'h2a;
    localparam OP0_SLTU = 6'h2b;
    localparam OP0_DADDU = 6'h2d;
    localparam OP0_DSUB = 6'h2e;
    localparam OP0_DADD = 6'h2c;
    localparam OP0_DSLL = 6'h38;
    localparam OP0_DSRL = 6'h3a;
    localparam OP0_DSLL32 = 6'h3c;
    localparam OP0_DSRL32 = 6'h3e;
    localparam OP0_SYSCALL = 6'h0c;

    // Secondary opcodes (rs field; OP_Z[0-3])
    localparam OPZ_MFCZ = 5'h00;
    localparam OPZ_MTCZ = 5'h04;

    // 16-20
    localparam OPR_BAL = 5'h11;

    // ERET stuff
    localparam OP_CO = 1'b1;
    localparam OPC_ERET = 6'h18;
endpackage
