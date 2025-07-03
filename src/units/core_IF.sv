import structures::IF_regs_t;

module core_IF #(
    parameter RESET_PC = 64'h100
) (
    input logic clock,
    input logic reset,
    input logic [63:0] next_fetch_pc,
    input logic stall,
    input logic flush,

    output IF_regs_t IF_regs
);
    logic [63:0] next_pc;
    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            IF_regs.fetch_pc <= RESET_PC;
            IF_regs.fetch_pc4 <= RESET_PC + 'd4;
        end else if (!stall || flush) begin
            IF_regs.fetch_pc <= next_fetch_pc;
            IF_regs.fetch_pc4 <= next_fetch_pc + 'd4;
        end
    end
endmodule
