module barrel_shifter32_tb;
    wire [31:0] data_out;
    reg [31:0] data_in;
    reg [4:0] shift_amount;
    reg direction; // 0 for left, 1 for right
    reg clk = 0;
    always #5 clk = ~clk;

    barrel_shifter32 #(32) barrel_shifter32_(
        .data_out(data_out),
        .data_in(data_in),
        .shift_amount(shift_amount),
        .direction(direction)
    );

    initial begin
        $dumpfile("barrel_shifter32_tb.vcd");
        $dumpvars(0, barrel_shifter32_tb);

        data_in = 32'h1;
        shift_amount = 5'b0;
        direction = 1'b0;

        #10;
        data_in = 32'h1;
        shift_amount = 5'b1;

        #10;
        data_in = 32'h1;
        shift_amount = 5'd31;

        #10;
        direction = 1'b1;
        data_in = 32'b100;
        shift_amount = 5'b1;

        #10;
        $finish;
    end

    always @(posedge clk) begin
        $display("time = %02t, data_out = %b", $time, data_out);
    end
endmodule