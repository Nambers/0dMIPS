import structures::forward_type_t;
import structures::NO_FORWARD;
import structures::FORWARD_ALU;
import structures::FORWARD_MEM;

module core_forward (
    input logic [4:0] IF_rs,
    input logic [4:0] IF_rt,
    input logic [4:0] ID_rd,
    input logic ID_alu_writeback,
    input logic [4:0] EX_rd,
    input logic EX_mem_writeback,
    output forward_type_t forward_A,
    output forward_type_t forward_B
);

    always_comb begin
        forward_A = NO_FORWARD;
        forward_B = NO_FORWARD;

        if (EX_mem_writeback && EX_rd != 0) begin
            if (EX_rd == IF_rs) forward_A = FORWARD_MEM;
            if (EX_rd == IF_rt) forward_B = FORWARD_MEM;
        end
        if (ID_alu_writeback && ID_rd != 0) begin
            if (ID_rd == IF_rs) forward_A = FORWARD_ALU;
            if (ID_rd == IF_rt) forward_B = FORWARD_ALU;
        end
    end
endmodule
