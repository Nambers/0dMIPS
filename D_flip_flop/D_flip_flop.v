module D_latch (
    input wire clk,
    input wire enable,
    input wire rst,
    input wire D,
    output wire Q
);
    wire not_q, R, S;
    // R = ~D & clk
    // S = D & clk
    // if not enable, R = 0 and S = 0 to hold
    and a1(R, ~D, clk, enable, ~rst);
    and a2(S, D, clk, enable, ~rst);

    // if asyncnronous reset, R = 1, S = 0
    nor o1(Q, not_q, R, rst);
    nor o2(not_q, S, Q);
endmodule

// master-slave D flip-flop
module D_flip_flop(
    input wire clk,
    input wire rst,
    input wire enable,
    input wire D,
    output wire Q
);
    wire tmp_q;
    // load master in negedge
    D_latch master(~clk, enable, rst, D, tmp_q);
    // load slave in posedge
    D_latch slave(clk, enable, rst, tmp_q, Q);
endmodule