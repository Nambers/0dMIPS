import structures::IF_regs_t;
import structures::mem_bus_req_t;
import structures::mem_bus_resp_t;
import structures::LOAD_WORD;
import structures::NO_STORE;

module core_IF #(
    parameter RESET_PC = 64'h100
) (
    input logic clock,
    input logic reset,
    input logic [63:0] next_fetch_pc,
    input logic stall,
    input logic flush,

    output logic [63:0] first_half_pc  /* verilator public */,
    output logic [63:0] first_half_pc4  /* verilator public */,
    output IF_regs_t IF_regs,

    // -- mem bus --
    output mem_bus_req_t  inst_req,
    input  mem_bus_resp_t inst_resp
);
    typedef struct packed {logic [63:0] fetch_pc4, fetch_pc;} IF1_t;

    IF1_t IF1;
    logic [63:0] inst_L1;

    cache_L1 inst_cache (
        .clock(clock),
        .reset(reset),
        .enable(!stall),
        .clear(flush),
        .signed_type(1'b0),
        .addr(IF1.fetch_pc),
        .wdata('x),
        .mem_load_type(LOAD_WORD),
        .mem_store_type(NO_STORE),
        .rdata(inst_L1),
        .req(inst_req),
        .resp(inst_resp)
    );

    always_comb begin
        first_half_pc  = IF1.fetch_pc;
        first_half_pc4 = IF1.fetch_pc4;
        IF_regs.inst   = inst_L1[31:0];
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            IF1.fetch_pc <= RESET_PC;
            IF1.fetch_pc4 <= RESET_PC + 4;
            IF_regs.fetch_pc <= '0;
            IF_regs.fetch_pc4 <= '0;
        end else if (!stall || flush) begin
            IF1.fetch_pc  <= next_fetch_pc;
            IF1.fetch_pc4 <= next_fetch_pc + 4;

            if (flush) begin
                IF_regs.fetch_pc  <= '0;
                IF_regs.fetch_pc4 <= '0;
            end else begin
                IF_regs.fetch_pc  <= IF1.fetch_pc;
                IF_regs.fetch_pc4 <= IF1.fetch_pc4;
            end
        end
    end
endmodule
