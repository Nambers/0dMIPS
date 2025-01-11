import structures::MEM_regs_t;
import structures::WB_regs_t;

module core_WB (
    input logic clock,
    input logic reset,
    input [4:0] MEM_regs_W_regnum,
    input [63:0] MEM_regs_W_data,
    input MEM_regs_write_enable,
    output WB_regs_t WB_regs
);
    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            WB_regs <= '0;
        end else begin
            WB_regs.W_regnum <= MEM_regs_W_regnum;
            WB_regs.W_data <= MEM_regs_W_data;
            WB_regs.write_enable <= MEM_regs_write_enable;
        end
    end
endmodule
