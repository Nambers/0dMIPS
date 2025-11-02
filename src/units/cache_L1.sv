import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
import structures::STORE_HALF;
import structures::STORE_WORD;
import structures::STORE_DWORD;
import structures::mem_load_type_t;
import structures::NO_LOAD;
import structures::LOAD_BYTE;
import structures::LOAD_HALF;
import structures::LOAD_WORD;
import structures::LOAD_DWORD;

module cache_L1 #(
    parameter CACHE_SIZE      = 1024 * 8 * 8,  // 8KB
    parameter CACHE_LINE_SIZE = 64 * 8,        // 64 Bytes per line
    parameter MEM_BUS_WIDTH   = 16 * 8         // 16 Bytes
) (
    input logic clk,
    input logic rst,
    input logic [63:0] addr,
    input logic [63:0] wdata,
    input mem_load_type_t mem_load_type,
    input mem_store_type_t mem_store_type,
    output logic [63:0] rdata,

    // L2 interface
    output mem_load_type_t next_mem_load_type,
    output mem_store_type_t next_mem_store_type,
    output logic [63:0] mem_addr,
    output logic [CACHE_LINE_SIZE-1:0] mem_wdata,
    input logic [CACHE_LINE_SIZE-1:0] mem_rdata,
    input logic mem_ready
);
    localparam WIDTH = 64;
    localparam CACHE_WAYS = 2;
    localparam CACHE_ENTRIES = CACHE_SIZE / CACHE_WAYS / CACHE_LINE_SIZE;

    logic [TAG_BITS-1:0] tag_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0];
    logic valid_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0];
    logic dirty_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0];
    logic LRU_way_array[CACHE_ENTRIES-1:0];
    logic [CACHE_LINE_SIZE-1:0] data_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0];

    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_ENTRIES);
    localparam TAG_BITS = WIDTH - INDEX_BITS - OFFSET_BITS;

    logic [TAG_BITS-1:0] tag;
    logic [INDEX_BITS-1:0] index;
    logic [OFFSET_BITS-1:0] offset;
    assign {tag, index, offset} = addr;

    logic [CACHE_WAYS - 1 : 0] way_hit;
    genvar i;
    generate
        for (i = 0; i < CACHE_WAYS; i++) begin : WAY_CHECK
            assign way_hit[i] = valid_array[i][index] && (tag_array[i][index] == tag);
        end
    endgenerate
    logic hit_way = way_hit[1];
    logic replace_way = LRU_way_array[index];

    logic hit = |way_hit;
    logic dirty_wb = valid_array[replace_way][index] && dirty_array[replace_way][index];

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            // Reset logic
            integer w, e;
            for (w = 0; w < CACHE_WAYS; w = w + 1) begin
                for (e = 0; e < CACHE_ENTRIES; e = e + 1) begin
                    valid_array[w][e] <= 1'b0;
                    dirty_array[w][e] <= 1'b0;
                end
            end
        end else begin
            if (!hit) begin
                // store dirty cache, then load new cache line
                // is will take at least 2 cycles
                if (dirty_wb) begin
                    next_mem_store_type <= STORE_DWORD;
                    mem_addr <= {tag_array[replace_way][index], index, {OFFSET_BITS{1'b0}}};
                    next_mem_load_type <= NO_LOAD;
                end else begin
                    next_mem_store_type <= NO_STORE;
                    mem_addr <= {tag, index, {OFFSET_BITS{1'b0}}};
                    next_mem_load_type <= LOAD_DWORD;
                end
                mem_wdata <= data_array[replace_way][index];
                if (mem_ready) begin
                    if (dirty_wb) begin
                        // write back finished
`ifdef DEBUG
                        $display(
                            "Cache L1: write back dirty cache, addr = %h, tag = %h, index = %h", {
                            tag_array[replace_way][index], index});
`endif
                        dirty_array[replace_way][index] <= 1'b0;
                        next_mem_store_type <= NO_STORE;
                    end else begin
                        // load new cache finished
`ifdef DEBUG
                        $display("Cache L1: load new cache line, addr = %h, index = %h", addr);
`endif
                        tag_array[replace_way][index] <= tag;
                        valid_array[replace_way][index] <= 1'b1;
                        dirty_array[replace_way][index] <= 1'b0;
                        data_array[replace_way][index] <= mem_rdata;
                        LRU_way_array[index] <= ~replace_way;
                        next_mem_load_type <= NO_LOAD;
                        // TODO: eliminate duplication code
                        case (mem_load_type)
                            LOAD_BYTE: begin
                                rdata <= {
                                    {(WIDTH - 8) {mem_rdata[offset*8+7]}}, mem_rdata[offset*8+:8]
                                };
                            end
                            LOAD_HALF: begin
                                rdata <= {
                                    {(WIDTH - 16) {mem_rdata[offset*8+15]}}, mem_rdata[offset*8+:16]
                                };
                            end
                            LOAD_WORD: begin
                                rdata <= {
                                    {(WIDTH - 32) {mem_rdata[offset*8+31]}}, mem_rdata[offset*8+:32]
                                };
                            end
                            LOAD_DWORD: begin
                                rdata <= mem_rdata[offset*8+:64];
                            end
                            NO_LOAD: rdata <= 'x;
                            default: rdata <= 'x;
                        endcase
                    end
                end
            end else begin
                case (mem_load_type)
                    LOAD_BYTE: begin
                        rdata <= {
                            {(WIDTH - 8) {data_array[hit_way][index][offset*8+7]}},
                            data_array[hit_way][index][offset*8+:8]
                        };
                    end
                    LOAD_HALF: begin
                        rdata <= {
                            {(WIDTH - 16) {data_array[hit_way][index][offset*8+15]}},
                            data_array[hit_way][index][offset*8+:16]
                        };
                    end
                    LOAD_WORD: begin
                        rdata <= {
                            {(WIDTH - 32) {data_array[hit_way][index][offset*8+31]}},
                            data_array[hit_way][index][offset*8+:32]
                        };
                    end
                    LOAD_DWORD: begin
                        rdata <= data_array[hit_way][index][offset*8+:64];
                    end
                    NO_LOAD: rdata <= 'x;
                    default: rdata <= 'x;
                endcase
                case (mem_store_type)
                    STORE_BYTE: begin
                        data_array[hit_way][index][offset*8+:8] <= wdata[7:0];
                    end
                    STORE_HALF: begin
                        data_array[hit_way][index][offset*8+:16] <= wdata[15:0];
                    end
                    STORE_WORD: begin
                        data_array[hit_way][index][offset*8+:32] <= wdata[31:0];
                    end
                    STORE_DWORD: begin
                        data_array[hit_way][index][offset*8+:64] <= wdata[63:0];
                    end
                    default: ;  // do nothing for NO_STORE
                endcase
                LRU_way_array[index] <= ~hit_way;
                dirty_array[hit_way][index] <= (mem_store_type != NO_STORE) ? 1'b1 : dirty_array[hit_way][index];
            end
        end
    end

endmodule
