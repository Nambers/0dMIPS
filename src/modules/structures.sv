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

    typedef enum bit [2:0] {
        NO_LOAD = 0,
        LOAD_BYTE,
        LOAD_HALF,
        LOAD_WORD,
        LOAD_DWORD
    } mem_load_type_t;

    typedef enum bit [2:0] {
        NO_STORE = 0,
        STORE_BYTE,
        STORE_HALF,
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

    typedef enum bit [1:0] {
        ORIGIN,
        A,
        B
    } alu_shifter_as_inp_t;

    typedef enum bit [1:0] {
        A_DATA = 0,
        A_SHIFTER,
        A_PC
    } alu_a_src_t;

    typedef enum bit [1:0] {
        B_DATA = 0,
        B_SHIFTER,
        SIGN_IMM,
        ZERO_IMM
    } alu_b_src_t;

    typedef enum bit [1:0] {
        ALU_OUT = 0,
        SHIFTER_OUT,
        PC_BRANCH
    } EX_out_src_t;

    typedef enum bit [1:0] {
        BRANCH,
        COMPACT_BRANCH,
        PC_RELATIVE
    } BranchAddr_src_t;

    typedef enum bit [1:0] {
        NO_EXT   = 0,
        EXT_BYTE,
        EXT_HALF
    } ext_src_t;

    typedef enum bit [1:0] {
        SHIFTER = 0,
        ROTATOR,
        SIGN_SHIFTER32,
        SIGN_ROTATOR32
    } cut_barrel_out32_t;

    typedef struct packed {logic [63:0] fetch_pc4, fetch_pc;} IF_regs_t;

    typedef struct packed {
        logic [63:0] A_data, B_data, pc4, pc_branch, jumpAddr;
        logic [4:0] W_regnum, cp0_rd, shamt;
        logic [2:0] alu_op, sel;
        logic [1:0] barrel_plus32;
        control_type_t control_type;
        mem_load_type_t mem_load_type;
        mem_store_type_t mem_store_type;
        slt_type_t slt_type;
        ext_src_t ext_src;
        alu_cut_t cut_alu_out32;
        alu_a_src_t alu_a_src;
        alu_b_src_t alu_b_src;
        EX_out_src_t ex_out_src;
        cut_barrel_out32_t cut_barrel_out32;
        logic reserved_inst_E,
            write_enable,
            barrel_right,
            shift_arith,
            rotator_src,
            barrel_src,
            barrel_sa_src,
            BEQ,
            BNE,
            BC,
            BAL,
            lui,
            linkpc,
            B_is_reg,
            signed_mem_out,
            ignore_overflow,
            // -- CP0 --
            MFC0,
            MTC0,
            ERET,
            break_,
            syscall
        ;
        logic [31:0] inst;
        // for store EPC and debugger
        logic [63:0] pc;
    } ID_regs_t;

    typedef struct packed {
        logic [63:0] out, B_data, pc4, pc_branch;
        logic [4:0] W_regnum, cp0_rd;
        logic [2:0] sel;
        mem_load_type_t mem_load_type;
        mem_store_type_t mem_store_type;
        logic overflow,
            zero,
            MFC0,
            MTC0,
            break_,
            syscall,
            write_enable,
            BEQ,
            BNE,
            BC,
            BAL,
            signed_mem_out,
            lui,
            linkpc
        ;
`ifdef DEBUGGER
        logic [31:0] inst;
        logic [63:0] pc;
`endif
    } EX_regs_t;

    typedef struct packed {
        logic [63:0] EPC, W_data;
        logic [4:0] W_regnum;
        logic write_enable,
            takenHandler
        ;  // ofs being used, if change, also change coreTest
`ifdef DEBUGGER
        logic [31:0] inst;
        logic [63:0] pc;
`endif
    } MEM_regs_t;

    typedef struct packed {
        logic [64-6-1:0] mem_addr;
        logic [64*8-1:0] mem_data_out;
        logic mem_req_load, mem_req_store;
    } mem_bus_req_t;

    typedef struct packed {
        logic [64*8-1:0] mem_data;
        logic mem_ready;
    } mem_bus_resp_t;
endpackage
