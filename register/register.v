module register #(
    parameter width = 32
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