// tristate: Tri-state buffer
//
// o       (output) - tri-state output
// d       (input)  - tri-state input
// control (input)  - Whether to output d or high impedance
//
module tristate (
    o,
    d,
    control
);

    parameter width = 32;

    output [(width-1):0] o;
    input [(width-1):0] d;
    input control;

    assign o = control ? d : 'bz;

endmodule  // tristate

// interrupt after <cycle> cycles
// What -	How
// read the current time	lw from `currentTimeAddr
// request a timer interrupt	sw the desired (future) time to `currentTimeAddr
// acknowledge a timer interrupt	sw any value to `acknowledgeInterruptAddr
module timer #(
    parameter width = 32,
    parameter currentTimeAddr = 32'hFFFF001C,
    parameter acknowledgeInterruptAddr = 32'hFFFF006C
) (
    output               TimerInterrupt,
    output [width - 1:0] cycle,
    output               TimerAddress,
    input  [width - 1:0] data,
    address,
    input                MemRead,
    MemWrite,
    clock,
    reset
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

    alu #(width) cycle_alu2 (
        cycle_D,,,,
        cycle_Q,
        {{(width - 1) {1'b0}}, 1'b1},
        3'b010
    );

    tristate #(width) cycle_out (
        cycle,
        cycle_Q,
        TimerRead
    );

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
