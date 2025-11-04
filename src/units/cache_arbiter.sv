module cache_arbiter #(
    parameter CACHE_LINE_SIZE = 64 * 8  // 64 Bytes
) (
    input logic clock,
    input logic reset,

    input logic mem_req_load_1,
    input logic mem_req_store_1,
    input logic [63:0] mem_addr_1,
    input wire [CACHE_LINE_SIZE-1:0] mem_data_out_1,
    output wire [CACHE_LINE_SIZE-1:0] mem_data_1,
    output logic mem_ready_1,

    input logic mem_req_load_2,
    input logic mem_req_store_2,
    input logic [63:0] mem_addr_2,
    inout wire [CACHE_LINE_SIZE-1:0] mem_data_out_2,
    output wire [CACHE_LINE_SIZE-1:0] mem_data_2,
    output logic mem_ready_2,

    // L2 interface
    output logic mem_req_load,
    output logic mem_req_store,
    output logic [63:0] mem_addr,
    input wire [CACHE_LINE_SIZE-1:0] mem_data,
    output wire [CACHE_LINE_SIZE-1:0] mem_data_out,
    input logic mem_ready
);
    logic cache1_st_Q, cache2_st_Q, cache1_st_D, cache2_st_D;
    register #(2) cache_st (
        {cache2_st_Q, cache1_st_Q},
        {cache2_st_D, cache1_st_D},
        clock,
        1'b00,
        reset
    );

    mux4v #(64) addr_mux (
        mem_addr,
        mem_addr_1,
        'x,
        mem_addr_2,
        'x,
        {cache2_st_Q, cache1_st_Q}
    );

    mux4v #(CACHE_LINE_SIZE) data_out_mux (
        mem_data_out,
        mem_data_out_1,
        'x,
        mem_data_out_2,
        'x,
        {cache2_st_Q, cache1_st_Q}
    );

    mux2v #(CACHE_LINE_SIZE) data_1_mux (
        mem_data_1,
        mem_data,
        'x,
        cache1_st_Q && mem_ready
    );

    mux2v #(CACHE_LINE_SIZE) data_2_mux (
        mem_data_2,
        mem_data,
        'x,
        cache2_st_Q && mem_ready
    );

    mux4v #(1) req_load_mux (
        mem_req_load,
        mem_req_load_1,
        1'b0,
        mem_req_load_2,
        1'b0,
        {cache2_st_Q, cache1_st_Q}
    );

    mux4v #(1) req_store_mux (
        mem_req_store,
        mem_req_store_1,
        1'b0,
        mem_req_store_2,
        1'b0,
        {cache2_st_Q, cache1_st_Q}
    );

    always_comb begin
        // if no ready and it was enabled in last cycle, stay
        // if not, check if 2nd cache is using bus. If so, wait,
        // otherwise check if requested
        cache1_st_D = (cache1_st_Q && !mem_ready) || ((mem_req_load_1 || mem_req_store_1) && !cache2_st_Q);
        mem_ready_1 = cache1_st_Q && mem_ready;
        // additionally, 2nd cache has to wait for 1st cache request
        cache2_st_D = (cache2_st_Q && !mem_ready) || ((mem_req_load_2 || mem_req_store_2) && !cache1_st_Q && !mem_req_load_1 && !mem_req_store_1);
        mem_ready_2 = cache2_st_Q && mem_ready;

        assert (!(cache1_st_D && cache2_st_D))
        else $fatal("cache arbiter: both caches requesting bus!");
    end
endmodule
