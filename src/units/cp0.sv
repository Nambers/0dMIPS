module cp0 #(
    parameter [4:0] STATUS_REGISTER = 5'd12,
    parameter [4:0] CAUSE_REGISTER = 5'd13,
    parameter [4:0] EPC_REGISTER    = 5'd14,
    parameter [4:0] BAD_INSTR_REGISTER = 5'd8
) (
    output logic [63:0] rd_data,
    output logic [63:0] EPC,
    output logic        takenHandler,
    input  logic [63:0] wr_data,
    input  logic [ 4:0] regnum,
    input  logic [ 2:0] sel,
    input  logic [63:0] curr_pc,
    input  logic        MTC0,
    input  logic        ERET,
    input  logic [ 7:0] interrupt_source,
    input  logic        clock,
    input  logic        reset,
    input  logic        overflow,
    input  logic        reserved_inst,
    input  logic        syscall,
    input  logic        break_
);
    logic [4:0] exc_code  /* verilator public */, next_exc_code;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] user_status;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [31:0] badinstr_D, cause_reg, status_reg;
    logic [63:0] EPC_D;
    logic exception_level, takenInterrupt, takenException;

    // TODO reset BEV, ERL should be 1
    // but can't rlly set BEV to 1, because I don't use boot vector yet.
    // when reset:
    // - enable all exception interrupts
    // - enable IE
    register #(32, 32'b0000_0000_0000_0000_1111_1111_0000_0001) user_status_reg (
        user_status,
        wr_data[31:0],
        clock,
        MTC0 && (regnum == STATUS_REGISTER) && (sel == 0),
        reset
    );

    register #(32) badinstr_reg (
        badinstr_D,
        wr_data[31:0],
        clock,
        takenException,
        ERET || reset
    );

    register #(1) exception_lv_reg (
        exception_level,
        takenHandler ? 1'b1 : wr_data[1],
        clock,
        takenHandler || ((MTC0 && regnum == STATUS_REGISTER) && (sel == 0)),
        ERET || reset
    );

    mux2v #(64) data_pc_mux (
        EPC_D,
        wr_data,
        curr_pc,
        takenException || takenInterrupt
    );
    register #(64) EPC_reg (
        EPC,
        EPC_D,
        clock,
        (MTC0 && (regnum == EPC_REGISTER) & (sel == 0)) || takenHandler,
        reset
    );

    always_comb begin
        cause_reg = {
            16'b0,
            interrupt_source,  // 7 outside interrupt sources
            1'b0,
            exc_code,  // ExcCode
            2'b0
        };
        status_reg = {
            user_status[31:3],
            user_status[2],  // ERL
            exception_level,  // EXL
            user_status[0]  // IE
        };

        unique case ({
            regnum, sel
        })
            {STATUS_REGISTER, 3'b0}: rd_data = {32'b0, status_reg};
            {CAUSE_REGISTER, 3'b0}:  rd_data = {32'b0, cause_reg};
            {EPC_REGISTER, 3'b0}:    rd_data = EPC;
            {BAD_INSTR_REGISTER, 3'b1}: rd_data = {32'b0, badinstr_D};
            default: rd_data = 'x;
        endcase
        case (1'b1)
            overflow:      next_exc_code = 5'h0c;
            reserved_inst: next_exc_code = 5'h0a;
            syscall:       next_exc_code = 5'h08;
            break_:        next_exc_code = 5'h09;
            default:       next_exc_code = 5'h00;
        endcase

        takenException = |next_exc_code;  // ExcCode != 0
        takenInterrupt = ((|(cause_reg[15:8] & status_reg[15:8])) && // if enabled interrupt sources
        (!(|exc_code)) &&  // ExcCode = 0
        (status_reg[0]) &&  // IE = 1
        (!status_reg[2]));  // ERL = 0
        takenHandler = (takenInterrupt || takenException) && (!status_reg[1]);  // EXL = 0
    end

    always_ff @(posedge clock, posedge reset) begin
`ifdef DEBUG
        if (regnum == BAD_INSTR_REGISTER)
            $display("CP0: readBadInstr = %h", rd_data);
        if (regnum == CAUSE_REGISTER && sel == 0)
            $display("CP0: readCause = %h", rd_data);
        if (regnum == STATUS_REGISTER && sel == 0)
            $display("CP0: readStatus = %h", rd_data);
        if (syscall) $display("CP0: syscall, EPC = %h", EPC);
        if (takenHandler)
            $display(
                "CP0: taken handler, ExcCode = %h, EPC wr = %h B_data = %h, pc = %h",
                next_exc_code,
                EPC_D,
                wr_data,
                curr_pc
            );
        if (ERET) $display("CP0: ERET, EPC = %h", EPC);
        if (MTC0)
            $display(
                "CP0: MTC0, regnum = %d(sel=%d), data = %h",
                regnum,
                sel,
                wr_data
            );
`endif
        if (reset) begin
            exc_code <= 5'h00;
        end else begin
            if (takenHandler) exc_code <= next_exc_code;
            else if (ERET) exc_code <= '0;
        end
    end

endmodule
