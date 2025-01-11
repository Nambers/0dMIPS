import structures::forward_type_t;
import structures::NO_FORWARD;
import structures::FORWARD_MEM;
import structures::FORWARD_WB;

module core_forward (
    input logic [4:0] ID_rs,
    input logic [4:0] ID_rt,
    input logic [4:0] MEM_rd,
    input logic MEM_reg_write,
    input logic [4:0] WB_rd,
    input logic WB_reg_write,
    output forward_type_t forward_A,
    output forward_type_t forward_B
);

    always_comb begin
        forward_A = NO_FORWARD;
        forward_B = NO_FORWARD;

        if (MEM_reg_write && MEM_rd != 0) begin
            if (MEM_rd == ID_rs) forward_A = FORWARD_MEM;
            if (MEM_rd == ID_rt) forward_B = FORWARD_MEM;
        end
        if (WB_reg_write && WB_rd != 0) begin
            if (WB_rd == ID_rs) forward_A = FORWARD_WB;
            if (WB_rd == ID_rt) forward_B = FORWARD_WB;
        end
    end
endmodule
