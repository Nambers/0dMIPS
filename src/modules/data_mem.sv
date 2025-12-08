import structures::mem_bus_req_t;
import structures::mem_bus_resp_t;

module data_mem #(
    // size of data segment
    parameter DATA_LEN = 'h20000,  // 0x4000 * 8, unit: byte
    parameter INDEX_LEN = $clog2(DATA_LEN),
    parameter CACHE_LINE_SIZE = 64  // 64 Bytes
) (
    input logic clock,
    input logic reset,
    input mem_bus_req_t req,
    output mem_bus_resp_t resp
);
    localparam LINE_CUT_BITS = $clog2(CACHE_LINE_SIZE);
    initial begin
        // Grab initial memory values
        $readmemh("memory.mem", data_seg);
    end

    logic [7:0] data_seg[0:DATA_LEN-1]  /* verilator public */;
    logic [INDEX_LEN-1:0] addr;

    always_comb begin
        assert (req.mem_addr < DATA_LEN - 64)
        else $fatal("Data memory access out of bounds: %h", req.mem_addr);
        assert (!(req.mem_req_load && req.mem_req_store))
        else $fatal("Data memory request cannot be both load and store");

        addr = {req.mem_addr[INDEX_LEN-LINE_CUT_BITS-1:0], {LINE_CUT_BITS{1'b0}}};
    end

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            $readmemh("memory.mem", data_seg);
            resp.mem_ready <= 1'b0;
        end else begin
            if (req.mem_req_store) begin
                for (int i = 0; i < 64; i++) begin
                    data_seg[addr+i[16:0]] <= req.mem_data_out[i*8+:8];
                end
                resp.mem_ready <= 1'b1;
            end
            if (req.mem_req_load) begin
                for (int i = 0; i < 64; i++) begin
                    resp.mem_data[i*8+:8] <= data_seg[addr+i[16:0]];
                end
                resp.mem_ready <= 1'b1;
            end else begin
                resp.mem_data  <= '0;
                resp.mem_ready <= 1'b0;
            end
        end
    end

endmodule  // data_mem
