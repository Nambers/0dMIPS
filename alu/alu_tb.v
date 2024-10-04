`define ALU_ADD    3'b010
`define ALU_SUB    3'b011
`define ALU_AND    3'b100
`define ALU_OR     3'b101
`define ALU_NOR    3'b110
`define ALU_XOR    3'b111
`define WIDTH 64

module alu_tb;
    reg clk;
    reg [`WIDTH - 1:0] a, b;
    reg [2:0] alu_op;
    wire [`WIDTH - 1:0] out;
    wire negative, zero, overflow;

    alu #(
        .width(`WIDTH)
    ) alu_0(
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .out(out),
        .negative(negative),
        .zero(zero),
        .overflow(overflow)
    );

    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
        clk = 0;
        a = 0;
        b = 0;

// AU tests
        #10;
        alu_op = `ALU_ADD;
        a = 1;
        b = 2; // out = 3

        #10
        alu_op = `ALU_SUB;
        a = 3;
        b = 2; // out = 1

        #10
        a = 1;
        b = 2; // out = -1 = 0xFFFFFFFFFFFFFFFF 2's complement

// LU tests
        #10
        alu_op = `ALU_OR;
        a = 0;
        b = 64'hdeadbeefdeadbeef; // out = 0xdeadbeefdeadbeef

        #10
        alu_op = `ALU_AND;
        a = 64'hdeadbeefdeadbeef;
        b = 0; // out = 0

        #10
        alu_op = `ALU_XOR;
        a = 64'hdeadbeefdeadbeef;
        b = 64'hdeadbeefdeadbeef; // out = 0

        #10;
        $finish;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        $display("a = %h, b = %h, op = %h, out = %h, n/z/o = %b%b%b", a, b, alu_op, out, negative, zero, overflow);
    end

endmodule