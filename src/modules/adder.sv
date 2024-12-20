module adder(
    output wire out,
    output wire cout,
    input wire a,
    input wire b,
    input wire cin,
    input wire sub
);
    wire b_ = b ^ sub;
    // K-map
    // a b / c | 0 | 1
    //     0 0 |   | 1
    //     0 1 | 1 |  
    //     1 1 |   | 1
    //     1 0 | 1 |  
    // = a'b'c + a'bc' + abc + ab'c'
    // = c(a'b' + ab) + c'(a'b + ab')
    // = c(a Xnor b) + c'(a ^ b)
    // = c((a ^ b)') + c'(a ^ b)
    // = c ^ (a ^ b) = c ^ a ^ b
    assign out = a ^ b_ ^ cin;
    // K-map
    // a b / c | 0 | 1
    //     0 0 |   |  
    //     0 1 |   | 1
    //     1 1 | 1 | 1
    //     1 0 |   | 1
    // = ab + bc + ac
    assign cout = (a & b_) | (a & cin) | (b_ & cin);

endmodule
