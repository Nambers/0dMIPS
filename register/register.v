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
)(

   output reg [(width-1):0] Q,
   input wire [(width-1):0] D,
   input wire clk,
   input wire enable,
   input wire rst
);
    always@(posedge clk)
        if (rst == 1'b1)
        Q <= reset_value;
        else if (enable == 1'b1)
        Q <= D;
endmodule // register

module regfile #(
    parameter width = 32,
    parameter reset_value = 0
) (
    output wire [width-1:0] A_data,
    output wire [width-1:0] B_data,
    input wire [4:0] A_addr,
    input wire [4:0] B_addr,
    input wire [4:0] W_addr,
    input wire [width-1:0] W_data,
    input wire wr_enable,
    input wire clk,
    input wire reset,
    output wire [31:0][width - 1:0] debug_reg_out
);
    wire [31:0][width - 1:0] reg_out;
    `ifdef SIMULATION
        assign debug_reg_out = reg_out;
    `endif
    wire [31:0] reg_enable, reg_enable_tmp;

    barrel_shifter32 barrel_shifter32_(
        .data_out(reg_enable_tmp),
        .data_in(32'b1),
        .shift_amount(W_addr),
        .direction(1'b0) // shift left
    );

    mux2v #(32) mux2v_0(
        reg_enable,
        32'b0,
        reg_enable_tmp,
        wr_enable
    );

    register #(width, reset_value) regs [31:0](
        .Q(reg_out),
        .D(W_data),
        .clk(clk),
        .enable(reg_enable),
        .rst(reset)
    );
    
    assign A_data = reg_out[A_addr];
    assign B_data = reg_out[B_addr];

endmodule