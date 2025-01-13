package structures;
    typedef enum [1:0] {
        NORMAL = 0,
        J = 1,
        JR = 2
    } control_type_t;

    typedef enum [1:0] {
        NO_FORWARD  = 0,
        FORWARD_ALU = 1,
        FORWARD_MEM  = 2
    } forward_type_t;

    typedef struct packed {
        logic [31:0] inst;
        logic [63:0] pc4, pc;
    } IF_regs_t;

    typedef struct packed {
        logic [63:0] A_data, B_data, pc4, pc_branch, jumpAddr;
        logic [31:0] inst;
        logic [4:0] W_regnum;
        logic [2:0] alu_op;
        logic [1:0] alu_src2, shifter_plus32;
        control_type_t control_type;
        forward_type_t forward_A, forward_B;
        logic reserved_inst_E,
            write_enable,
            mem_read,
            word_we,
            byte_we,
            byte_load,
            slt,
            cut_shifter_out32,
            cut_alu_out32,
            shift_right,
            alu_shifter_src,
            BEQ,
            BNE,
            lui,
            signed_byte,
            // -- CP0 --
            MFC0,
            MTC0,
            ERET
        ;
    } ID_regs_t;

    typedef struct packed {
        logic [63:0] out, slt_out, B_data, pc4, pc_branch;
        logic [4:0] W_regnum;
        logic [2:0] sel;
        logic reserved_inst_E, 
        overflow, zero, mem_read, 
        word_we, byte_we, byte_load, MFC0, MTC0, ERET, write_enable, BEQ, BNE, signed_byte;
    } EX_regs_t;

    typedef struct packed {
        logic [63:0] EPC, W_data;
        logic [4:0] W_regnum;
        logic write_enable, takenHandler, mem_read;
    } MEM_regs_t;
endpackage
