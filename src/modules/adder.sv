module adder (
    output logic out,
    output logic cout,
    input  logic a,
    input  logic b,
    input  logic cin,
    input  logic sub
);
    logic b_;
    always_comb begin
        b_   = b ^ sub;
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
        out  = a ^ b_ ^ cin;
        // K-map
        // a b / c | 0 | 1
        //     0 0 |   |  
        //     0 1 |   | 1
        //     1 1 | 1 | 1
        //     1 0 |   | 1
        // = ab + bc + ac
        cout = (a & b_) | (a & cin) | (b_ & cin);
    end
endmodule
