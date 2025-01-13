module cp0 #(
    parameter [4:0] STATUS_REGISTER = 5'd12,
    parameter [4:0] CAUSE_REGISTER  = 5'd13,
    parameter [4:0] EPC_REGISTER    = 5'd14 // register for resuming execution after interrupt
) (
    output logic [63:0] rd_data,
    output logic [63:0] EPC,
    output logic        takenHandler,
    input  logic [63:0] wr_data,
    input  logic [ 4:0] regnum,
    input  logic [ 2:0] sel,
    input  logic [63:0] next_pc,
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
    logic [4:0] exc_code, next_exc_code;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] user_status;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [63:0] EPC_D;
    logic exception_level;

    // TODO reset BEV, ERL should be 1
    // when reset:
    // - enable all exception interrupts
    // - enable IE
    register #(32, 32'b0000_0000_0000_0000_1111_1111_0000_0001) user_status_reg (
        user_status,
        wr_data[31:0],
        clock,
        MTC0 & regnum == STATUS_REGISTER & sel == 0,
        reset
    );
    register #(1) exception_lv_reg (
        exception_level,
        takenHandler ? 1'b1 : wr_data[1],
        clock,
        takenHandler | (MTC0 & regnum == STATUS_REGISTER & sel == 0),
        ERET | reset
    );

    // TODO EPC won't work under pipeline
    mux2v #(64) m (
        EPC_D,
        wr_data,
        next_pc,
        takenHandler
    );
    register #(64) EPC_reg (
        EPC,
        EPC_D,
        clock,
        (MTC0 & regnum == EPC_REGISTER & sel == 0) | takenHandler,
        reset
    );

    wire [31:0] cause_reg = {
        16'b0,  // reserved
        interrupt_source,  // 7 outside interrupt sources
        1'b0,  // reserved
        exc_code,  // ExcCode
        2'b0  // reserved
    };
    wire [31:0] status_reg = {user_status[31:2], exception_level, user_status[0]};

    wire takenInterrupt = ((|(cause_reg[15:8] & status_reg[15:8])) & // if enabled interrupt sources
    (~(|exc_code)) &  // ExcCode = 0
    (~status_reg[1]) &  // EXL = 0
    (status_reg[0]) &  // IE = 1
    (~status_reg[2]));  // ERL = 0

    wire takenException = ((|exc_code) &  // ExcCode != 0
    (~status_reg[1]));  // EXL = 0

    assign takenHandler = takenInterrupt | takenException;

    always_comb begin
        case (regnum)
            STATUS_REGISTER: rd_data = {32'b0, status_reg};
            CAUSE_REGISTER:  rd_data = {32'b0, cause_reg};
            EPC_REGISTER:    rd_data = EPC;
            default:         rd_data = 64'b0;
        endcase

        if (~exception_level && (overflow | reserved_inst | syscall | break_)) begin
            unique case (1'b1)
                overflow:      next_exc_code = 5'h0c;
                reserved_inst: next_exc_code = 5'h0a;
                syscall:       next_exc_code = 5'h08;
                break_:        next_exc_code = 5'h09;
                default:       next_exc_code = 5'h00;
            endcase
        end else begin
            next_exc_code = 5'h00;
        end
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            exc_code <= 5'h00;
        end else begin
            exc_code <= next_exc_code;
        end
    end

endmodule
