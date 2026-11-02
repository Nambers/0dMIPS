// Simulation-only, read-only DPI inspectors for bulk state (register file,
// L1 caches, backing memory). They are bound into the RTL, so no RTL file
// changes are needed, and C++ selects an instance with
// svSetScope(svGetScopeFromName("<instance path>.insp")); see
// simulations/soc_inspect.hpp, the only C++ that calls these functions.
//
// Rules that keep the C++ side layout-agnostic:
// - geometry is passed in from the target's own (local)params via the bind and
//   reported to C++, never hard-coded there;
// - every index is range-checked (status -1 instead of aliasing);
// - values are returned as <= 64-bit scalars, so C++ does no bit slicing.
// They are called on demand only and add no per-cycle work.

module regfile_inspect #(
    parameter int WIDTH = 0
);
    if (WIDTH < 1 || WIDTH > 64) begin : g_width_guard
        $error("regfile_inspect: register width %0d does not fit in 64 bits", WIDTH);
    end

    export "DPI-C" function dbg_rf_read;

    // 0 on success, -1 if i is not a register number
    function int dbg_rf_read(input int i, output longint unsigned value);
        if (i < 0 || i >= 32) return -1;
        value = 64'(regfile.reg_out[i]);
        return 0;
    endfunction
endmodule
bind regfile regfile_inspect #(.WIDTH(width)) insp ();


module cache_L1_inspect #(
    parameter int WAYS        = 0,
    parameter int ENTRIES     = 0,
    parameter int WORDS       = 0,
    parameter int OFFSET_BITS = 0,
    parameter int INDEX_BITS  = 0,
    parameter int TAG_BITS    = 0
);
    // dbg_cache_word's case is written out per bank (generate-block arrays
    // need constant indices); refuse to elaborate if the RTL geometry changes.
    if (WAYS != 2 || WORDS != 8) begin : g_geometry_guard
        $error("cache_L1_inspect: dbg_cache_word covers 2 ways x 8 words, RTL has %0d x %0d",
               WAYS, WORDS);
    end

    export "DPI-C" function dbg_cache_geometry;
    export "DPI-C" function dbg_cache_decode;
    export "DPI-C" function dbg_cache_meta;
    export "DPI-C" function dbg_cache_word;

    function void dbg_cache_geometry(output int ways, output int entries, output int words);
        ways    = WAYS;
        entries = ENTRIES;
        words   = WORDS;
    endfunction

    // same split as cache_L1: {tag, index, offset} = addr
    function void dbg_cache_decode(input longint unsigned addr, output int index,
                                   output longint unsigned tag, output int word);
        logic [TAG_BITS-1:0] t;
        logic [INDEX_BITS-1:0] i;
        logic [OFFSET_BITS-1:0] o;
        {t, i, o} = addr;
        index = int'(i);
        tag   = 64'(t);
        word  = int'(o[OFFSET_BITS-1:3]);
    endfunction

    function automatic bit in_range(int way, int idx);
        return way >= 0 && way < WAYS && idx >= 0 && idx < ENTRIES;
    endfunction

    // 0 on success, -1 if (way, idx) is out of range
    function int dbg_cache_meta(input int way, input int idx, output bit valid,
                                output bit dirty, output bit lru,
                                output longint unsigned tag);
        if (!in_range(way, idx)) return -1;
        valid = cache_L1.valid_array[way][idx];
        dirty = cache_L1.dirty_array[way][idx];
        lru   = cache_L1.LRU_way_array[idx];
        tag   = 64'(cache_L1.tag_array[way][idx]);
        return 0;
    endfunction

`define ODMIPS_BANK(w, b) w * 8 + b: data = cache_L1.way_bank[w].word_bank[b].data[idx];
    // 0 on success, -1 if (way, word, idx) is out of range
    function int dbg_cache_word(input int way, input int word, input int idx,
                                output longint unsigned data);
        if (!in_range(way, idx) || word < 0 || word >= WORDS) return -1;
        case (way * 8 + word)
            `ODMIPS_BANK(0, 0) `ODMIPS_BANK(0, 1) `ODMIPS_BANK(0, 2) `ODMIPS_BANK(0, 3)
            `ODMIPS_BANK(0, 4) `ODMIPS_BANK(0, 5) `ODMIPS_BANK(0, 6) `ODMIPS_BANK(0, 7)
            `ODMIPS_BANK(1, 0) `ODMIPS_BANK(1, 1) `ODMIPS_BANK(1, 2) `ODMIPS_BANK(1, 3)
            `ODMIPS_BANK(1, 4) `ODMIPS_BANK(1, 5) `ODMIPS_BANK(1, 6) `ODMIPS_BANK(1, 7)
            default: return -1;
        endcase
        return 0;
    endfunction
`undef ODMIPS_BANK
endmodule
// parameter expressions in a bind are evaluated in the target (cache_L1) scope
bind cache_L1 cache_L1_inspect #(
    .WAYS       (CACHE_WAYS),
    .ENTRIES    (CACHE_ENTRIES),
    .WORDS      (WORDS_PER_LINE),
    .OFFSET_BITS(OFFSET_BITS),
    .INDEX_BITS (INDEX_BITS),
    .TAG_BITS   (TAG_BITS)
) insp ();


module xpm_inspect #(
    parameter int LINES     = 0,
    parameter int LINE_BITS = 0
);
    if (LINE_BITS % 64 != 0) begin : g_line_guard
        $error("xpm_inspect: line width %0d is not a whole number of 64-bit words", LINE_BITS);
    end

    export "DPI-C" function dbg_mem_geometry;
    export "DPI-C" function dbg_mem_word;

    function void dbg_mem_geometry(output int lines, output int line_bytes);
        lines      = LINES;
        line_bytes = LINE_BITS / 8;
    endfunction

    // 64-bit word `word` of line `line` (byte 0 of a line is bits [7:0]);
    // 0 on success, -1 if out of range
    function int dbg_mem_word(input int line, input int word, output longint unsigned data);
        if (line < 0 || line >= LINES || word < 0 || word >= LINE_BITS / 64) return -1;
        data = xpm_memory_sdpram.mem[line][word*64+:64];
        return 0;
    endfunction
endmodule
bind xpm_memory_sdpram xpm_inspect #(
    .LINES    (NUM_WORDS),
    .LINE_BITS(READ_DATA_WIDTH_B)
) insp ();
