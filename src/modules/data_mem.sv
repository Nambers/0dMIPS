import structures::mem_bus_req_t;
import structures::mem_bus_resp_t;

// data_mem: backing store for the data cache (L2 interface).
//
// The array is cache-line-wide so Vivado infers a BRAM instead of distributed
// LUT-RAM.  A 64-byte (512-bit) element per entry means one registered
// read/write per cycle - the canonical BRAM access pattern.
//
// memory.mem is cache-line addressed.  Each record is one 512-bit cache line
// with byte 0 stored in bits [7:0].

module data_mem #(
    parameter DATA_LEN        = 'h1000,  // total bytes in data segment
    parameter CACHE_LINE_SIZE = 64      // bytes per cache line
) (
    input logic clock,
    input logic reset,
    input mem_bus_req_t req,
    output mem_bus_resp_t resp
);
    localparam NUM_LINES      = DATA_LEN / CACHE_LINE_SIZE;
    localparam LINE_ADDR_BITS = $clog2(NUM_LINES);

    logic [LINE_ADDR_BITS-1:0] line_addr;

    always_comb begin
        assert (!(req.mem_req_load && req.mem_req_store))
        else $fatal("data_mem: simultaneous load and store");
        assert (!(req.mem_req_load || req.mem_req_store) || req.mem_addr < NUM_LINES)
        else $fatal("data_mem: line address out of bounds: %h", req.mem_addr);

        // cache_L1 already strips the intra-line byte offset before driving
        // mem_addr, so this bus carries addr[63:6], not a byte address.
        line_addr = req.mem_addr[LINE_ADDR_BITS-1:0];
    end

    // Intermediate registers so each always_ff block drives exactly one signal.
    // resp is then assembled in always_comb, silencing MULTIDRIVEN warnings.
    logic [CACHE_LINE_SIZE*8-1:0] resp_data_r;
    logic resp_ready_r;

    // Vivado uses the official XPM.  Verilator uses the local narrow
    // xpm_memory_sdpram model in xpm_memory_sdpram_verilator.sv.
    //
    // XPM also lets Vivado write_mem_info emit an .mmi file for
    // updatemem-based bitstream patching.
    xpm_memory_sdpram #(
        .MEMORY_SIZE       (DATA_LEN * 8),
        .MEMORY_PRIMITIVE  ("block"),
        .CLOCKING_MODE     ("common_clock"),
        .MEMORY_INIT_FILE  ("memory.mem"),
        .USE_MEM_INIT      (1),
        .USE_MEM_INIT_MMI  (1),
        .WRITE_DATA_WIDTH_A(CACHE_LINE_SIZE * 8),
        .READ_DATA_WIDTH_B (CACHE_LINE_SIZE * 8),
        .BYTE_WRITE_WIDTH_A(CACHE_LINE_SIZE * 8),
        .ADDR_WIDTH_A      (LINE_ADDR_BITS),
        .ADDR_WIDTH_B      (LINE_ADDR_BITS),
        .READ_LATENCY_B    (1),
        .WRITE_MODE_B      ("read_first")
    ) data_seg_xpm (
        .sleep         (1'b0),
        .clka          (clock),
        .ena           (req.mem_req_store),
        .wea           (req.mem_req_store),
        .addra         (line_addr),
        .dina          (req.mem_data_out),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .clkb          (clock),
        .rstb          (1'b0),
        .enb           (req.mem_req_load),
        .regceb        (1'b1),
        .addrb         (line_addr),
        .doutb         (resp_data_r),
        .sbiterrb      (),
        .dbiterrb      ()
    );

    // mem_ready in its own flop so it can have an async reset without
    // preventing BRAM inference on the array above.
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            resp_ready_r <= 1'b0;
        end else begin
            resp_ready_r <= req.mem_req_load | req.mem_req_store;
        end
    end

    always_comb begin
        resp.mem_data  = resp_data_r;
        resp.mem_ready = resp_ready_r;
    end

endmodule  // data_mem
