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
    input logic [63:0] pred_npc,  // speculative next PC from branch predictor
    input logic [63:0] EPC,
    input logic takenHandler,
    input logic reset,
    output logic [63:0] next_fetch_pc  /* verilator public */,
    output logic flush
);
    logic [63:0] interrupeHandlerAddr  /* verilator public */ = 64'd0;
    logic [63:0] forwarded_A;
    logic [63:0] correct_npc;
    logic is_cond_branch, actual_taken, mispredict;

    mux4v #(64) forward_mux_A (
        forwarded_A,
        ID_regs.A_data,
        EX_regs.out,
        MEM1_data,
        MEM_data,
        forward_A
    );

    always_comb begin
        // -- resolve conditional branch in EX and check the prediction --
        is_cond_branch = EX_regs.BEQ || EX_regs.BNE || EX_regs.BC || EX_regs.BAL;
        actual_taken   = EX_regs.BC || EX_regs.BAL ||
                         (EX_regs.BEQ && EX_regs.zero) ||
                         (EX_regs.BNE && !EX_regs.zero);
        correct_npc    = actual_taken ? EX_regs.pc_branch : EX_regs.pc4;
        // the predictor steered fetch to EX_regs.predicted_npc; flush only if
        // that disagrees with the resolved next PC.
        mispredict     = is_cond_branch && (EX_regs.predicted_npc != correct_npc);

        if (reset) begin
            next_fetch_pc = 64'd0;
            flush = 1'b1;
        end else if (takenHandler) begin
            next_fetch_pc = interrupeHandlerAddr;
            flush = 1'b1;
        end else if (ID_regs.ERET) begin
            next_fetch_pc = EPC;
            flush = 1'b1;
        end else if (mispredict) begin
            next_fetch_pc = correct_npc;
            flush = 1'b1;
        end else
            // jump resolve in ID stage
            /* verilator lint_off CASEINCOMPLETE */
            unique case (ID_regs.control_type)
                NORMAL: begin
                    // follow the predicted (speculative) path
                    next_fetch_pc = pred_npc;
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
