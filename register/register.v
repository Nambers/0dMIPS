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

module regfile #(
    parameter width = 32
) (
    output wire [width-1:0] A_data,
    output wire [width-1:0] B_data,
    input wire [4:0] A_addr,
    input wire [4:0] B_addr,
    input wire [4:0] W_addr,
    input wire [width-1:0] W_data,
    input wire wr_enable,
    input wire clk,
    input wire reset
);
    wire [31:0][width - 1:0] reg_out;
    wire [31:0] reg_enable;
    register #(width) regs [31:0](
        .Q(reg_out),
        .D(W_data),
        .clk(clk),
        .enable(reg_enable),
        .rst(reset)
    );
    
    assign A_data = reg_out[A_addr];
    assign B_data = reg_out[B_addr];
    
    barrel_shifter32 barrel_shifter32_(
        .data_out(reg_enable),
        .data_in(32'h1),
        .shift_amount(W_addr),
        .direction(1'b0) // shift left
    );

endmodule