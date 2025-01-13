import structures::control_type_t;
import structures::NORMAL;
import structures::J;
import structures::JR;
import structures::ID_regs_t;
import structures::EX_regs_t;

module core_branch (
    /* verilator lint_off UNUSEDSIGNAL */
    input ID_regs_t ID_regs,
    input EX_regs_t EX_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] pc4,
    input logic [63:0] EPC,
    input logic takenHandler,
    output logic [63:0] next_pc,
    output logic flush
);
    logic [63:0] interrupeHandlerAddr;

    initial begin
        integer fd;
        // plz put the error handler address at first in .data section
        // this can help the memory be compacted
        fd = $fopen("memory.data.mem", "r");
        if (|fd) begin
            $fscanf(fd, "@%h", interrupeHandlerAddr);  // skip the first line
            $fscanf(fd, "%h", interrupeHandlerAddr);
            interrupeHandlerAddr = {interrupeHandlerAddr[31:0], interrupeHandlerAddr[63:32]};
            $fclose(fd);
        end
    end

    always_comb begin
        if (takenHandler) begin
            next_pc = interrupeHandlerAddr;
            flush   = 1'b1;
        end else if (ID_regs.ERET) begin
            next_pc = EPC;
            flush   = 1'b1;
            // branch resolve in EX stage
        end else if ((EX_regs.BEQ && EX_regs.zero) || (EX_regs.BNE && !EX_regs.zero)) begin
            next_pc = EX_regs.pc_branch;
            flush   = 1'b1;
        end else
            // others resolve in ID stage
            /* verilator lint_off CASEINCOMPLETE */
            case (ID_regs.control_type)
                NORMAL: begin
                    next_pc = pc4;
                    flush   = 1'b0;
                end
                J: begin
                    next_pc = ID_regs.jumpAddr;
                    flush   = 1'b1;
                end
                JR: begin
                    next_pc = ID_regs.A_data;
                    flush   = 1'b1;
                end
            endcase
        /* verilator lint_on CASEINCOMPLETE */
    end
endmodule
