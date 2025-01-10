// https://martin.hinner.info/vga/timing.html

// // 640x480 @ 60Hz standard VGA
// `define H_DISPLAY 10'd640
// `define H_R_BORDER 10'd16
// `define H_L_BORDER 10'd48
// `define H_RETRACE 10'd96
// `define H_MAX (`H_DISPLAY + `H_L_BORDER + `H_R_BORDER + `H_RETRACE - 1)
// `define START_H_RETRACE (`H_DISPLAY + `H_R_BORDER)
// `define END_H_RETRACE (`H_DISPLAY + `H_R_BORDER + `H_RETRACE - 1)

// `define V_DISPLAY 10'd480
// `define V_T_BORDER 10'd11
// `define V_B_BORDER 10'd31
// `define V_RETRACE 10'd2
// `define V_MAX (`V_DISPLAY + `V_T_BORDER + `V_B_BORDER + `V_RETRACE - 1)
// `define START_V_RETRACE (`V_DISPLAY + `V_B_BORDER)
// `define END_V_RETRACE (`V_DISPLAY + `V_B_BORDER + `V_RETRACE - 1)
// // in 25.175Mhz clock

// 640x480 @ 72Hz standard VGA
`define H_DISPLAY 10'd640
`define H_R_BORDER 10'd24
`define H_L_BORDER 10'd128
`define H_RETRACE 10'd40
`define H_MAX (`H_DISPLAY + `H_L_BORDER + `H_R_BORDER + `H_RETRACE - 1)
`define START_H_RETRACE (`H_DISPLAY + `H_R_BORDER)
`define END_H_RETRACE (`H_DISPLAY + `H_R_BORDER + `H_RETRACE - 1)

`define V_DISPLAY 10'd480
`define V_T_BORDER 10'd8
`define V_B_BORDER 10'd28
`define V_RETRACE 10'd3
`define V_MAX (`V_DISPLAY + `V_T_BORDER + `V_B_BORDER + `V_RETRACE - 1)
`define START_V_RETRACE (`V_DISPLAY + `V_B_BORDER)
`define END_V_RETRACE (`V_DISPLAY + `V_B_BORDER + `V_RETRACE - 1)
// in 31.5Mhz clock

// // 640x480 @ 75Hz standard VGA
// `define H_DISPLAY 10'd640
// `define H_R_BORDER 10'd16
// `define H_L_BORDER 10'd48
// `define H_RETRACE 10'd96
// `define H_MAX (`H_DISPLAY + `H_L_BORDER + `H_R_BORDER + `H_RETRACE - 1)
// `define START_H_RETRACE (`H_DISPLAY + `H_R_BORDER)
// `define END_H_RETRACE (`H_DISPLAY + `H_R_BORDER + `H_RETRACE - 1)

// `define V_DISPLAY 10'd480
// `define V_T_BORDER 10'd11
// `define V_B_BORDER 10'd32
// `define V_RETRACE 10'd2
// `define V_MAX (`V_DISPLAY + `V_T_BORDER + `V_B_BORDER + `V_RETRACE - 1)
// `define START_V_RETRACE (`V_DISPLAY + `V_B_BORDER)
// `define END_V_RETRACE (`V_DISPLAY + `V_B_BORDER + `V_RETRACE - 1)
// // in 31.5Mhz clock

// 128 * 5 = 640 and 96 * 5 = 480
`define BUF_WIDTH 128
`define BUF_HEIGHT 96
`define SCALE_FACTOR 5

module VGA (
    input logic clk,
    input logic VGA_clk,  // should be 31.5Mhz
    input logic rst,
    input logic [11:0] w_data,
    output logic wr_ready,

    // --- VGA ports ---
    output wire Hsync,
    output wire Vsync,
    output logic [3:0] VGA_r,
    output logic [3:0] VGA_g,
    output logic [3:0] VGA_b
);

    logic [9:0] h  /* verilator public */, v  /* verilator public */;
    logic [11:0] buf0_out[`BUF_WIDTH - 1 : 0], buf1_out[`BUF_WIDTH - 1 : 0];
    logic [9:0] w_addr;

    register #(12) line_buf0[`BUF_WIDTH - 1 : 0] (
        buf0_out,
        w_data,
        clk,
        {{(`BUF_WIDTH - 1) {1'b0}}, (wr_ready & ~w_buf)} << w_addr,
        rst
    );
    register #(12) line_buf1[`BUF_WIDTH - 1 : 0] (
        buf1_out,
        w_data,
        clk,
        {{(`BUF_WIDTH - 1) {1'b0}}, (wr_ready & w_buf)} << w_addr,
        rst
    );
    logic r_buf, w_buf;
    logic [2:0] scale_cnt;

    initial begin
        h = 10'b0;
        v = 10'b0;
    end

    wire enable = (h < `H_DISPLAY && v < `V_DISPLAY);
    assign Hsync = (h >= `START_H_RETRACE && h <= `END_H_RETRACE) & ~rst;
    assign Vsync = (v >= `START_V_RETRACE && v <= `END_V_RETRACE) & ~rst;

    always @(posedge rst, posedge VGA_clk) begin
        if (rst) begin
            h <= 10'b0;
            v <= 10'b0;
            scale_cnt <= 3'b0;
            r_buf <= 1'b0;
        end else begin
            if (enable) begin
                {VGA_r, VGA_g, VGA_b} <= r_buf ? buf0_out[h/`SCALE_FACTOR] : buf1_out[h/`SCALE_FACTOR];
            end
            if (h == `H_MAX) begin
                h <= 10'b0;
                if (scale_cnt == `SCALE_FACTOR - 1) begin
                    scale_cnt <= 3'b0;
                    r_buf <= ~r_buf;
                end else begin
                    scale_cnt <= scale_cnt + 1;
                end
                if (v + 1 == `V_MAX) v <= 10'b0;
                else v <= v + 1;
            end else h <= h + 1;
        end
    end

    always_ff @(posedge rst, posedge clk) begin
        if (rst) begin
            w_buf <= 1'b1;
            wr_ready <= 1'b1;
        end else begin
            if (wr_ready) begin
                if (w_addr == `BUF_WIDTH - 1) begin
                    wr_ready <= 1'b0;
                    w_addr <= 10'b0;
                    w_buf <= ~w_buf;
                end
                w_addr <= w_addr + 1;
            end else begin
                if (w_buf != r_buf) wr_ready <= 1'b1;
            end
        end
    end


endmodule
