import configurations::H_DISPLAY;
import configurations::V_DISPLAY;
import configurations::SCALE_FACTOR;
import configurations::H_MAX;
import configurations::V_MAX;
import configurations::START_H_RETRACE;
import configurations::END_H_RETRACE;
import configurations::START_V_RETRACE;
import configurations::END_V_RETRACE;
import configurations::VGA_COLOR_ADDR;

// use `sd` to write color to VGA buffer
// {42'b0, 10'bY, 10'bX, 12'bcolor}
// x,y are after scaled
module VGA (
    input logic clk,
    input logic VGA_clk,  // should be 31.5Mhz
    input logic rst,
    input logic wr_enable,
    input logic [63:0] addr,
    input logic [31:0] w_data,
    output logic VGA_taken,

    // --- VGA ports ---
    output wire Hsync,
    output wire Vsync,
    output logic [3:0] VGA_r,
    output logic [3:0] VGA_g,
    output logic [3:0] VGA_b
);
    // TODO maybe static assert % SCALE_FACTOR == 0
    localparam BUF_WIDTH = H_DISPLAY / SCALE_FACTOR;
    localparam BUF_HEIGHT = V_DISPLAY / SCALE_FACTOR;
    logic [11:0]
        frame_buf0[BUF_WIDTH * BUF_HEIGHT - 1:0],
        frame_buf1[BUF_WIDTH * BUF_HEIGHT - 1:0];
    // horizontal and vertical cnt
    logic [9:0] h  /* verilator public */, v  /* verilator public */;
    logic w_buf;

    initial begin
        h = 10'b0;
        v = 10'b0;
    end

    wire VGA_enable = (h < H_DISPLAY && v < V_DISPLAY);
    wire [11:0] w_color = w_data[11:0];
    wire [9:0] w_x = w_data[21:12];
    wire [13:0] read_index = ({4'b0, h} / SCALE_FACTOR) + ({4'b0,v} / SCALE_FACTOR) * BUF_WIDTH;
    wire [9:0] w_y = w_data[31:22];
    assign Hsync = (h >= START_H_RETRACE && h <= END_H_RETRACE) & ~rst;
    assign Vsync = (v >= START_V_RETRACE && v <= END_V_RETRACE) & ~rst;

    always @(posedge rst, posedge VGA_clk) begin
        if (rst) begin
            h <= 10'b0;
            v <= 10'b0;
        end else begin
            if (VGA_enable) begin
                {VGA_r, VGA_g, VGA_b} <= (~w_buf) ? frame_buf0[read_index] : frame_buf1[read_index];
            end
            if (h == H_MAX) begin
                h <= 10'b0;
                if (v + 1 == V_MAX) v <= 10'b0;
                else v <= v + 1;
            end else h <= h + 1;
            if (Vsync) w_buf <= ~w_buf;
        end
    end

    always_ff @(posedge rst, posedge clk) begin
        if (rst) begin
            VGA_taken <= 1'b0;
        end else begin
            if (wr_enable & (addr == VGA_COLOR_ADDR)) begin
                if (w_buf) frame_buf0[w_y*BUF_WIDTH+w_x] <= w_color;
                else frame_buf1[w_y*BUF_WIDTH+w_x] <= w_color;
                VGA_taken <= 1;
            end else begin
                VGA_taken <= 0;
            end
        end
    end


endmodule
