module mux2v #(
    parameter width = 32
) (
    output wire [width-1:0] out,
    input wire [width-1:0] a,
    input wire [width-1:0] b,
    input wire sel
);
    assign out = ({ {width{~sel}}} & a) | ({ {width{sel}}} & b);
endmodule

module mux3v #(
    parameter width = 32
) (
    output wire [width-1:0] out,
    input wire [width-1:0] a,
    input wire [width-1:0] b,
    input wire [width-1:0] c,
    input wire [1:0] sel
);
    wire [width - 1:0] tmp;
    mux2v #(width) mux2v_0(tmp, a, b, sel[0]);
    mux2v #(width) mux2v_1(out, tmp, c, sel[1]);
endmodule

module mux4v #(
    parameter width = 32
) (
    output wire [width-1:0] out,
    input wire [width-1:0] a,
    input wire [width-1:0] b,
    input wire [width-1:0] c,
    input wire [width-1:0] d,
    input wire [1:0] sel
);
    wire [width - 1:0] tmp, tmp2;
    mux2v #(width) mux2v_0(tmp, a, b, sel[0]);
    mux2v #(width) mux2v_1(tmp2, c, d, sel[0]);
    mux2v #(width) mux2v_2(out, tmp, tmp2, sel[1]);
endmodule