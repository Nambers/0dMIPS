module lu #(
    parameter width = 32
) (
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [1:0] lu_op,
    output logic [width-1:0] out
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
