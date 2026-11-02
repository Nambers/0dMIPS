// Simulation-only top for the SoC harnesses. Kept outside src/ on purpose:
// the Vivado project generator adds src/ recursively.
//
// Everything the C++ harnesses observe is a named top-level port driven by a
// hierarchical reference, so they never depend on Verilator's generated
// class/member layout or on hand-computed packed-struct bit offsets, and the
// SoC is verilated with --public-ignore (RTL `public` markings are only for the
// unit tests). Bulk state (register file, caches, memory) is read through the
// DPI inspectors in soc_inspect.sv.
//
// To observe something new: add an output port here and drive it below.
module soc_tb (
    input logic sys_clk,
`ifdef VGA_ENABLED
    input  logic       VGA_clk,
    output logic [3:0] VGA_r,
    output logic [3:0] VGA_g,
    output logic [3:0] VGA_b,
    output logic       Hsync,
    output logic       Vsync,
    output logic [9:0] probe_vga_h,
    output logic [9:0] probe_vga_v,
`endif
`ifdef LED_ENABLED
    output logic [3:0] led,
`endif
    input logic sys_rst_n,

    // -- pc / instruction held in each stage's input register --
    output logic [63:0] probe_ID_pc,    // IF_regs.fetch_pc: the PC the sims print
    output logic [31:0] probe_ID_inst,
    output logic [63:0] probe_EX_pc,    // ID_regs
    output logic [31:0] probe_EX_inst,
`ifdef DEBUGGER
    // EX_regs / MEM_regs only carry pc and inst when DEBUGGER is defined
    output logic [63:0] probe_MEM_pc,
    output logic [31:0] probe_MEM_inst,
    output logic [63:0] probe_WB_pc,
    output logic [31:0] probe_WB_inst,
`endif

    // -- memory access in MEM1 (EX_regs) --
    output structures::mem_load_type_t  probe_MEM_load_type,
    output structures::mem_store_type_t probe_MEM_store_type,
    output logic [63:0]                 probe_MEM_addr,

    // -- control --
    output logic                      probe_reset,
    output logic                      probe_stall,
    output logic                      probe_flush,
    output logic                      probe_inst_cache_miss_stall,
    output logic                      probe_data_cache_miss_stall,
    output structures::forward_type_t probe_forward_A,
    output structures::forward_type_t probe_forward_B,
    output logic [4:0]                probe_exc_code,
    output logic [7:0]                probe_interrupt_sources,

    // -- peripheral (MMIO) port --
    output logic        probe_d_valid,
    output logic        probe_d_ready,
    output logic [63:0] probe_d_addr,
    output logic [63:0] probe_d_wdata,
    output logic [63:0] probe_d_rdata,

    // -- memory bus between the L1 caches and data_mem --
    output logic        probe_bus_load,
    output logic        probe_bus_store,
    output logic [63:0] probe_bus_addr,   // byte address of the requested line

    // -- L1 caches: address being looked up and the ways that hit --
    output logic [63:0] probe_icache_addr,
    output logic [1:0]  probe_icache_way_hit,
    output logic [63:0] probe_dcache_addr,
    output logic [1:0]  probe_dcache_way_hit,

    // -- peripherals --
    output logic [63:0] probe_timer_cycle,
    output logic        probe_stdout_taken,
    output logic [63:0] probe_stdout_buffer
);
    SOC dut (
        .sys_clk(sys_clk),
`ifdef VGA_ENABLED
        .VGA_clk(VGA_clk),
        .VGA_r  (VGA_r),
        .VGA_g  (VGA_g),
        .VGA_b  (VGA_b),
        .Hsync  (Hsync),
        .Vsync  (Vsync),
`endif
`ifdef LED_ENABLED
        .led(led),
`endif
        .sys_rst_n(sys_rst_n)
    );

    assign probe_ID_pc          = dut.core.IF_regs.fetch_pc;
    assign probe_ID_inst        = dut.core.IF_regs.inst;
    assign probe_EX_pc          = dut.core.ID_regs.pc;
    assign probe_EX_inst        = dut.core.ID_regs.inst;
`ifdef DEBUGGER
    assign probe_MEM_pc         = dut.core.EX_regs.pc;
    assign probe_MEM_inst       = dut.core.EX_regs.inst;
    assign probe_WB_pc          = dut.core.MEM_regs.pc;
    assign probe_WB_inst        = dut.core.MEM_regs.inst;
`endif

    assign probe_MEM_load_type  = dut.core.EX_regs.mem_load_type;
    assign probe_MEM_store_type = dut.core.EX_regs.mem_store_type;
    assign probe_MEM_addr       = dut.core.EX_regs.out;

    assign probe_reset                 = dut.reset;
    assign probe_stall                 = dut.core.stall;
    assign probe_flush                 = dut.core.flush;
    assign probe_inst_cache_miss_stall = dut.core.IF_stage.inst_cache_miss_stall;
    assign probe_data_cache_miss_stall = dut.core.data_cache_miss_stall;
    assign probe_forward_A             = dut.core.forward_A;
    assign probe_forward_B             = dut.core.forward_B;
    assign probe_exc_code              = dut.core.MEM_stage.cp0_.exc_code;
    assign probe_interrupt_sources     = dut.interrupt_sources;

    assign probe_d_valid = dut.d_valid;
    assign probe_d_ready = dut.d_ready;
    assign probe_d_addr  = dut.d_addr;
    assign probe_d_wdata = dut.d_wdata;
    assign probe_d_rdata = dut.d_rdata;

    assign probe_bus_load  = dut.mem_bus_req.mem_req_load;
    assign probe_bus_store = dut.mem_bus_req.mem_req_store;
    assign probe_bus_addr  = {dut.mem_bus_req.mem_addr, 6'b0};

    assign probe_icache_addr    = dut.core.IF_stage.inst_cache.addr;
    assign probe_icache_way_hit = dut.core.IF_stage.inst_cache.way_hit;
    assign probe_dcache_addr    = dut.core.MEM_stage.data_cache.addr;
    assign probe_dcache_way_hit = dut.core.MEM_stage.data_cache.way_hit;

    assign probe_timer_cycle   = dut.timer.cycle_D;
    assign probe_stdout_taken  = dut.stdout.stdout_taken;
    assign probe_stdout_buffer = dut.stdout.buffer;
`ifdef VGA_ENABLED
    assign probe_vga_h = dut.vga.h;
    assign probe_vga_v = dut.vga.v;
`endif
endmodule
