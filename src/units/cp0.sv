module cp0 #(
    parameter [4:0] STATUS_REGISTER = 5'd12,
    parameter [4:0] CAUSE_REGISTER  = 5'd13,
    parameter [4:0] EPC_REGISTER    = 5'd14 // register for resuming execution after interrupt
) (
    output logic [63:0] rd_data,
    output wire  [63:0] EPC,
    output wire         TakenInterrupt,
    input  wire  [63:0] wr_data,
    input  wire  [ 4:0] regnum,
    input  wire  [ 2:0] sel,
    input  wire  [63:0] next_pc,
    input  wire         MTC0,
    input  wire         ERET,
    input  wire         TimerInterrupt,
    input  wire         clock,
    input  wire         reset,
    input  wire         overflow,
    input  wire         reserved_inst,
    input  wire         syscall,
    input  wire         break_
);
    logic [4:0] exc_code;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] user_status;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [63:0] EPC_D;
    wire exception_level;

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
        TimerInterrupt,  // timer
        5'b0,  // Hardware
        2'b0,  // Software
        1'b0,  // reserved
        exc_code,  // ExcCode
        2'b0  // reserved
    };
    wire [31:0] status_reg = {user_status[31:2], exception_level, user_status[0]};

    // wire a,b,c;
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

    always @(*) begin
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
