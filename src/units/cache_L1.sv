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
import structures::cache_ops_t;
import structures::WB_INVALIDATE;

// total cache size = CACHE_LINE_SIZE * CACHE_ENTRIES * CACHE_WAYS = 64B * 32 * 2 = 4KB
module cache_L1 #(
    parameter CACHE_LINE_SIZE = 64 * 8,  // 64 Bytes per line
    parameter CACHE_ENTRIES   = 32
) (
    input logic clock,
    input logic reset,
    input logic enable,
    input logic clear,
    input logic signed_type,
    input logic [63:0] addr  /* verilator public */,
    input logic [63:0] wdata,
    input mem_load_type_t mem_load_type,
    input mem_store_type_t mem_store_type,
    input logic cache_inst,
    input cache_ops_t cache_op,
    output logic [63:0] rdata,
    output logic miss,

    // L2 interface
    output mem_bus_req_t  req,
    input  mem_bus_resp_t resp
);

    localparam WIDTH = 64;
    localparam CACHE_WAYS = 2;
    localparam CACHE_WAYS_BITS = $clog2(CACHE_WAYS);

    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE / 8);
    localparam INDEX_BITS = $clog2(CACHE_ENTRIES);
    localparam TAG_BITS = WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE = CACHE_LINE_SIZE / WIDTH; // number of WIDTH-bit words per cache line

    logic [TAG_BITS-1:0] tag_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic valid_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic dirty_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic LRU_way_array[CACHE_ENTRIES-1:0];
    // data_bank_rd[way][word]: async-read outputs of the per-bank RAMs (synthesis)
    // or wired from data_array (Verilator).  All reads in the main always_ff go here.
    logic [WIDTH-1:0] data_bank_rd[CACHE_WAYS-1:0][WORDS_PER_LINE-1:0];
    logic [INDEX_BITS-1:0] rd_index;  // read address: index for normal ops, addr[...] for cache_inst
    logic do_fill;       // write-enable: L2 fill  (loading a new cache line)
    logic do_hit_store;  // write-enable: hit store (store to a present line)

    logic [TAG_BITS-1:0] tag;
    logic [INDEX_BITS-1:0] index;
    logic [OFFSET_BITS-1:0] offset;
    logic [$clog2(WORDS_PER_LINE)-1:0] word_idx; // which WIDTH-bit word in the cache line
    logic [2:0] byte_idx;                         // byte offset within that WIDTH-bit word

    logic [CACHE_WAYS - 1 : 0] way_hit  /* verilator public */;
    logic hit_way_idx;
    logic replace_way;
    logic dirty_wb;

    // Precomputed byte write-enables: static-index loop in always_ff can then
    // write data_array[w][way][index][b*8+:8] where both w and b are compile-time
    // constants, satisfying Vivado's BRAM / distributed-RAM byte-enable inference.
    logic [7:0] byte_wr_en;
    // Store data shifted to the byte position in the cache word so that lane b
    // in the static byte-enable loop always receives the correct data byte.
    // E.g. for SW at byte_idx=4: wdata[31:0] lands at wdata_aligned[63:32].
    logic [WIDTH-1:0] wdata_aligned;

    always_comb begin
        {tag, index, offset} = addr;
        word_idx = offset[OFFSET_BITS-1:3]; // top bits: select WIDTH-bit word in line
        byte_idx = offset[2:0];             // bottom 3 bits: byte within WIDTH-bit word
        way_hit = {
            valid_array[1][index] && (tag_array[1][index] == tag),
            valid_array[0][index] && (tag_array[0][index] == tag)
        };
        hit_way_idx = way_hit[1];
        replace_way = LRU_way_array[index];
        dirty_wb = valid_array[replace_way][index] && dirty_array[replace_way][index];
        miss = (|mem_load_type || |mem_store_type) && !(|way_hit);

        // Decode mem_store_type + byte_idx into a byte-lane enable vector.
        // This is purely combinatorial; the static loop index b in always_ff
        // turns each lane into an independent, single-bit write enable.
        case (mem_store_type)
            STORE_BYTE:  byte_wr_en = 8'h01 << byte_idx;
            STORE_HALF:  byte_wr_en = 8'h03 << {byte_idx[2:1], 1'b0};
            STORE_WORD:  byte_wr_en = 8'h0f << {byte_idx[2], 2'b0};
            STORE_DWORD: byte_wr_en = 8'hff;
            default:     byte_wr_en = 8'h00;
        endcase
        // Shift store data into position so wdata_aligned[b*8+:8] gives the
        // correct byte for cache-word lane b.
        wdata_aligned = wdata << ({byte_idx, 3'b0});

        // Read address for data banks: cache_inst uses addr low bits as set index.
        rd_index     = cache_inst ? addr[INDEX_BITS-1:0] : index;
        // Write-enable pulses consumed by the per-bank storage block below.
        do_fill      = !reset && !cache_inst && !clear && enable
                       && (|mem_load_type || |mem_store_type)
                       && !(|way_hit) && resp.mem_ready && !dirty_wb;
        do_hit_store = !reset && !cache_inst && !clear && enable
                       && (|mem_store_type) && (|way_hit);
    end

    // -----------------------------------------------------------------------
    // Data storage.
    //   Synthesis (`ifndef VERILATOR): WORDS_PER_LINE × CACHE_WAYS independent
    //     1-D distributed LUT-RAMs, each indexed only by `index`.
    //     Vivado infers ~16 × 32-deep × 64-bit RAMs per instance instead of
    //     65 K FFs + mux trees that the 3-D declaration previously forced.
    //    (`ifdef VERILATOR): flat 3-D array preserves the existing
    //     C++ test interface (data_array[word][way][entry]) unchanged.
    // -----------------------------------------------------------------------
//`ifndef VERILATOR
    genvar gway, gw;
    generate
        for (gway = 0; gway < CACHE_WAYS; gway++) begin : gbw
            for (gw = 0; gw < WORDS_PER_LINE; gw++) begin : gbg
                (* ram_style = "block" *) logic [WIDTH-1:0] d[0:CACHE_ENTRIES-1];
                // Async read: output captured by the main always_ff when forming rdata.
                assign data_bank_rd[gway][gw] = d[rd_index];
                always_ff @(posedge clock) begin
                    // Fill: gw*WIDTH is a compile-time constant → static part-select.
                    if (do_fill && (replace_way == gway))
                        d[index] <= resp.mem_data[gw*WIDTH+:WIDTH];
                    // Hit store: gway/gw are genvar constants, so (hit_way_idx==gway)
                    // and (word_idx==gw) synthesise as static bank-select decode logic.
                    else if (do_hit_store && (hit_way_idx == gway) && (word_idx == gw))
                        for (int b = 0; b < 8; b++)
                            if (byte_wr_en[b]) d[index][b*8+:8] <= wdata_aligned[b*8+:8];
                end
            end
        end
    endgenerate
//`else
//    //  3-D array keeps C++ test access (data_array[word][way][entry]).
//    logic [WIDTH-1:0] data_array[WORDS_PER_LINE-1:0][CACHE_WAYS-1:0][CACHE_ENTRIES-1:0] /* verilator public */;
//    always_comb begin
//        for (int g = 0; g < CACHE_WAYS; g++)
//            for (int w = 0; w < WORDS_PER_LINE; w++)
//                data_bank_rd[g][w] = data_array[w][g][rd_index];
//    end
//    always_ff @(posedge clock) begin
//        if (do_fill)
//            for (int w = 0; w < WORDS_PER_LINE; w++)
//                data_array[w][replace_way][index] <= resp.mem_data[w*WIDTH+:WIDTH];
//        else if (do_hit_store)
//            for (int b = 0; b < 8; b++)
//                if (byte_wr_en[b])
//                    data_array[word_idx][hit_way_idx][index][b*8+:8] <= wdata_aligned[b*8+:8];
//    end
//`endif

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            // Reset logic
            valid_array <= '{default: '{default: '0}};
            dirty_array <= '{default: '{default: '0}};
            LRU_way_array <= '{default: '0};
            rdata <= '0;
        end else if (cache_inst) begin
            case (cache_op)
                WB_INVALIDATE: begin
                    if(valid_array[0][addr[INDEX_BITS-1:0]] && dirty_array[0][addr[INDEX_BITS-1:0]]) begin
                        req.mem_req_store <= 1'b1;
                        req.mem_req_load <= 1'b0;
                        req.mem_addr <= {tag_array[0][addr[INDEX_BITS-1:0]], addr[INDEX_BITS-1:0]};
                        for (int w = 0; w < WORDS_PER_LINE; w++)
                            req.mem_data_out[w*WIDTH+:WIDTH] <= data_bank_rd[0][w];
                    end else if(valid_array[1][addr[INDEX_BITS-1:0]] && dirty_array[1][addr[INDEX_BITS-1:0]]) begin
                        req.mem_req_store <= 1'b1;
                        req.mem_req_load <= 1'b0;
                        req.mem_addr <= {tag_array[1][addr[INDEX_BITS-1:0]], addr[INDEX_BITS-1:0]};
                        for (int w = 0; w < WORDS_PER_LINE; w++)
                            req.mem_data_out[w*WIDTH+:WIDTH] <= data_bank_rd[1][w];
                    end else begin
                        // no dirty data, just invalidate
                        valid_array[0][addr[INDEX_BITS-1:0]] <= 1'b0;
                        valid_array[1][addr[INDEX_BITS-1:0]] <= 1'b0;
                        req.mem_req_store <= 1'b0;
                        req.mem_req_load <= 1'b0;
                    end

                end
                default: $display("unsupported cache operation %b", cache_op);  // do nothing
            endcase
            rdata <= '0;
        end else if (enable && clear) begin
            rdata <= '0;
        end else if (enable && ((|mem_load_type) || (|mem_store_type))) begin
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
                        for (int w = 0; w < WORDS_PER_LINE; w++)
                            req.mem_data_out[w*WIDTH+:WIDTH] <= data_bank_rd[replace_way][w];
                    end else begin
                        $display("%m request new data, addr = %h", {tag, index});
                        req.mem_req_store <= 1'b0;
                        req.mem_req_load <= 1'b1;
                        req.mem_addr <= {tag, index};
                    end
                    rdata <= '0;
                end else begin
                    // response phase
`ifdef DEBUG
                    $display("%m response phase, dirty_wb = %b", dirty_wb);
`endif
                    if (dirty_wb) begin
                        // write back finished
`ifdef DEBUG
                        $display("%m writed back dirty cache, addr = %h, tag = %h, index = %h",
                                 req.mem_addr, tag_array[replace_way][index], index);
`endif
                        dirty_array[replace_way][index] <= 1'b0;
                        req.mem_req_store <= 1'b0;
                        rdata <= '0;
                    end else begin
                        // load new cache finished
`ifdef DEBUG
                        $display("%m: loaded new cache line, addr = %h, index = %h, data = %h",
                                 addr, index, resp.mem_data);
`endif
                        tag_array[replace_way][index] <= tag;
                        valid_array[replace_way][index] <= 1'b1;
                        dirty_array[replace_way][index] <= 1'b0;
                        // Fill write handled by per-bank storage block (do_fill).
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
                // Hit load: data_bank_rd[way][word] is the async-read output of the
                // per-bank distributed RAM; way/word selection is a combinatorial mux.
                case (mem_load_type)
                    LOAD_BYTE: begin
                        rdata <= {
                            {(WIDTH - 8) {data_bank_rd[hit_way_idx][word_idx][byte_idx*8+7] & signed_type}},
                            data_bank_rd[hit_way_idx][word_idx][byte_idx*8+:8]
                        };
                    end
                    LOAD_HALF: begin
                        rdata <= {
                            {(WIDTH - 16) {data_bank_rd[hit_way_idx][word_idx][byte_idx*8+15] & signed_type}},
                            data_bank_rd[hit_way_idx][word_idx][byte_idx*8+:16]
                        };
                    end
                    LOAD_WORD: begin
                        rdata <= {
                            {(WIDTH - 32) {data_bank_rd[hit_way_idx][word_idx][byte_idx*8+31] & signed_type}},
                            data_bank_rd[hit_way_idx][word_idx][byte_idx*8+:32]
                        };
                    end
                    LOAD_DWORD: begin
                        rdata <= data_bank_rd[hit_way_idx][word_idx];
                    end
                    NO_LOAD: rdata <= 'x;
                    default: rdata <= 'x;
                endcase
                // Hit-store writes handled by per-bank storage block (do_hit_store).
                LRU_way_array[index] <= ~hit_way_idx;
                dirty_array[hit_way_idx][index] <= (|mem_store_type) || dirty_array[hit_way_idx][index];
`ifdef DEBUG
                $display("%0t %m try to access addr=%h, tag=%h, index=%d, offset=%h, result = %h",
                         $time, addr, tag, index, offset,
                         data_bank_rd[hit_way_idx][word_idx]);
`endif
            end
        end else begin
            req.mem_req_load  <= 1'b0;
            req.mem_req_store <= 1'b0;
        end
    end

endmodule
