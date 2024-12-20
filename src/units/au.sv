module au #(
    parameter width = 32
) (
    input wire [width-1:0] a,
    input wire [width-1:0] b,
    input wire sub,
    output wire [width-1:0] out,
    output wire negative,
    output wire zero,
    output wire overflow
);
    wire [width-1:0] c_out;
    // adder adder_0 (
    //     .out(out[0]),
    //     .cout(c_out[0]),
    //     .a(a[0]),
    //     .b(b[0]),
    //     .cin(sub),
    //     .sub(sub)
    // );
    // adder adder_gate[width-1:1] (
    //     .out(out[width-1:1]),
    //     .cout(c_out[width-1:1]),
    //     .a(a[width-1:1]),
    //     .b(b[width-1:1]),
    //     .cin(c_out[width-2:0]),
    //     .sub(sub)
    // );

    // OR
    adder adder_0 (
        .out(out[0]),
        .cout(c_out[0]),
        .a(a[0]),
        .b(b[0]),
        .cin(sub),
        .sub(sub)
    );
    genvar i;
    generate
        for (i = 1; i < width; i++) begin
            adder adder_0 (
                .out(out[i]),
                .cout(c_out[i]),
                .a(a[i]),
                .b(b[i]),
                .cin(c_out[i-1]),
                .sub(sub)
            );
        end
    endgenerate

    assign negative = out[width-1];
    assign zero = ~|out;
    assign overflow = c_out[width-1] ^ c_out[width-2];
endmodule
