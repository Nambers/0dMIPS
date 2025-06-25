import structures::forward_type_t;
import structures::NO_FORWARD;
import structures::FORWARD_ALU;
import structures::FORWARD_MEM;

module core_forward (
    input  logic          [4:0] IF_rs,
    input  logic          [4:0] IF_rt,
    input  logic          [4:0] ID_rs,
    input  logic          [4:0] ID_rt,
    input  logic          [4:0] EX_rd,
    input  logic                EX_alu_writeback,
    input  logic          [4:0] MEM_rd,
    input  logic                MEM_mem_writeback,
    input  logic                ID_B_is_reg,
    output forward_type_t       forward_A,
    output forward_type_t       forward_B,
    output forward_type_t       forward_A_ID,
    output forward_type_t       forward_B_ID
);

    always_comb begin
        forward_A = NO_FORWARD;
        forward_B = NO_FORWARD;
        forward_A_ID = NO_FORWARD;
        forward_B_ID = NO_FORWARD;

        if (MEM_mem_writeback && MEM_rd != 0) begin
            if (MEM_rd == ID_rs) forward_A = FORWARD_MEM;
            if ((MEM_rd == ID_rt) & ID_B_is_reg) forward_B = FORWARD_MEM;
            if (MEM_rd == IF_rs) forward_A_ID = FORWARD_MEM;
            if (MEM_rd == IF_rt) forward_B_ID = FORWARD_MEM;
        end
        if (EX_alu_writeback && EX_rd != 0) begin
            if (EX_rd == ID_rs) forward_A = FORWARD_ALU;
            if ((EX_rd == ID_rt) & ID_B_is_reg) forward_B = FORWARD_ALU;
            if (EX_rd == IF_rt) forward_B_ID = FORWARD_ALU;
            if (EX_rd == IF_rs) forward_A_ID = FORWARD_ALU;
        end
    end
endmodule
