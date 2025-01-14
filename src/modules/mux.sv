// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP
module mux2v #(
    parameter width = 32
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic sel
);
    assign out = ({{width{~sel}}} & a) | ({{width{sel}}} & b);
endmodule

module mux3v #(
    parameter width = 32
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [1:0] sel
);
    logic [width - 1:0] tmp;
    mux2v #(width) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width) mux2v_1 (
        out,
        tmp,
        c,
        sel[1]
    );
endmodule

module mux4v #(
    parameter width = 32
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [width-1:0] d,
    input logic [1:0] sel
);
    logic [width - 1:0] tmp, tmp2;
    mux2v #(width) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width) mux2v_1 (
        tmp2,
        c,
        d,
        sel[0]
    );
    mux2v #(width) mux2v_2 (
        out,
        tmp,
        tmp2,
        sel[1]
    );
endmodule

module mux8v #(
    parameter width = 32
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [width-1:0] d,
    input logic [width-1:0] e,
    input logic [width-1:0] f,
    input logic [width-1:0] g,
    input logic [width-1:0] h,
    input logic [2:0] sel
);
    logic [width - 1:0] tmp, tmp2, tmp3, tmp4;
    mux2v #(width) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width) mux2v_1 (
        tmp2,
        c,
        d,
        sel[0]
    );
    mux2v #(width) mux2v_2 (
        tmp3,
        e,
        f,
        sel[0]
    );
    mux2v #(width) mux2v_3 (
        tmp4,
        g,
        h,
        sel[0]
    );
    mux4v #(width) mux4v_0 (
        out,
        tmp,
        tmp2,
        tmp3,
        tmp4,
        sel[2:1]
    );
endmodule
// verilator lint_on MULTITOP
// verilator lint_on DECLFILENAME
