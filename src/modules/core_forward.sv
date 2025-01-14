import structures::forward_type_t;
import structures::NO_FORWARD;
import structures::FORWARD_ALU;
import structures::FORWARD_MEM;

module core_forward (
    input logic [4:0] ID_rs,
    input logic [4:0] ID_rt,
    input logic [4:0] EX_rd,
    input logic EX_alu_writeback,
    input logic [4:0] MEM_rd,
    input logic MEM_mem_writeback,
    output forward_type_t forward_A,
    output forward_type_t forward_B
);

    always_comb begin
        forward_A = NO_FORWARD;
        forward_B = NO_FORWARD;

        if (MEM_mem_writeback && MEM_rd != 0) begin
            if (MEM_rd == ID_rs) forward_A = FORWARD_MEM;
            if (MEM_rd == ID_rt) forward_B = FORWARD_MEM;
        end
        if (EX_alu_writeback && EX_rd != 0) begin
            if (EX_rd == ID_rs) forward_A = FORWARD_ALU;
            if (EX_rd == ID_rt) forward_B = FORWARD_ALU;
        end
    end
endmodule
