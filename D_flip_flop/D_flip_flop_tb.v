module D_flip_flop_tb;

    reg clk = 0;
    reg d;
    wire q;
    reg rst;
    reg enable;

    D_flip_flop uut (
        .clk(clk),
        .enable(enable),
        .rst(rst),
        .D(d),
        .Q(q)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("D_flip_flop_tb.vcd");
        $dumpvars(0, D_flip_flop_tb);

        rst = 1; enable = 1; d = 0;
        #10 rst = 0;

        #10 d = 1;
        #10 d = 0;
        #10 d = 1;

        #10 enable = 0;
        #10 d = 0;
        #10 enable = 1;
        #10 d = 1;

        #10 rst = 1;
        #5 rst = 0;

        #10 $finish;
    end

    // 监视输出
    always @(posedge clk) 
        $display("Time=%02t: clk=%b, rst=%b, enable=%b, d=%b, q=%b", 
                 $time, clk, rst, enable, d, q);

endmodule
