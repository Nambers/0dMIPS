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

// Total cache size = CACHE_LINE_SIZE * CACHE_ENTRIES * CACHE_WAYS = 64B * 32 * 2 = 4KB.
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
    localparam OFFSET_BITS = $clog2(CACHE_LINE_SIZE / 8);
    localparam INDEX_BITS = $clog2(CACHE_ENTRIES);
    localparam TAG_BITS = WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE = CACHE_LINE_SIZE / WIDTH;

    logic [TAG_BITS-1:0] tag_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic valid_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic dirty_array[CACHE_WAYS-1:0][CACHE_ENTRIES-1:0]  /* verilator public */;
    logic LRU_way_array[CACHE_ENTRIES-1:0];

    logic [WIDTH-1:0] data_bank_rd[CACHE_WAYS-1:0][WORDS_PER_LINE-1:0];
    logic [INDEX_BITS-1:0] data_rd_index;
    logic fill_enable;
    logic hit_store_enable;
    logic [INDEX_BITS-1:0] cache_op_index;

    logic [TAG_BITS-1:0] tag;
    logic [INDEX_BITS-1:0] index;
    logic [OFFSET_BITS-1:0] offset;
    logic [$clog2(WORDS_PER_LINE)-1:0] word_idx;
    logic [2:0] byte_idx;

    logic [CACHE_WAYS - 1 : 0] way_hit  /* verilator public */;
    logic hit_way_idx;
    logic replace_way;
    logic dirty_wb;

    logic [7:0] byte_wr_en;
    logic [WIDTH-1:0] wdata_aligned;

    function automatic logic [WIDTH-1:0] load_from_word(
        input logic [WIDTH-1:0] word_data, input logic [2:0] byte_offset,
        input mem_load_type_t load_type, input logic is_signed);
        case (load_type)
            LOAD_BYTE: begin
                load_from_word = {
                    {(WIDTH - 8) {word_data[byte_offset*8+7] & is_signed}},
                    word_data[byte_offset*8+:8]
                };
            end
            LOAD_HALF: begin
                load_from_word = {
                    {(WIDTH - 16) {word_data[byte_offset*8+15] & is_signed}},
                    word_data[byte_offset*8+:16]
                };
            end
            LOAD_WORD: begin
                load_from_word = {
                    {(WIDTH - 32) {word_data[byte_offset*8+31] & is_signed}},
                    word_data[byte_offset*8+:32]
                };
            end
            LOAD_DWORD: load_from_word = word_data;
            NO_LOAD:    load_from_word = 'x;
            default:    load_from_word = 'x;
        endcase
    endfunction

    function automatic logic [WIDTH-1:0] load_from_line(
        input logic [CACHE_LINE_SIZE-1:0] line_data,
        input logic [OFFSET_BITS-1:0] line_offset,
        input mem_load_type_t load_type, input logic is_signed);
        case (load_type)
            LOAD_BYTE: begin
                load_from_line = {
                    {(WIDTH - 8) {line_data[line_offset*8+7] & is_signed}},
                    line_data[line_offset*8+:8]
                };
            end
            LOAD_HALF: begin
                load_from_line = {
                    {(WIDTH - 16) {line_data[line_offset*8+15] & is_signed}},
                    line_data[line_offset*8+:16]
                };
            end
            LOAD_WORD: begin
                load_from_line = {
                    {(WIDTH - 32) {line_data[line_offset*8+31] & is_signed}},
                    line_data[line_offset*8+:32]
                };
            end
            LOAD_DWORD: load_from_line = line_data[line_offset*8+:64];
            NO_LOAD:    load_from_line = 'x;
            default:    load_from_line = 'x;
        endcase
    endfunction

    always_comb begin
        {tag, index, offset} = addr;
        word_idx = offset[OFFSET_BITS-1:3];
        byte_idx = offset[2:0];
        cache_op_index = addr[INDEX_BITS-1:0];

        way_hit = {
            valid_array[1][index] && (tag_array[1][index] == tag),
            valid_array[0][index] && (tag_array[0][index] == tag)
        };
        hit_way_idx = way_hit[1];
        replace_way = LRU_way_array[index];
        dirty_wb = valid_array[replace_way][index] && dirty_array[replace_way][index];
        miss = (|mem_load_type || |mem_store_type) && !(|way_hit);

        case (mem_store_type)
            STORE_BYTE:  byte_wr_en = 8'h01 << byte_idx;
            STORE_HALF:  byte_wr_en = 8'h03 << {byte_idx[2:1], 1'b0};
            STORE_WORD:  byte_wr_en = 8'h0f << {byte_idx[2], 2'b0};
            STORE_DWORD: byte_wr_en = 8'hff;
            default:     byte_wr_en = 8'h00;
        endcase

        wdata_aligned = wdata << ({byte_idx, 3'b0});
        data_rd_index = cache_inst ? cache_op_index : index;

        fill_enable = !reset && !cache_inst && !clear && enable
                      && (|mem_load_type || |mem_store_type)
                      && !(|way_hit) && resp.mem_ready && !dirty_wb;
        hit_store_enable = !reset && !cache_inst && !clear && enable
                           && (|mem_store_type) && (|way_hit);
    end

    // Data storage is split by way and by 64-bit word within a cache line.
    // The static generate indexes keep each bank as a simple 32-deep RAM.
    genvar bank_way, bank_word;
    generate
        for (bank_way = 0; bank_way < CACHE_WAYS; bank_way++) begin : way_bank
            for (
                bank_word = 0; bank_word < WORDS_PER_LINE; bank_word++
            ) begin : word_bank
                (* ram_style = "block" *) logic [WIDTH-1:0] data[0:CACHE_ENTRIES-1] /* verilator public */;

                assign data_bank_rd[bank_way][bank_word] = data[data_rd_index];

                always_ff @(posedge clock) begin
                    if (fill_enable && (replace_way == bank_way))
                        data[index] <= resp.mem_data[bank_word*WIDTH+:WIDTH];
                    else if (hit_store_enable && (hit_way_idx == bank_way) && (word_idx == bank_word))
                        for (int b = 0; b < 8; b++)
                        if (byte_wr_en[b])
                            data[index][b*8+:8] <= wdata_aligned[b*8+:8];
                end
            end
        end
    endgenerate

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            valid_array <= '{default: '{default: '0}};
            dirty_array <= '{default: '{default: '0}};
            LRU_way_array <= '{default: '0};
            rdata <= '0;
        end else if (cache_inst) begin
            case (cache_op)
                WB_INVALIDATE: begin
                    if (valid_array[0][cache_op_index] && dirty_array[0][cache_op_index]) begin
                        req.mem_req_store <= 1'b1;
                        req.mem_req_load <= 1'b0;
                        req.mem_addr <= {
                            tag_array[0][cache_op_index], cache_op_index
                        };
                        for (int w = 0; w < WORDS_PER_LINE; w++)
                        req.mem_data_out[w*WIDTH+:WIDTH] <= data_bank_rd[0][w];
                    end else if (valid_array[1][cache_op_index] && dirty_array[1][cache_op_index]) begin
                        req.mem_req_store <= 1'b1;
                        req.mem_req_load <= 1'b0;
                        req.mem_addr <= {
                            tag_array[1][cache_op_index], cache_op_index
                        };
                        for (int w = 0; w < WORDS_PER_LINE; w++)
                        req.mem_data_out[w*WIDTH+:WIDTH] <= data_bank_rd[1][w];
                    end else begin
                        valid_array[0][cache_op_index] <= 1'b0;
                        valid_array[1][cache_op_index] <= 1'b0;
                        req.mem_req_store <= 1'b0;
                        req.mem_req_load <= 1'b0;
                    end

                end
                default: $display("unsupported cache operation %b", cache_op);
            endcase
            rdata <= '0;
        end else if (enable && clear) begin
            rdata <= '0;
        end else if (enable && ((|mem_load_type) || (|mem_store_type))) begin
            if (!(|way_hit)) begin
                if (!resp.mem_ready) begin
                    if (dirty_wb) begin
                        req.mem_req_store <= 1'b1;
                        req.mem_req_load <= 1'b0;
                        req.mem_addr <= {tag_array[replace_way][index], index};
                        for (int w = 0; w < WORDS_PER_LINE; w++)
                        req.mem_data_out[w*WIDTH+:WIDTH] <= data_bank_rd[replace_way][w];
                    end else begin
                        $display("%m request new data, addr = %h", {tag, index
                                 });
                        req.mem_req_store <= 1'b0;
                        req.mem_req_load <= 1'b1;
                        req.mem_addr <= {tag, index};
                    end
                    rdata <= '0;
                end else begin
`ifdef DEBUG
                    $display("%m response phase, dirty_wb = %b", dirty_wb);
`endif
                    if (dirty_wb) begin
`ifdef DEBUG
                        $display(
                            "%m writed back dirty cache, addr = %h, tag = %h, index = %h",
                            req.mem_addr, tag_array[replace_way][index], index);
`endif
                        dirty_array[replace_way][index] <= 1'b0;
                        req.mem_req_store <= 1'b0;
                        rdata <= '0;
                    end else begin
                        // load new cache finished
`ifdef DEBUG
                        $display(
                            "%m: loaded new cache line, addr = %h, index = %h, data = %h",
                            addr, index, resp.mem_data);
`endif
                        tag_array[replace_way][index] <= tag;
                        valid_array[replace_way][index] <= 1'b1;
                        dirty_array[replace_way][index] <= 1'b0;
                        req.mem_req_load <= 1'b0;
                        rdata <= load_from_line(
                            resp.mem_data, offset, mem_load_type, signed_type
                        );
                        LRU_way_array[index] <= ~replace_way;
                    end
                end
            end else begin
                rdata <= load_from_word(
                    data_bank_rd[hit_way_idx][word_idx],
                    byte_idx,
                    mem_load_type,
                    signed_type
                );
                LRU_way_array[index] <= ~hit_way_idx;
                dirty_array[hit_way_idx][index] <= (|mem_store_type) || dirty_array[hit_way_idx][index];
`ifdef DEBUG
                $display(
                    "%0t %m try to access addr=%h, tag=%h, index=%d, offset=%h, result = %h",
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
