import structures::control_type_t;
import structures::NORMAL;
import structures::J;
import structures::JR;
import structures::ID_regs_t;
import structures::EX_regs_t;

module core_branch (
    /* verilator lint_off UNUSEDSIGNAL */
    input ID_regs_t ID_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] pc4,
    input logic [63:0] EPC,
    input logic takenHandler,
    input logic reset,
    output logic [63:0] next_pc,
    output logic flush
);
    logic [63:0] interrupeHandlerAddr;

    initial begin
        integer fd;
        // plz put the error handler address at first in .data section
        // this can help the memory be compacted
        // TODO make it boot vector or configurable in CP0
        fd = $fopen("memory.mem", "r");
        if (|fd) begin
            $fscanf(fd, "@%h", interrupeHandlerAddr);  // skip the first line
            if (interrupeHandlerAddr != 'b0) begin
                interrupeHandlerAddr = 'h0;  // default value
            end else begin
                $fscanf(fd, "%h", interrupeHandlerAddr);
                $display("Interrupe Handler Address: %h", interrupeHandlerAddr);
            end
            $fclose(fd);
        end
    end

    always_comb begin
        if (reset) begin
            next_pc = 64'd0;
            flush   = 1'b1;
        end else if (takenHandler) begin
            next_pc = interrupeHandlerAddr;
            flush   = 1'b1;
        end else if (ID_regs.ERET) begin
            next_pc = EPC;
            flush   = 1'b1;
            // branch resolve in ID stage
        end else if (ID_regs.BC | ID_regs.BAL | (ID_regs.BEQ & ID_regs.zero) | (ID_regs.BNE & ~ID_regs.zero)) begin
            next_pc = ID_regs.pc_branch;
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
                    // jalr and jr
                    next_pc = ID_regs.A_data;
                    flush   = 1'b1;
                end
            endcase
        /* verilator lint_on CASEINCOMPLETE */
    end
endmodule
