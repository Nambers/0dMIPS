// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP
module barrel_rotator_right #(
    parameter WIDTH = 32
) (
    output logic [WIDTH-1:0] w5,
    input  logic [WIDTH-1:0] w0,
    input  logic [      4:0] rotate_amount
);

    logic [WIDTH-1:0] w1, w2, w3, w4;

    mux2v #(WIDTH) mux_r1 (
        w1,
        w0,
        {w0[0], w0[WIDTH-1:1]},
        rotate_amount[0]
    );
    mux2v #(WIDTH) mux_r2 (
        w2,
        w1,
        {w1[1:0], w1[WIDTH-1:2]},
        rotate_amount[1]
    );
    mux2v #(WIDTH) mux_r4 (
        w3,
        w2,
        {w2[3:0], w2[WIDTH-1:4]},
        rotate_amount[2]
    );
    mux2v #(WIDTH) mux_r8 (
        w4,
        w3,
        {w3[7:0], w3[WIDTH-1:8]},
        rotate_amount[3]
    );
    mux2v #(WIDTH) mux_r16 (
        w5,
        w4,
        {w4[15:0], w4[WIDTH-1:16]},
        rotate_amount[4]
    );
endmodule

module barrel_rotator32 #(
    parameter WIDTH = 32
) (
    output logic [WIDTH-1:0] data_out,
    input  logic [WIDTH-1:0] data_in,
    input  logic [      4:0] rotate_amount,
    input  logic             direction       // 0 = left, 1 = right
);

    logic [WIDTH-1:0] right_result;

    barrel_rotator_right #(WIDTH) right_rotator (
        right_result,
        data_in,
        rotate_amount
    );

    mux2v #(WIDTH) final_mux (
        data_out,
        'x,
        right_result,
        direction
    );
endmodule
// verilator lint_on MULTITOP
// verilator lint_on DECLFILENAME
