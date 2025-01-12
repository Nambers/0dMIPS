import structures::IF_regs_t;
import structures::ID_regs_t;
import structures::MEM_regs_t;
import structures::control_type_t;
import structures::forward_type_t;

module core_ID (
    input logic clock,
    input logic reset,
    input IF_regs_t IF_regs,
    input logic stall,
    input logic flush,
    /* verilator lint_off UNUSEDSIGNAL */
    input MEM_regs_t MEM_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    output ID_regs_t ID_regs,

    // -- forward --
    input forward_type_t forward_A,
    input forward_type_t forward_B
);
    logic [63:0] A_data, B_data;
    logic [4:0] W_regnum;
    logic [2:0] alu_op;
    logic [1:0] alu_src2, shifter_plus32;
    control_type_t control_type;
    logic
        reserved_inst_E,
        write_enable,
        rd_src,
        mem_read,
        word_we,
        byte_we,
        byte_load,
        slt,
        lui,
        cut_shifter_out32,
        cut_alu_out32,
        shift_right,
        alu_shifter_src,
        MFC0,
        MTC0,
        ERET,
        BEQ,
        BNE;

    // -- decoder --
    mips_decoder decoder (
        alu_op,
        write_enable,
        rd_src,
        alu_src2,
        reserved_inst_E,
        control_type,
        mem_read,
        word_we,
        byte_we,
        byte_load,
        slt,
        lui,
        shift_right,
        shifter_plus32,
        alu_shifter_src,
        cut_shifter_out32,
        cut_alu_out32,
        MFC0,
        MTC0,
        ERET,
        BEQ,
        BNE,
        IF_regs.inst
    );

    // -- reg --
    regfile #(64) rf (
        A_data,
        B_data,
        IF_regs.inst[25:21],
        IF_regs.inst[20:16],
        MEM_regs.W_regnum,
        MEM_regs.W_data,
        MEM_regs.write_enable,
        clock,
        reset
    );


    mux2v #(5) rd_mux (
        W_regnum,
        IF_regs.inst[15:11],
        IF_regs.inst[20:16],
        rd_src
    );

    wire [63:0] BranchAddr = {{46{IF_regs.inst[15]}}, IF_regs.inst[15:0], 2'b0};
    wire [63:0] JumpAddr = {{32{1'b0}}, IF_regs.pc4[63:60], IF_regs.inst[25:0], 2'b0};

    always_ff @(posedge clock, posedge reset) begin
        // $display("writeback regnum = %d, data = %h, enable = %h", MEM_regs.W_regnum,
        //          MEM_regs.W_data, MEM_regs.write_enable);
        if (reset || flush || stall) begin
            ID_regs <= '0;
        end else begin
            ID_regs.W_regnum <= W_regnum;
            ID_regs.reserved_inst_E <= reserved_inst_E;
            ID_regs.alu_op <= alu_op;
            ID_regs.write_enable <= write_enable;
            ID_regs.mem_read <= mem_read;
            ID_regs.word_we <= word_we;
            ID_regs.byte_we <= byte_we;
            ID_regs.byte_load <= byte_load;
            ID_regs.slt <= slt;
            ID_regs.cut_shifter_out32 <= cut_shifter_out32;
            ID_regs.cut_alu_out32 <= cut_alu_out32;
            ID_regs.shift_right <= shift_right;
            ID_regs.alu_shifter_src <= alu_shifter_src;
            ID_regs.MFC0 <= MFC0;
            ID_regs.MTC0 <= MTC0;
            ID_regs.ERET <= ERET;
            ID_regs.BEQ <= BEQ;
            ID_regs.BNE <= BNE;
            ID_regs.alu_src2 <= alu_src2;
            ID_regs.control_type <= control_type;
            ID_regs.shifter_plus32 <= shifter_plus32;
            ID_regs.A_data <= A_data;
            ID_regs.B_data <= B_data;
            ID_regs.inst <= IF_regs.inst;
            ID_regs.pc4 <= IF_regs.pc4;
            ID_regs.pc_branch <= IF_regs.pc + BranchAddr;
            ID_regs.jumpAddr <= JumpAddr;
            ID_regs.forward_A <= forward_A;
            ID_regs.forward_B <= forward_B;
            ID_regs.lui <= lui;
        end
    end
endmodule
