// // verilator lint_off DECLFILENAME
// // verilator lint_off MULTITOP
// module adder (
//     output logic out,
//     output logic cout,
//     input  logic a,
//     input  logic b,
//     input  logic cin,
//     input  logic sub
// );
//     logic b_;
//     always_comb begin
//         b_   = b ^ sub;
//         // K-map
//         // a b / c | 0 | 1
//         //     0 0 |   | 1
//         //     0 1 | 1 |  
//         //     1 1 |   | 1
//         //     1 0 | 1 |  
//         // = a'b'c + a'bc' + abc + ab'c'
//         // = c(a'b' + ab) + c'(a'b + ab')
//         // = c(a Xnor b) + c'(a ^ b)
//         // = c((a ^ b)') + c'(a ^ b)
//         // = c ^ (a ^ b) = c ^ a ^ b
//         out  = a ^ b_ ^ cin;
//         // K-map
//         // a b / c | 0 | 1
//         //     0 0 |   |  
//         //     0 1 |   | 1
//         //     1 1 | 1 | 1
//         //     1 0 |   | 1
//         // = ab + bc + ac
//         cout = (a & b_) | (a & cin) | (b_ & cin);
//     end
// endmodule


module au #(
    parameter width = 32
) (
    input logic [width-1:0] a,
    input logic [width-1:0] b,
    input logic sub,
    output logic [width-1:0] out,
    output logic negative,
    output logic zero,
    output logic overflow,
    output logic borrow_out
);
    // logic [width-1:0] c_out;
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
    // logic [width-1:0] c_out;
    // adder adder_0 (
    //     .out(out[0]),
    //     .cout(c_out[0]),
    //     .a(a[0]),
    //     .b(b[0]),
    //     .cin(sub),
    //     .sub(sub)
    // );

    // genvar i;
    // generate
    //     for (i = 1; i < width; i++) begin
    //         adder adder_0 (
    //             .out(out[i]),
    //             .cout(c_out[i]),
    //             .a(a[i]),
    //             .b(b[i]),
    //             .cin(c_out[i-1]),
    //             .sub(sub)
    //         );
    //     end
    // endgenerate

    // always_comb begin
    //     negative = out[width-1];
    //     zero = ~|out;
    //     overflow = c_out[width-1] ^ c_out[width-2];
    //     borrow_out = ~c_out[width-1];
    // end

    // -- OR more compiler friendly --
    logic [  width:0] result;
    logic [width-1:0] b_eff;

    always_comb begin
        b_eff = b ^ {width{sub}};
        result = {1'b0, a} + {1'b0, b_eff} + {{width{1'b0}}, sub};

        out = result[width-1:0];
        negative = out[width-1];
        zero = ~|out;
        overflow = (a[width-1] == b_eff[width-1]) && (out[width-1] != a[width-1]);
        borrow_out = ~result[width];
    end

endmodule
