module D_flip_flop_tb;

    reg clk;
    reg d;
    wire q;
    reg rst;

    D_flip_flop uut (
        .clk(clk),
        .rst(rst),
        .D(d),
        .Q(q)
    );

    initial begin
        $dumpfile("D_flip_flop_tb.vcd");
        $dumpvars(0, D_flip_flop_tb);
        clk = 0;
        rst = 1;
        d = 0;

        #10
        rst = 0;

        #10;
        d = 1;

        #10;
        d = 0;

        #10;
        d = 1;

        #10;
        $finish;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        $display("q = %b", q);
    end

endmodule