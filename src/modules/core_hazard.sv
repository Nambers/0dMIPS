module core_hazard #(
    parameter PERIPHERAL_BASE = 64'h2000_0000
) (
    // --- load-use ---
    input logic [4:0] IF_rs,
    input logic [4:0] IF_rt,
    input logic [4:0] ID_W_regnum,
    input logic ID_mem_read,
    input logic IF_B_is_reg,
    output logic stall,

    // --- peripherals ---
    input logic [63:0] addr,
    input logic EX_mem_read,
    input logic EX_mem_write,
    // data peripheral ready
    input logic d_ready,
    // data peripheral access
    output logic d_valid,

    // --- mem bus ---
    input logic mem_bus_req,
    input logic mem_bus_ready
);
    logic load_use, d_valid_tmp;
    always_comb begin
        d_valid = (EX_mem_write || EX_mem_read) && (addr >= PERIPHERAL_BASE);
        // if addr is in the peripheral range and it's memory access operations
        // then it's a valid peripheral access
        load_use = ID_mem_read &&
                  (ID_W_regnum != 0) &&
                  ((IF_rs == ID_W_regnum) || (IF_B_is_reg && (IF_rt == ID_W_regnum)));

        d_valid_tmp = (EX_mem_write || EX_mem_read) && (addr >= PERIPHERAL_BASE);
        stall = load_use || (d_valid_tmp && !d_ready) || (mem_bus_req && !mem_bus_ready);

        // $display("stall = %d, %d %d %d", stall, load_use, (d_valid_tmp && !d_ready),
        //          (mem_bus_req && !mem_bus_ready));
    end
endmodule
