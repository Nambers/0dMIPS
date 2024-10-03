module D_flip_flop (
    input wire clk,
    input wire rst,
    input wire D,
    output wire Q
);
    wire not_Q, w1, w2;
    // R = ~D & clk
    // S = D & clk

    // orignal
    // or o1(w1, ~w2, D & clk);
    // or o2(w2, Q, ~D & clk);

    // with reset (asyncnronous)
    or o1(w1, ~w2, D & clk, rst);
    or o2(w2, Q, ~D & clk & ~rst);

    assign Q = ~w1;

endmodule