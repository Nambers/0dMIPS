// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP

// XMASK: don't-care inputs in port order (a = MSB), e.g. mux4v #(w, 4'b0010) = c.
// Vivado elaborates a 'x port constant as 0, so the 'x is applied in here.
module mux2v #(
    parameter width = 32,
    parameter bit [1:0] XMASK = '0
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic sel
);
    always_comb begin
        // out = ({{width{~sel}}} & a) | ({{width{sel}}} & b);
        // OR
        out = sel ? (XMASK[0] ? 'x : b) : (XMASK[1] ? 'x : a);
    end
endmodule

module mux3v #(
    parameter width = 32,
    parameter bit [2:0] XMASK = '0
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [1:0] sel
);
    logic [width - 1:0] tmp;
    mux2v #(width, XMASK[2:1]) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width, {
        XMASK[2] && XMASK[1], XMASK[0]
    }) mux2v_1 (
        out,
        tmp,
        c,
        sel[1]
    );
endmodule

module mux4v #(
    parameter width = 32,
    parameter bit [3:0] XMASK = '0
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [width-1:0] d,
    input logic [1:0] sel
);
    logic [width - 1:0] tmp, tmp2;
    mux2v #(width, XMASK[3:2]) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width, XMASK[1:0]) mux2v_1 (
        tmp2,
        c,
        d,
        sel[0]
    );
    mux2v #(width, {
        XMASK[3] && XMASK[2], XMASK[1] && XMASK[0]
    }) mux2v_2 (
        out,
        tmp,
        tmp2,
        sel[1]
    );
endmodule

module mux8v #(
    parameter width = 32,
    parameter bit [7:0] XMASK = '0
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
    mux2v #(width, XMASK[7:6]) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width, XMASK[5:4]) mux2v_1 (
        tmp2,
        c,
        d,
        sel[0]
    );
    mux2v #(width, XMASK[3:2]) mux2v_2 (
        tmp3,
        e,
        f,
        sel[0]
    );
    mux2v #(width, XMASK[1:0]) mux2v_3 (
        tmp4,
        g,
        h,
        sel[0]
    );
    mux4v #(width, {
        XMASK[7] && XMASK[6],
        XMASK[5] && XMASK[4],
        XMASK[3] && XMASK[2],
        XMASK[1] && XMASK[0]
    }) mux4v_0 (
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
