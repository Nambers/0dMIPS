module core_hazard #(
    parameter PERIPHERAL_BASE = 64'h2000_0000
) (
    // --- load-use ---
    input logic [4:0] ID_rs,
    input logic [4:0] ID_rt,
    input logic [4:0] EX_rd,
    input logic EX_mem_read,
    output logic stall,

    // --- peripherals ---
    input logic [63:0] addr,
    input logic EX_mem_write,
    // data peripheral ready
    input logic d_ready,
    // data peripheral access
    output logic d_valid
);
    // if addr is in the peripheral range and it's memory access operations
    // then it's a valid peripheral access
    assign d_valid = (EX_mem_write || EX_mem_read) && (addr >= PERIPHERAL_BASE);
    assign stall = (EX_mem_read &&
                  (EX_rd != 0) &&
                  ((ID_rs == EX_rd) || (ID_rt == EX_rd))) || (d_valid && !d_ready);
endmodule
