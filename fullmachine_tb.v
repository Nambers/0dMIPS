module fullmachine_test;
    /* Make a regular pulsing clock. */
    reg       clk = 0;
    always #5 clk = !clk;
    integer     i;

    reg 		reset = 1, done = 0;
    wire         except;

    full_machine fm(except, clk, reset);
    
    initial begin
        $dumpfile("fullmachine.vcd");
        $dumpvars(0, fullmachine_test); // dump all variables except memories

        # 3 reset = 0;
        # 300 done = 1;
        // this is enough time to run 30 instructions. If you need to run
        // more, change the "300" above to a more appropriate number
        $finish;
    end
   
    initial
        $monitor("At time %t, reset = %d pc = %h, inst = %h, except = %h",
                 $time, reset, fm.PC_reg.Q, fm.im.data, except);
   
endmodule // test
