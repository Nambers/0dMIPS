module cp0 #(
    parameter [4:0] STATUS_REGISTER = 5'd12,
    parameter [4:0] CAUSE_REGISTER  = 5'd13,
    parameter [4:0] EPC_REGISTER    = 5'd14 // register for resuming execution after interrupt
) (
    output logic [63:0] rd_data,
    output logic [63:0] EPC,
    output logic        TakenInterrupt,
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
    logic [4:0] exc_code;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] user_status;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [63:0] EPC_D;
    logic exception_level;

    register #(32, 32'h00400004) user_status_reg (
        user_status,
        wr_data[31:0],
        clock,
        MTC0 & regnum == STATUS_REGISTER & sel == 0,
        reset
    );
    register #(1) exception_lv_reg (
        exception_level,
        TakenInterrupt ? 1'b1 : wr_data[1],
        clock,
        TakenInterrupt | (MTC0 & regnum == STATUS_REGISTER & sel == 0),
        ERET | reset
    );

    mux2v #(64) m (
        EPC_D,
        wr_data,
        next_pc,
        TakenInterrupt
    );
    register #(64) EPC_reg (
        EPC,
        EPC_D,
        clock,
        (MTC0 & regnum == EPC_REGISTER & sel == 0) | TakenInterrupt,
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

    // logic  a,b,c;
    // and a1(a, cause_reg[15], status_reg[15]);
    // not b1(b, status_reg[1]);
    // and c1(c, b, status_reg[0]);
    // and (TakenInterrupt, a, c);
    assign TakenInterrupt = (cause_reg[15] & status_reg[15]) & ((~status_reg[1]) & status_reg[0]);

    always_comb begin
        case (regnum)
            STATUS_REGISTER: rd_data = {32'b0, status_reg};
            CAUSE_REGISTER:  rd_data = {32'b0, cause_reg};
            EPC_REGISTER:    rd_data = EPC;
            default:         rd_data = 64'b0;
        endcase
    end

    always_comb begin
        if (~exception_level && (overflow | reserved_inst | syscall | break_)) begin
            case (1'b1)
                overflow:      exc_code = 5'h0c;
                reserved_inst: exc_code = 5'h0a;
                syscall:       exc_code = 5'h08;
                break_:        exc_code = 5'h09;
                default:       exc_code = 5'h00;
            endcase
        end else begin
            exc_code = 5'h00;
        end
    end

endmodule
