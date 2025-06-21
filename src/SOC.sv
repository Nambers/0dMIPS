import structures::mem_store_type_t;
import configurations::PERIPHERAL_BASE;

module SOC (
    input logic clk,
    input logic VGA_clk,
    input logic reset,

    // -- VGA --
    output logic [3:0] VGA_r,
    output logic [3:0] VGA_g,
    output logic [3:0] VGA_b,
    output logic Hsync,
    output logic Vsync
);
    logic [63:0] d_addr /* verilator public */, d_wdata, d_rdata, timer_out;
    logic [7:0] interrupt_sources /* verilator public */;
    mem_store_type_t d_store_type;
    logic
        d_valid /* verilator public */, d_ready, timer_taken, timer_interrupt, VGA_taken, stdout_taken;

    assign interrupt_sources = {timer_interrupt, 7'b0};

    core #(PERIPHERAL_BASE) core (
        .clock(clk),
        .reset(reset),
        .d_addr(d_addr),
        .d_wdata(d_wdata),
        .d_rdata(d_rdata),
        .d_store_type(d_store_type),
        .d_valid(d_valid),
        .d_ready(d_ready),
        .interrupt_sources(interrupt_sources)
    );

    timer timer (
        .TimerInterrupt(timer_interrupt),
        .cycle(timer_out),
        .TimerAddress(timer_taken),
        .data(d_wdata),
        .address(d_addr),
        .MemRead(d_valid & (~(|d_store_type))),
        .MemWrite(d_valid & (|d_store_type)),
        .clock(clk),
        .reset(reset)
    );

    VGA vga (
        .clk(clk),
        .VGA_clk(VGA_clk),
        .rst(reset),
        .wr_enable(|d_store_type),
        .addr(d_addr),
        .w_data(d_wdata[31:0]),
        .VGA_taken(VGA_taken),
        .Hsync(Hsync),
        .Vsync(Vsync),
        .VGA_r(VGA_r),
        .VGA_g(VGA_g),
        .VGA_b(VGA_b)
    );

    stdout stdout (
        .clock(clk),
        .reset(reset),
        .addr(d_addr),
        .mem_store_type(d_store_type),
        .w_data(d_wdata),
        .stdout_taken(stdout_taken)
    );

    always_comb begin
        unique case (1'b1)
            timer_taken & ~reset: d_rdata = timer_out;
            default: d_rdata = 'z;
        endcase
    end

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            d_ready <= '0;
        end else begin
            d_ready <= d_valid & (timer_taken | VGA_taken | stdout_taken);
        end
    end

endmodule
