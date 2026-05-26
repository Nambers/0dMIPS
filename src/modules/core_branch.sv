import structures::control_type_t;
import structures::NORMAL;
import structures::J;
import structures::JR;
import structures::ID_regs_t;
import structures::EX_regs_t;
import structures::forward_type_t;

module core_branch (
    /* verilator lint_off UNUSEDSIGNAL */
    input ID_regs_t ID_regs,
    input EX_regs_t EX_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input forward_type_t forward_A,
    input logic [63:0] MEM1_data,
    input logic [63:0] MEM_data,
    input logic [63:0] fetch_pc4,
    input logic [63:0] EPC,
    input logic takenHandler,
    input logic reset,
    output logic [63:0] next_fetch_pc  /* verilator public */,
    output logic flush
);
    logic [63:0] interrupeHandlerAddr  /* verilator public */ = 64'd0;
    logic [63:0] forwarded_A;

    mux4v #(64) forward_mux_A (
        forwarded_A,
        ID_regs.A_data,
        EX_regs.out,
        MEM1_data,
        MEM_data,
        forward_A
    );

    always_comb begin
        if (reset) begin
            next_fetch_pc = 64'd0;
            flush = 1'b1;
        end else if (takenHandler) begin
            next_fetch_pc = interrupeHandlerAddr;
            flush = 1'b1;
        end else if (ID_regs.ERET) begin
            next_fetch_pc = EPC;
            flush = 1'b1;
            // branch resolve in EX stage
        end else if (EX_regs.BC || EX_regs.BAL || (EX_regs.BEQ && EX_regs.zero) || (EX_regs.BNE && !EX_regs.zero)) begin
            next_fetch_pc = EX_regs.pc_branch;
            flush = 1'b1;
        end else
            // jump resolve in ID stage
            /* verilator lint_off CASEINCOMPLETE */
            unique case (ID_regs.control_type)
                NORMAL: begin
                    next_fetch_pc = fetch_pc4;
                    flush = 1'b0;
                end
                J: begin
                    next_fetch_pc = ID_regs.jumpAddr;
                    flush = 1'b1;
                end
                JR: begin
                    // jalr and jr
                    next_fetch_pc = forwarded_A;
                    flush = 1'b1;
                end
            endcase
        /* verilator lint_on CASEINCOMPLETE */
    end
endmodule
