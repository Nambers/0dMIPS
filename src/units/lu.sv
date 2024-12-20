module lu #(
    parameter width = 32
) (
    input wire [width-1:0] a,
    input wire [width-1:0] b,
    input wire [1:0] lu_op,
    output wire [width-1:0] out
);
    mux4v #(width) mux4v_0 (
        .out(out),
        .a  (a & b),
        .b  (a | b),
        .c  (~(a | b)),
        .d  (a ^ b),
        .sel(lu_op)
    );
endmodule
