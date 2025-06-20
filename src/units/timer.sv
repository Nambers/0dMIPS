import configurations::TIMER_CNT_ADDR;
import configurations::TIMER_CRL_ADDR;
// interrupt after <cycle> cycles
// What -	How
// read the current time	lw from `currentTimeAddr
// request a timer interrupt	sw the desired (future) time to `currentTimeAddr
// acknowledge a timer interrupt	sw any value to `acknowledgeInterruptAddr
module timer #(
    parameter width = 64
) (
    output logic               TimerInterrupt,
    output logic [width - 1:0] cycle,
    output logic               TimerAddress,
    input  logic [width - 1:0] data,
    input  logic [width - 1:0] address,
    input  logic               MemRead,
    input  logic               MemWrite,
    input  logic               clock,
    input  logic               reset
);

    // -- logic declarations --
    // cycle counter
    logic [width - 1:0] cycle_D, cycle_Q;
    // interrupt cycle
    logic [width - 1:0] icycle_Q;
    // lower
    logic Acknowledge, TimerWrite, TimerRead;
    logic armed_Q;

    // -- cycle counter --

    register #(width) cycle_counter (
        cycle_Q,
        cycle_D,
        clock,
        1'b1,
        reset
    );

    assign cycle_D = cycle_Q + 1;

    // Tri-state buffer
    assign cycle   = TimerRead ? cycle_Q : 'z;

    // -- interrupt cycle --

    register #(1) armed(
        armed_Q,
        1'b1,
        clock,
        TimerWrite,
        Acknowledge | reset
    );

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
        (icycle_Q == cycle_Q) && armed_Q,
        reset | Acknowledge
    );

    // -- lower --

    wire addr_eq1 = address == TIMER_CNT_ADDR;
    wire addr_eq2 = address == TIMER_CRL_ADDR;
    assign TimerAddress = addr_eq1 | addr_eq2;
    assign Acknowledge = addr_eq2 & MemWrite;
    assign TimerRead = addr_eq1 & MemRead;
    assign TimerWrite = addr_eq1 & MemWrite;

endmodule
