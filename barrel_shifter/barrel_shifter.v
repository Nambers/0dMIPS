module barrel_shifter32(
    output wire [31:0] data_out,
    input wire [31:0] data_in,
    input wire [4:0] shift_amount,
    input wire direction // 0 for left, 1 for right
);

    wire [31:0] w10, w11, w20, w21, w30, w31, w40, w41, w50;

    // Stage 1: Shift by 0 or 1
    mux2v #32 mux2v_0(
        w10,
        {data_in[30:0], 1'b0},
        {1'b0, data_in[31:1]},
        direction
    );
    mux2v #32 mux2v_1(
        w11,
        data_in,
        w10,
        shift_amount[0]
    );

    // Stage 2: Shift by 0 or 2
    mux2v #32 mux2v_2(
        w20,
        {w11[29:0], 2'b0},
        {2'b0, w11[31:2]},
        direction
    );
    mux2v #32 mux2v_3(
        w21,
        w11,
        w20,
        shift_amount[1]
    );

    // Stage 3: Shift by 0 or 4
    mux2v #32 mux2v_4(
        w30,
        {w21[27:0], 4'b0},
        {4'b0, w21[31:4]},
        direction
    );
    mux2v #32 mux2v_5(
        w31,
        w21,
        w30,
        shift_amount[2]
    );

    // Stage 4: Shift by 0 or 8
    mux2v #32 mux2v_6(
        w40,
        {w31[23:0], 8'b0},
        {8'b0, w31[31:8]},
        direction
    );
    mux2v #32 mux2v_7(
        w41,
        w31,
        w40,
        shift_amount[3]
    );

    // Stage 5: Shift by 0 or 16
    mux2v #32 mux2v_8(
        w50,
        {w41[15:0], 16'b0},
        {16'b0, w41[31:16]},
        direction
    );
    mux2v #32 mux2v_9(
        data_out,
        w41,
        w50,
        shift_amount[4]
    );

endmodule
