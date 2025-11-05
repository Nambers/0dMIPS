import structures::mem_bus_req_t;
import structures::mem_bus_resp_t;

module cache_arbiter #(
    parameter CACHE_LINE_SIZE = 64 * 8  // 64 Bytes
) (
    input logic clock,
    input logic reset,

    input  mem_bus_req_t  req1,
    output mem_bus_resp_t resp1,

    input  mem_bus_req_t  req2,
    output mem_bus_resp_t resp2,

    // L2 interface
    output mem_bus_req_t  req,
    input  mem_bus_resp_t resp
);
    logic cache1_st_Q, cache2_st_Q, cache1_st_D, cache2_st_D;
    register #(2) cache_st (
        {cache2_st_Q, cache1_st_Q},
        {cache2_st_D, cache1_st_D},
        clock,
        1'b00,
        reset
    );

    mux4v #(64-6) addr_mux (
        req.mem_addr,
        req1.mem_addr,
        'x,
        req2.mem_addr,
        'x,
        {cache2_st_Q, cache1_st_Q}
    );

    mux4v #(CACHE_LINE_SIZE) data_out_mux (
        req.mem_data_out,
        req1.mem_data_out,
        'x,
        req2.mem_data_out,
        'x,
        {cache2_st_Q, cache1_st_Q}
    );

    mux2v #(CACHE_LINE_SIZE) data_1_mux (
        resp1.mem_data,
        resp.mem_data,
        'x,
        cache1_st_Q && resp.mem_ready
    );

    mux2v #(CACHE_LINE_SIZE) data_2_mux (
        resp2.mem_data,
        resp.mem_data,
        'x,
        cache2_st_Q && resp.mem_ready
    );

    mux4v #(1) req_load_mux (
        req.mem_req_load,
        req1.mem_req_load,
        1'b0,
        req2.mem_req_load,
        1'b0,
        {cache2_st_Q, cache1_st_Q}
    );

    mux4v #(1) req_store_mux (
        req.mem_req_store,
        req1.mem_req_store,
        1'b0,
        req2.mem_req_store,
        1'b0,
        {cache2_st_Q, cache1_st_Q}
    );

    always_comb begin
        // if no ready and it was enabled in last cycle, stay
        // if not, check if 2nd cache is using bus. If so, wait,
        // otherwise check if requested
        cache1_st_D = (cache1_st_Q && !resp.mem_ready) || ((req1.mem_req_load || req1.mem_req_store) && !cache2_st_Q);
        resp1.mem_ready = cache1_st_Q && resp.mem_ready;
        // additionally, 2nd cache has to wait for 1st cache request
        cache2_st_D = (cache2_st_Q && !resp.mem_ready) || ((req2.mem_req_load || req2.mem_req_store) && !cache1_st_Q && !req1.mem_req_load && !req1.mem_req_store);
        resp2.mem_ready = cache2_st_Q && resp.mem_ready;

        assert (!(cache1_st_D && cache2_st_D))
        else $fatal("cache arbiter: both caches requesting bus!");
    end
endmodule
