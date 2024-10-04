`define WIDTH 64

module regfile_tb;
    wire [`WIDTH-1:0] A_data;
    wire [`WIDTH-1:0] B_data;
    reg [4:0] A_addr = 5'b00000;
    reg [4:0] B_addr = 5'b00000;
    reg [4:0] W_addr = 5'b00000;
    reg [`WIDTH-1:0] W_data;
    reg wr_enable;
    reg clk = 0;
    reg reset;

    always #5 clk = ~clk;

    regfile #(
        .width(`WIDTH)
    ) regfile_(
        .A_data(A_data),
        .B_data(B_data),
        .A_addr(A_addr),
        .B_addr(B_addr),
        .W_addr(W_addr),
        .W_data(W_data),
        .wr_enable(wr_enable),
        .clk(clk),
        .reset(reset)
    );

    integer i;

    initial begin
        $dumpfile("regfile_tb.vcd");
        $dumpvars(0, regfile_tb);
        reset = 1;
        wr_enable = 1;
        W_data = `WIDTH'hdeadbeef; // write to 0
        
        #10 reset = 0;

        #10 W_data = `WIDTH'hcafebabe;
        W_addr = 32'h15;
        A_addr = 32'h15; // check result

        #10 wr_enable = 0;
        W_addr = 32'h14;
        W_data = `WIDTH'hFFFF; // not write
        B_addr = 32'h14; // check result

        #10;
        $finish;
    end

    always @(posedge clk) begin
        $display("time = %02t, A_data(%h) = %h, B_data(%h) = %h, try to write R(%h) <= %h, enable = %b", $time, A_addr, A_data, B_addr, B_data, W_addr, W_data, wr_enable);
    end
endmodule