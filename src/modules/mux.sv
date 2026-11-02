// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP

// XMASK marks inputs whose value is a don't-care. Its range is ascending
// ([0:N-1]), so the literal reads in port order (a is the leftmost bit) and
// XMASK[i] is input i, i.e. XMASK[sel] is the selected input:
// mux4v #(.., 4'b0010) means only c is a don't-care.
// Pass 'x on those pins for readability, but the mask is what takes effect:
// a 'x constant on a port is elaborated as 0 (Vivado), which turns e.g.
// `sel ? b : 'x` into an AND gate. Writing the 'x inside the module keeps it a
// don't-care, so the mux collapses (mux2v with XMASK=2'b10 becomes `out = b`).
module mux2v #(
    parameter width = 32,
    parameter bit [0:1] XMASK = '0
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic sel
);
    always_comb begin
        // out = ({{width{~sel}}} & a) | ({{width{sel}}} & b);
        // OR
        out = sel ? (XMASK[1] ? 'x : b) : (XMASK[0] ? 'x : a);
    end
endmodule

module mux3v #(
    parameter width = 32,
    parameter bit [0:2] XMASK = '0
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [1:0] sel
);
    logic [width - 1:0] tmp;
    mux2v #(width, XMASK[0:1]) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    // an all-don't-care child output stays a don't-care one level up
    mux2v #(width, {
        XMASK[0] && XMASK[1], XMASK[2]
    }) mux2v_1 (
        out,
        tmp,
        c,
        sel[1]
    );
endmodule

module mux4v #(
    parameter width = 32,
    parameter bit [0:3] XMASK = '0
) (
    output logic [width-1:0] out,
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic [width-1:0] c,
    input logic [width-1:0] d,
    input logic [1:0] sel
);
    logic [width - 1:0] tmp, tmp2;
    mux2v #(width, XMASK[0:1]) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width, XMASK[2:3]) mux2v_1 (
        tmp2,
        c,
        d,
        sel[0]
    );
    mux2v #(width, {
        XMASK[0] && XMASK[1], XMASK[2] && XMASK[3]
    }) mux2v_2 (
        out,
        tmp,
        tmp2,
        sel[1]
    );
endmodule

module mux8v #(
    parameter width = 32,
    parameter bit [0:7] XMASK = '0
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
    mux2v #(width, XMASK[0:1]) mux2v_0 (
        tmp,
        a,
        b,
        sel[0]
    );
    mux2v #(width, XMASK[2:3]) mux2v_1 (
        tmp2,
        c,
        d,
        sel[0]
    );
    mux2v #(width, XMASK[4:5]) mux2v_2 (
        tmp3,
        e,
        f,
        sel[0]
    );
    mux2v #(width, XMASK[6:7]) mux2v_3 (
        tmp4,
        g,
        h,
        sel[0]
    );
    mux4v #(width, {
        XMASK[0] && XMASK[1],
        XMASK[2] && XMASK[3],
        XMASK[4] && XMASK[5],
        XMASK[6] && XMASK[7]
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
