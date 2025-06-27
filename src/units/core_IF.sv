import structures::IF_regs_t;

module core_IF #(
    parameter RESET_PC = 64'h100
) (
    input logic clock,
    input logic reset,
    input logic [63:0] next_pc,
    input logic [31:0] inst,
    input logic stall,
    input logic flush,

    output logic [63:0] pc,
    output IF_regs_t IF_regs
);
    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            pc <= RESET_PC;
            IF_regs.pc <= RESET_PC;
            IF_regs.pc4 <= RESET_PC + 'd4;
            IF_regs.inst <= 'd0;
        end else if (!stall || flush) begin
            if (flush) begin
                // when flush, keep pc
                IF_regs.inst <= 'd0;
            end else begin
                IF_regs.inst <= inst;
            end
            pc <= next_pc;
            IF_regs.pc <= next_pc;
            IF_regs.pc4 <= next_pc + 'd4;
        end
    end
endmodule
