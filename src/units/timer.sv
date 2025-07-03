import configurations::TIMER_CNT_ADDR;
import configurations::TIMER_CRL_ADDR;
// interrupt after <cycle> cycles
// What -	How
// read the current time	lw from `TIMER_CNT_ADDR
// request a timer interrupt	sw the desired (future) time to `TIMER_CNT_ADDR
// acknowledge a timer interrupt	sw any value to `TIMER_CRL_ADDR
module timer #(
    parameter width = 64
) (
    output logic               TimerInterrupt,
    output logic [width - 1:0] cycle,
    output logic               TimerAddress,
    input  logic               enable,
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
    logic Acknowledge, TimerWrite, TimerRead, addr_eq1, addr_eq2;
    logic armed_Q;

    // -- cycle counter --

    register #(width) cycle_counter (
        cycle_Q,
        cycle_D,
        clock,
        1'b1,
        reset
    );

    // -- interrupt cycle --

    register #(1) armed (
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

    always_comb begin
        addr_eq1 = enable & (address == TIMER_CNT_ADDR);
        addr_eq2 = enable & (address == TIMER_CRL_ADDR);
        TimerAddress = addr_eq1 | addr_eq2;
        Acknowledge = addr_eq2 & MemWrite;
        TimerRead = addr_eq1 & MemRead;
        TimerWrite = addr_eq1 & MemWrite;

        cycle_D = cycle_Q + 1;
        // Tri-state buffer
        cycle = TimerRead ? cycle_Q : 'x;
    end

    always_ff @(posedge clock or posedge reset) begin
`ifdef DEBUG
        if (reset) begin
            $display("Timer reset");
        end else if (TimerWrite) begin
            $display("Timer write: %h to %h", data, address);
        end else if (TimerRead) begin
            $display("Timer read from %h = %h", address, cycle_Q);
        end else if (Acknowledge) begin
            $display("Timer acknowledge at %h", address);
        end
        if (TimerInterrupt) begin
            $display("Timer interrupt at cycle %h", cycle_Q);
        end
`endif
    end
endmodule
