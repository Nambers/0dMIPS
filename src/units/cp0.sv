module cp0 #(
    parameter width = 32,
    parameter STATUS_REGISTER = 5'd12,
    parameter CAUSE_REGISTER  = 5'd13,
    parameter EPC_REGISTER    = 5'd14 // register for resuming execution after interrupt
) (
    output wire [width - 1:0] rd_data,
    output wire [width - 3:0] EPC,
    output wire               TakenInterrupt,
    input  wire [width - 1:0] wr_data,
    input  wire [        4:0] regnum,
    input  wire [width - 3:0] next_pc,
    input  wire               MTC0,
    input  wire               ERET,
    input  wire               TimerInterrupt,
    input  wire               clock,
    input  wire               reset
);

    /* verilator lint_off UNUSEDSIGNAL */
    wire [width - 1:0] user_status, enable_wire;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [width - 3:0] EPC_D;
    wire exception_level;

    barrel_shifter32 #(width) barrel_shifter32_ (
        .data_out(enable_wire),
        .data_in({{(width - 1) {1'b0}}, MTC0}),
        .shift_amount(regnum),
        .direction(1'b0)  // shift left
    );
    register #(width) user_status_reg (
        user_status,
        wr_data,
        clock,
        enable_wire[STATUS_REGISTER],
        reset
    );
    register #(1) exception_lv_reg (
        exception_level,
        1'b1,
        clock,
        TakenInterrupt,
        ERET | reset
    );

    mux2v #(width - 2) m (
        EPC_D,
        wr_data[width-1:2],
        next_pc,
        TakenInterrupt
    );
    register #(width - 2) EPC_reg (
        EPC,
        EPC_D,
        clock,
        enable_wire[EPC_REGISTER] | TakenInterrupt,
        reset
    );

    wire [width - 1:0] cause_reg = {16'b0, TimerInterrupt, 15'b0};
    wire [width - 1:0] status_reg = {
        16'b0, user_status[15:8], 6'b0, exception_level, user_status[0]
    };

    // wire a,b,c;
    // and a1(a, cause_reg[15], status_reg[15]);
    // not b1(b, status_reg[1]);
    // and c1(c, b, status_reg[0]);
    // and (TakenInterrupt, a, c);
    assign TakenInterrupt = (cause_reg[15] & status_reg[15]) & ((~status_reg[1]) & status_reg[0]);

    assign rd_data = (regnum == STATUS_REGISTER ? status_reg : (regnum == CAUSE_REGISTER ? cause_reg : (regnum == EPC_REGISTER ? {EPC, 2'b0} : 32'b0)));

endmodule
