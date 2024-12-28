`define WIDTH 32
`define ADDR_WIDTH 64
module cp0 #(
    parameter [5:0] STATUS_REGISTER = 6'd12,
    parameter [5:0] CAUSE_REGISTER  = 6'd13,
    parameter [5:0] EPC_REGISTER    = 6'd14 // register for resuming execution after interrupt
) (
    output wire [`ADDR_WIDTH - 1:0] rd_data,
    output wire [`ADDR_WIDTH - 3:0] EPC,
    output wire                     TakenInterrupt,
    input  wire [`ADDR_WIDTH - 1:0] wr_data,
    input  wire [              4:0] regnum,
    input  wire [`ADDR_WIDTH - 3:0] next_pc,
    input  wire                     MTC0,
    input  wire                     ERET,
    input  wire                     TimerInterrupt,
    input  wire                     clock,
    input  wire                     reset
);

    /* verilator lint_off UNUSEDSIGNAL */
    wire [`ADDR_WIDTH - 1:0] user_status, enable_wire;
    /* verilator lint_on UNUSEDSIGNAL */
    wire [`ADDR_WIDTH - 3:0] EPC_D;
    wire exception_level;

    barrel_shifter32 #(`ADDR_WIDTH) barrel_shifter32_ (
        .data_out(enable_wire),
        .data_in({{(`ADDR_WIDTH - 1) {1'b0}}, MTC0}),
        .shift_amount(regnum),
        .direction(1'b0)  // shift left
    );
    register #(`ADDR_WIDTH) user_status_reg (
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

    mux2v #(`ADDR_WIDTH - 2) m (
        EPC_D,
        wr_data[`ADDR_WIDTH-1:2],
        next_pc,
        TakenInterrupt
    );
    register #(`ADDR_WIDTH - 2) EPC_reg (
        EPC,
        EPC_D,
        clock,
        enable_wire[EPC_REGISTER] | TakenInterrupt,
        reset
    );

    wire [`WIDTH - 1:0] cause_reg = {16'b0, TimerInterrupt, 15'b0};
    wire [`WIDTH - 1:0] status_reg = {
        16'b0, user_status[15:8], 6'b0, exception_level, user_status[0]
    };

    // wire a,b,c;
    // and a1(a, cause_reg[15], status_reg[15]);
    // not b1(b, status_reg[1]);
    // and c1(c, b, status_reg[0]);
    // and (TakenInterrupt, a, c);
    assign TakenInterrupt = (cause_reg[15] & status_reg[15]) & ((~status_reg[1]) & status_reg[0]);

    assign rd_data = ({1'b0, regnum} == STATUS_REGISTER ? {32'b0, status_reg} : ({1'b0, regnum} == CAUSE_REGISTER ? {32'b0,cause_reg} : ({1'b0, regnum} == EPC_REGISTER ? {EPC, 2'b0} : `ADDR_WIDTH'b0)));

endmodule
