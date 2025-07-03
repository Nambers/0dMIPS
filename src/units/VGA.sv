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

module VGA (
    input logic clk,
    input logic VGA_clk,  // should be 31.5Mhz
    input logic rst,
    input logic wr_enable,
    input logic [63:0] addr,
    input logic [31:0] w_data,
    // last input is written
    output logic VGA_taken,

    // --- VGA ports ---
    output logic Hsync,
    output logic Vsync,
    output logic [3:0] VGA_r,
    output logic [3:0] VGA_g,
    output logic [3:0] VGA_b
);
    localparam BUF_WIDTH = H_DISPLAY / SCALE_FACTOR;
    localparam BUF_HEIGHT = V_DISPLAY / SCALE_FACTOR;

    // double buffers for write and display
    logic [11:0] frame_buf0[BUF_WIDTH * BUF_HEIGHT - 1:0], frame_buf1[BUF_WIDTH * BUF_HEIGHT - 1:0];

    // display counters
    logic [9:0] h  /* verilator public */, v  /* verilator public */;

    // double buffer control
    logic display_buf;  // curr display buffer
    logic write_buf;  // curr write buffer

    logic display_buf_sync1, display_buf_sync2;

    logic VGA_enable;

    logic [11:0] w_color;
    logic [9:0] w_x;
    logic [9:0] w_y;
    logic [13:0] read_index;

    initial begin
        h = 10'b0;
        v = 10'b0;
        display_buf = 1'b0;
        write_buf = 1'b1;
    end

    always_comb begin
        VGA_enable = (h < H_DISPLAY && v < V_DISPLAY);

        w_color = w_data[11:0];
        w_x = w_data[21:12];
        w_y = w_data[31:22];

        read_index = ({4'b0, h} / SCALE_FACTOR) + ({4'b0, v} / SCALE_FACTOR) * BUF_WIDTH;

        Hsync = (h >= START_H_RETRACE && h <= END_H_RETRACE);
        Vsync = (v >= START_V_RETRACE && v <= END_V_RETRACE);
    end

    // display control
    always_ff @(posedge VGA_clk or posedge rst) begin
        if (rst) begin
            h <= 10'b0;
            v <= 10'b0;
            display_buf <= 1'b0;
            {VGA_r, VGA_g, VGA_b} <= 12'h000;  // init to black
        end else begin
            if (VGA_enable) begin
                {VGA_r, VGA_g, VGA_b} <= display_buf ? frame_buf1[read_index] : frame_buf0[read_index];
            end else begin
                {VGA_r, VGA_g, VGA_b} <= 12'h000;
            end

            if (h == H_MAX) begin
                h <= 10'b0;
                if (v == V_MAX) begin
                    v <= 10'b0;
                end else begin
                    v <= v + 1;
                end

                if (v == V_DISPLAY - 1) begin
                    display_buf <= ~display_buf;
                end
            end else begin
                h <= h + 1;
            end
        end
    end

    // write control
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            display_buf_sync1 <= 1'b0;
            display_buf_sync2 <= 1'b0;
            VGA_taken <= 1'b0;
            write_buf <= 1'b1;
        end else begin
            // sync buffer
            display_buf_sync1 <= display_buf;
            display_buf_sync2 <= display_buf_sync1;

            write_buf <= ~display_buf_sync2;

            VGA_taken <= wr_enable & (addr == VGA_COLOR_ADDR);

            if (wr_enable && (addr == VGA_COLOR_ADDR)) begin
                if (write_buf) begin
                    frame_buf1[w_y*BUF_WIDTH+w_x] <= w_color;
                end else begin
                    frame_buf0[w_y*BUF_WIDTH+w_x] <= w_color;
                end
            end
        end
    end

endmodule
