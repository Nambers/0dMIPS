package configurations;
    // === SOC address config ===
    localparam KUSEG_BASE_ADDR = 64'h0000_0000_0000_0000;
    // localparam KSEG0_BASE_ADDR = 64'h8000_0000_0000_0000;
    // localparam KSEG1_BASE_ADDR = 64'hA000_0000_0000_0000;

    // === peripheral base address ===
    // --- ROM ---
    localparam RAM_BASE_ADDR = KUSEG_BASE_ADDR;  // RAM: 16MB
    localparam ROM_BASE_ADDR = RAM_BASE_ADDR + 64'h1000_0000;  // ROM: 1MB, 0x1000_0000

    /* verilator lint_off UNUSEDPARAM */
    // peripheral base address started from 0x2000_0000, every component base should be aligin by double word(8bytes)
    // and port aligned by word(4bytes)
    // --- Timer ---
    localparam TIMER_BASE_ADDR = ROM_BASE_ADDR + 64'h1000_0000; // start from 0x2000_0000
    localparam TIMER_CNT_ADDR = TIMER_BASE_ADDR;
    localparam TIMER_CRL_ADDR = TIMER_BASE_ADDR + 64'h4;
    // --- VGA ---
    localparam VGA_BASE_ADDR = TIMER_BASE_ADDR + 64'h8;
    localparam VGA_COLOR_ADDR = VGA_BASE_ADDR;
    // --- Keyboard ---
    // localparam KB_BASE_ADDR = VGA_BASE_ADDR + 64'h8;

    // === VGA config ===
    // more timing config check https://martin.hinner.info/vga/timing.html
    // 640x480 @ 72Hz standard VGA
    localparam H_DISPLAY = 10'd640;
    localparam H_R_BORDER = 10'd24;
    localparam H_L_BORDER = 10'd128;
    localparam H_RETRACE = 10'd40;
    localparam H_MAX = (H_DISPLAY + H_L_BORDER + H_R_BORDER + H_RETRACE - 1);
    localparam START_H_RETRACE = (H_DISPLAY + H_R_BORDER);
    localparam END_H_RETRACE = (H_DISPLAY + H_R_BORDER + H_RETRACE - 1);

    localparam V_DISPLAY = 10'd480;
    localparam V_T_BORDER = 10'd8;
    localparam V_B_BORDER = 10'd28;
    localparam V_RETRACE = 10'd3;
    localparam V_MAX = (V_DISPLAY + V_T_BORDER + V_B_BORDER + V_RETRACE - 1);
    localparam START_V_RETRACE = (V_DISPLAY + V_B_BORDER);
    localparam END_V_RETRACE = (V_DISPLAY + V_B_BORDER + V_RETRACE - 1);
    // in 31.5Mhz clock
    localparam SCALE_FACTOR = 5;
    /* verilator lint_on UNUSEDPARAM */

endpackage
