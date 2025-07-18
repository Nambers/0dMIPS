module regfile #(
    parameter width = 32,
    parameter reset_value = 0
) (
    output logic [width-1:0] A_data,
    output logic [width-1:0] B_data,
    input logic [4:0] A_addr,
    input logic [4:0] B_addr,
    input logic [4:0] W_addr  /* verilator public */,
    input logic [width-1:0] W_data  /* verilator public */,
    input logic wr_enable  /* verilator public */,
    input logic clk,
    input logic reset
);
    logic [31:0][width - 1:0] reg_out;
    logic [31:0] reg_enable, reg_enable_tmp;

    barrel_shifter_left #(32) barrel_shifter32_ (
        .w5(reg_enable_tmp),
        .w0(32'b1),
        .shift_amount(W_addr)
    );

    mux2v #(32) mux2v_0 (
        reg_enable,
        32'b0,
        reg_enable_tmp,
        wr_enable
    );

    register #(width, reset_value) regs[31:0] (
        .Q(reg_out),
        .D(W_data),
        .clk(clk),
        .enable(reg_enable),
        .rst(reset)
    );

    always_comb begin
        A_data = reg_out[A_addr];
        B_data = reg_out[B_addr];
    end
endmodule
