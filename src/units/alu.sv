`define ALU_ADD    3'b010
`define ALU_SUB    3'b011
`define ALU_AND    3'b100
`define ALU_OR     3'b101
`define ALU_NOR    3'b110
`define ALU_XOR    3'b111

module alu #(
    parameter width = 32
) (
    output wire [width-1:0] out,
    output wire overflow,
    output wire zero,
    output wire negative,
    input wire [width-1:0] a,
    input wire [width-1:0] b,
    input wire [2:0] alu_op
);
    wire [width-1:0] lu_out, au_out;
    lu #(width) lu_0(
        a,
        b,
        alu_op[1:0],
        lu_out
    );
    au #(width) au_0(
        a,
        b,
        alu_op[0],
        au_out,
        negative,
        zero,
        overflow
    );

    mux2v #(width) mux2v_0(
        out,
        au_out,
        lu_out,
        alu_op[2]
    );
endmodule
