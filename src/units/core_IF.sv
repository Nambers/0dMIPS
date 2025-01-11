import structures::IF_regs_t;

module core_IF (
    input logic clock,
    input logic reset,
    input logic [63:0] pc_next,
    input logic [31:0] inst,
    input logic stall,
    input logic flush,

    output logic [63:0] pc,
    output IF_regs_t IF_regs
);
    always_ff @(posedge clock, posedge reset) begin
        if (reset || flush) begin
            if (reset) begin
                pc <= 64'd0;
                IF_regs.pc4 <= 64'd4;
            end else begin
                pc <= pc_next;
                IF_regs.pc4 <= pc_next + 64'd4;
            end
            IF_regs.inst <= 32'd0;
        end else if (!stall) begin
            IF_regs.inst <= inst;
            pc <= pc_next;
            IF_regs.pc4 <= pc_next + 64'd4;
        end
    end
endmodule
