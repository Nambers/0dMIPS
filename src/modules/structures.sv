package structures;
    typedef enum bit [1:0] {
        NORMAL = 0,
        J,
        JR
    } control_type_t;

    typedef enum bit [1:0] {
        NO_FORWARD  = 0,
        FORWARD_ALU,
        FORWARD_MEM
    } forward_type_t;

    typedef enum bit [1:0] {
        NO_LOAD = 0,
        LOAD_BYTE,
        LOAD_WORD,
        LOAD_DWORD
    } mem_load_type_t;

    typedef enum bit [1:0] {
        NO_STORE = 0,
        STORE_BYTE,
        STORE_WORD,
        STORE_DWORD
    } mem_store_type_t;

    typedef enum bit [1:0] {
        NO_SLT = 0,
        SLT,
        SLTU
    } slt_type_t;

    typedef enum bit [1:0] {
        NO_CUT = 0,
        SIGNED_CUT,
        UNSIGNED_CUT
    } alu_cut_t;

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
        mem_load_type_t mem_load_type;
        mem_store_type_t mem_store_type;
        slt_type_t slt_type;
        alu_cut_t cut_alu_out32;
        logic reserved_inst_E,
            write_enable,
            cut_shifter_out32,
            shift_right,
            alu_shifter_src,
            BEQ,
            BNE,
            BC,
            lui,
            signed_byte,
            signed_word,
            ignore_overflow,
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
        mem_load_type_t mem_load_type;
        mem_store_type_t mem_store_type;
        logic reserved_inst_E,
            overflow,
            zero,
            MFC0,
            MTC0,
            ERET,
            write_enable,
            BEQ,
            BNE,
            BC,
            signed_byte,
            signed_word
        ;
    } EX_regs_t;

    typedef struct packed {
        logic [63:0] EPC, W_data;
        logic [4:0] W_regnum;
        logic write_enable, takenHandler;
    } MEM_regs_t;
endpackage
