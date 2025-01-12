module core_hazard #(
    parameter PERIPHERAL_BASE = 64'h2000_0000
) (
    // --- load-use ---
    input logic [4:0] IF_rs,
    input logic [4:0] IF_rt,
    input logic [4:0] ID_W_regnum,
    input logic ID_mem_read,
    output logic stall,

    // --- peripherals ---
    input logic [63:0] addr,
    input logic EX_mem_read,
    input logic EX_mem_write,
    // data peripheral ready
    input logic d_ready,
    // data peripheral access
    output logic d_valid
);
    // if addr is in the peripheral range and it's memory access operations
    // then it's a valid peripheral access
    assign d_valid = (EX_mem_write || EX_mem_read) && (addr >= PERIPHERAL_BASE);
    assign stall = (ID_mem_read &&
                  (ID_W_regnum != 0) &&
                  ((IF_rs == ID_W_regnum) || (IF_rt == ID_W_regnum))) || (d_valid && !d_ready);
endmodule
