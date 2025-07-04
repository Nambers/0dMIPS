// verilator lint_off DECLFILENAME
// verilator lint_off MULTITOP
module barrel_shifter_left #(
    parameter WIDTH = 32
) (
    output logic [WIDTH-1:0] w5,
    input  logic [WIDTH-1:0] w0,
    input  logic [      4:0] shift_amount
);

    logic [WIDTH-1:0] w1, w2, w3, w4;

    mux2v #(WIDTH) mux_l1 (
        w1,
        w0,
        {w0[WIDTH-2:0], 1'b0},
        shift_amount[0]
    );
    mux2v #(WIDTH) mux_l2 (
        w2,
        w1,
        {w1[WIDTH-3:0], 2'b0},
        shift_amount[1]
    );
    mux2v #(WIDTH) mux_l4 (
        w3,
        w2,
        {w2[WIDTH-5:0], 4'b0},
        shift_amount[2]
    );
    mux2v #(WIDTH) mux_l8 (
        w4,
        w3,
        {w3[WIDTH-9:0], 8'b0},
        shift_amount[3]
    );
    mux2v #(WIDTH) mux_l16 (
        w5,
        w4,
        {w4[WIDTH-17:0], 16'b0},
        shift_amount[4]
    );
endmodule

module barrel_shifter_right #(
    parameter WIDTH = 32
) (
    output logic [WIDTH-1:0] w5,
    input  logic [WIDTH-1:0] w0,
    input  logic [      4:0] shift_amount,
    input  logic             arithmetic
);

    logic [WIDTH-1:0] w1, w2, w3, w4, r1_final, r2_final, r4_final, r8_final, r16_final;

    mux2v #(WIDTH) mux_r1_sel (
        r1_final,
        {1'b0, w0[WIDTH-1:1]},
        {w0[WIDTH-1], w0[WIDTH-1:1]},
        arithmetic
    );
    mux2v #(WIDTH) mux_r1 (
        w1,
        w0,
        r1_final,
        shift_amount[0]
    );

    mux2v #(WIDTH) mux_r2_sel (
        r2_final,
        {2'b0, w1[WIDTH-1:2]},
        {{2{w1[WIDTH-1]}}, w1[WIDTH-1:2]},
        arithmetic
    );
    mux2v #(WIDTH) mux_r2 (
        w2,
        w1,
        r2_final,
        shift_amount[1]
    );

    mux2v #(WIDTH) mux_r4_sel (
        r4_final,
        {4'b0, w2[WIDTH-1:4]},
        {{4{w2[WIDTH-1]}}, w2[WIDTH-1:4]},
        arithmetic
    );
    mux2v #(WIDTH) mux_r4 (
        w3,
        w2,
        r4_final,
        shift_amount[2]
    );

    mux2v #(WIDTH) mux_r8_sel (
        r8_final,
        {8'b0, w3[WIDTH-1:8]},
        {{8{w3[WIDTH-1]}}, w3[WIDTH-1:8]},
        arithmetic
    );
    mux2v #(WIDTH) mux_r8 (
        w4,
        w3,
        r8_final,
        shift_amount[3]
    );

    mux2v #(WIDTH) mux_r16_sel (
        r16_final,
        {16'b0, w4[WIDTH-1:16]},
        {{16{w4[WIDTH-1]}}, w4[WIDTH-1:16]},
        arithmetic
    );
    mux2v #(WIDTH) mux_r16 (
        w5,
        w4,
        r16_final,
        shift_amount[4]
    );
endmodule

module barrel_shifter32 #(
    parameter WIDTH = 32
) (
    output logic [WIDTH-1:0] data_out,
    input  logic [WIDTH-1:0] data_in,
    input  logic [      4:0] shift_amount,
    input  logic             direction,     // 0 = left, 1 = right
    input  logic             arithmetic
);

    logic [WIDTH-1:0] left_result, right_result;

    barrel_shifter_left #(WIDTH) u_left (
        .w5(left_result),
        .w0(data_in),
        .shift_amount(shift_amount)
    );

    barrel_shifter_right #(WIDTH) u_right (
        .w5(right_result),
        .w0(data_in),
        .shift_amount(shift_amount),
        .arithmetic(arithmetic)
    );

    mux2v #(WIDTH) final_mux (
        .out(data_out),
        .a  (left_result),
        .b  (right_result),
        .sel(direction)
    );
endmodule
// verilator lint_on MULTITOP
// verilator lint_on DECLFILENAME
