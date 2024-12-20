// interrupt after <cycle> cycles
// What -	How
// read the current time	lw from `currentTimeAddr
// request a timer interrupt	sw the desired (future) time to `currentTimeAddr
// acknowledge a timer interrupt	sw any value to `acknowledgeInterruptAddr
module timer #(
    parameter width = 64,
    parameter currentTimeAddr = 64'hFFFF001C,
    parameter acknowledgeInterruptAddr = 64'hFFFF006C
) (
    output wire               TimerInterrupt,
    output wire [width - 1:0] cycle,
    output wire               TimerAddress,
    input  wire [width - 1:0] data,
    input  wire [width - 1:0] address,
    input  wire               MemRead,
    input  wire               MemWrite,
    input  wire               clock,
    input  wire               reset
);

    // -- wire declarations --
    // cycle counter
    wire [width - 1:0] cycle_D, cycle_Q;
    // interrupt cycle
    wire [width - 1:0] icycle_Q;
    // lower
    wire Acknowledge, TimerWrite, TimerRead;

    // -- cycle counter --

    register #(width) cycle_counter (
        cycle_Q,
        cycle_D,
        clock,
        1'b1,
        reset
    );

    /* verilator lint_off PINNOCONNECT */
    alu #(width) cycle_alu2 (
        cycle_D,,,,
        cycle_Q,
        {{(width - 1) {1'b0}}, 1'b1},
        3'b010  // ALU_ADD
    );
    /* verilator lint_on PINNOCONNECT */

    // Tri-state buffer
    assign cycle = TimerRead ? cycle_Q : {width{1'bz}};

    // -- interrupt cycle --

    register #(width, {width{1'b1}}) interrupt_cycle (
        icycle_Q,
        data,
        clock,
        TimerWrite,
        reset
    );

    // -- interrupt line --

    register #(1) interrupt_line (
        TimerInterrupt,
        1'b1,
        clock,
        icycle_Q == cycle_Q,
        reset | Acknowledge
    );

    // -- lower --

    wire addr_eq1 = address == currentTimeAddr;
    wire addr_eq2 = address == acknowledgeInterruptAddr;
    assign TimerAddress = addr_eq1 | addr_eq2;
    assign Acknowledge = addr_eq2 & MemWrite;
    assign TimerRead = addr_eq1 & MemRead;
    assign TimerWrite = addr_eq1 & MemWrite;

endmodule
