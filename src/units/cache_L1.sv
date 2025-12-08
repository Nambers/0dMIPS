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
import structures::mem_bus_req_t;
import structures::mem_bus_resp_t;

// total cache size = CACHE_LINE_SIZE * CACHE_ENTRIES * CACHE_WAYS = 64B * 32 * 2 = 4KB
module cache_L1 #(
    parameter CACHE_LINE_SIZE = 64 * 8,  // 64 Bytes per line
    parameter CACHE_ENTRIES   = 32
) (
    input logic clock,
    input logic reset,
    input logic clear,
    input logic signed_type,
    input logic [63:0] addr  /* verilator public */,
    input logic [63:0] wdata,
    input mem_load_type_t mem_load_type,
    input mem_store_type_t mem_store_type,
    output logic [63:0] rdata,

    // L2 interface
    output mem_bus_req_t  req,
    input  mem_bus_resp_t resp
);

    localparam WIDTH = 64;
    localparam CACHE_WAYS = 2;
    localparam CACHE_WAYS_BITS = $clog2(CACHE_WAYS);

    logic [TAG_BITS-1:0] tag_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic valid_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic dirty_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic LRU_way_array[CACHE_ENTRIES-1:0];
    logic [CACHE_LINE_SIZE-1:0] data_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0] /* verilator public */;

    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE / 8);
    localparam INDEX_BITS = $clog2(CACHE_ENTRIES);
    localparam TAG_BITS = WIDTH - INDEX_BITS - OFFSET_BITS;

    logic [TAG_BITS-1:0] tag;
    logic [INDEX_BITS-1:0] index;
    logic [OFFSET_BITS-1:0] offset;

    logic [CACHE_WAYS - 1 : 0] way_hit  /* verilator public */;
    logic hit_way_idx;
    logic replace_way;
    logic dirty_wb;

    always_comb begin
        {tag, index, offset} = addr;
        way_hit = {
            valid_array[1][index] && (tag_array[1][index] == tag),
            valid_array[0][index] && (tag_array[0][index] == tag)
        };
        hit_way_idx = way_hit[1];
        replace_way = LRU_way_array[index];
        dirty_wb = valid_array[replace_way][index] && dirty_array[replace_way][index];
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            // Reset logic
            valid_array <= '{default: '{default: '0}};
            dirty_array <= '{default: '{default: '0}};
            LRU_way_array <= '{default: '0};
            rdata <= '0;
        end else if (clear) begin
            rdata <= '0;
        end else if ((|mem_load_type) || (|mem_store_type)) begin
            if (!(|way_hit)) begin
                // store dirty cache, then load new cache line
                // is will take at least 2 cycles
                if (!resp.mem_ready) begin
                    // request phase
                    // $display("%m request phase, dirty_wb = %b", dirty_wb);
                    if (dirty_wb) begin
                        req.mem_req_store <= 1'b1;
                        req.mem_req_load <= 1'b0;
                        req.mem_addr <= {tag_array[replace_way][index], index};
                        req.mem_data_out <= data_array[replace_way][index];
                    end else begin
`ifdef DEBUG
                        $display("%m request new data, addr = %h", {tag, index});
`endif
                        req.mem_req_store <= 1'b0;
                        req.mem_req_load <= 1'b1;
                        req.mem_addr <= {tag, index};
                    end
                end else begin
                    // response phase
                    $display("%m response phase, dirty_wb = %b", dirty_wb);
                    if (dirty_wb) begin
                        // write back finished
                        // `ifdef DEBUG
                        $display("%m writed back dirty cache, addr = %h, tag = %h, index = %h",
                                 req.mem_addr, tag_array[replace_way][index], index);
                        // `endif
                        dirty_array[replace_way][index] <= 1'b0;
                        req.mem_req_store <= 1'b0;
                    end else begin
                        // load new cache finished
`ifdef DEBUG
                        $display("%m: loaded new cache line, addr = %h, index = %h, data = %h",
                                 addr, index, resp.mem_data);
`endif
                        tag_array[replace_way][index] <= tag;
                        valid_array[replace_way][index] <= 1'b1;
                        dirty_array[replace_way][index] <= 1'b0;
                        data_array[replace_way][index] <= resp.mem_data;
                        req.mem_req_load <= 1'b0;
                        // TODO: eliminate duplication code
                        case (mem_load_type)
                            LOAD_BYTE: begin
                                rdata <= {
                                    {(WIDTH - 8) {resp.mem_data[offset*8+7] & signed_type}},
                                    resp.mem_data[offset*8+:8]
                                };
                            end
                            LOAD_HALF: begin
                                rdata <= {
                                    {(WIDTH - 16) {resp.mem_data[offset*8+15] & signed_type}},
                                    resp.mem_data[offset*8+:16]
                                };
                            end
                            LOAD_WORD: begin
                                rdata <= {
                                    {(WIDTH - 32) {resp.mem_data[offset*8+31] & signed_type}},
                                    resp.mem_data[offset*8+:32]
                                };
                            end
                            LOAD_DWORD: begin
                                rdata <= resp.mem_data[offset*8+:64];
                            end
                            NO_LOAD: rdata <= 'x;
                            default: rdata <= 'x;
                        endcase
                        LRU_way_array[index] <= ~replace_way;
                    end
                end
            end else begin
                case (mem_load_type)
                    LOAD_BYTE: begin
                        rdata <= {
                            {(WIDTH - 8) {data_array[hit_way_idx][index][offset*8+7] & signed_type}},
                            data_array[hit_way_idx][index][offset*8+:8]
                        };
                    end
                    LOAD_HALF: begin
                        rdata <= {
                            {(WIDTH - 16) {data_array[hit_way_idx][index][offset*8+15] & signed_type}},
                            data_array[hit_way_idx][index][offset*8+:16]
                        };
                    end
                    LOAD_WORD: begin
                        rdata <= {
                            {(WIDTH - 32) {data_array[hit_way_idx][index][offset*8+31] & signed_type}},
                            data_array[hit_way_idx][index][offset*8+:32]
                        };
                    end
                    LOAD_DWORD: begin
                        rdata <= data_array[hit_way_idx][index][offset*8+:64];
                    end
                    NO_LOAD: rdata <= 'x;
                    default: rdata <= 'x;
                endcase
                case (mem_store_type)
                    STORE_BYTE: begin
                        data_array[hit_way_idx][index][offset*8+:8] <= wdata[7:0];
                    end
                    STORE_HALF: begin
                        data_array[hit_way_idx][index][offset*8+:16] <= wdata[15:0];
                    end
                    STORE_WORD: begin
                        data_array[hit_way_idx][index][offset*8+:32] <= wdata[31:0];
                    end
                    STORE_DWORD: begin
                        data_array[hit_way_idx][index][offset*8+:64] <= wdata[63:0];
                    end
                    default: ;  // do nothing for NO_STORE
                endcase
                LRU_way_array[index] <= ~hit_way_idx;
                dirty_array[hit_way_idx][index] <= (|mem_store_type) || dirty_array[hit_way_idx][index];
`ifdef DEBUG
                $display("%0t %m try to access addr=%h, tag=%h, index=%d, offset=%h, result = %h",
                         $time, addr, tag, index, offset,
                         data_array[hit_way_idx][index][offset*8+:64]);
`endif
            end
        end else begin
            req.mem_req_load  <= 1'b0;
            req.mem_req_store <= 1'b0;
        end
    end

endmodule
