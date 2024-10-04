`define WIDTH 32

module register_tb;

    reg clk = 0;
    reg [`WIDTH - 1:0] d;
    wire [`WIDTH - 1:0] q;
    reg enable;
    reg rst;

    register #(
        .width(`WIDTH)
    ) uut (
        .clk(clk),
        .enable(enable),
        .rst(rst),
        .D(d),
        .Q(q)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("register_tb.vcd");
        $dumpvars(0, register_tb);
        enable = 1;
        rst = 1;
        d = `WIDTH'b0;

        #10 rst = 0;

        #10 d = `WIDTH'h2; // q = 2

        #10 enable = 0;
        d = 0; // q = 2

        #10 enable = 1;
        d = `WIDTH'h3; // q = 3

        #20;
        $finish;
    end

    always @(posedge clk) begin
        $display("time = %2t, q = %h", $time, q);
    end
endmodule