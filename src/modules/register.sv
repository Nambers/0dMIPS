// There also two ways to implement register with enable

// -- use D flip-flop --
/***
module register #(
    parameter width = 32,
    parameter reset_value = 0
) (
    output wire [width-1:0] Q,
    input wire [width-1:0] D,
    input wire clk,
    input wire enable,
    input wire rst
);
    D_flip_flop D_flip_flop_ [width - 1: 0](
        clk, rst, enable, D[width - 1:0], Q[width - 1:0]
    );
endmodule
***/

// -- use reg and always block --

// register: A register which may be reset to an arbirary value
//
// q      (output) - Current value of register
// d      (input)  - Next value of register
// clk    (input)  - Clock (positive edge-sensitive)
// enable (input)  - Load new value? (yes = 1, no = 0)
// reset  (input)  - Synchronous reset    (reset = 1)
//
module register #(
    parameter width = 32,
    parameter reset_value = 0
) (
    output logic [(width-1):0] Q,
    input logic [(width-1):0] D,
    input logic clk,
    input logic enable,
    input logic rst
);
    always @(posedge clk or posedge rst) begin
        if (rst) Q <= reset_value;
        else if (enable) Q <= D;
    end
endmodule  // register
