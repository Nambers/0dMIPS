module core_hazard #(
    parameter PERIPHERAL_BASE = 64'h2000_0000
) (
    input logic clock,
    input logic reset,
    // --- load-use ---
    input logic [4:0] IF_rs,
    input logic [4:0] IF_rt,
    input logic IF_B_is_reg,
    input logic IF_use_AU,
    input logic [4:0] ID_rs,
    input logic [4:0] ID_rt,
    input logic ID_B_is_reg,
    input logic [4:0] EX_W_regnum,
    input logic [4:0] ID_W_regnum,
    input logic ID_mem_read,
    output logic stall_EX,
    output logic stall_ID,

    // --- peripherals ---
    input logic [63:0] addr,
    input logic EX_mem_read,
    input logic EX_mem_write,
    // data peripheral ready
    input logic d_ready,
    // data peripheral access
    output logic d_valid
);
    logic release_next;
    // if addr is in the peripheral range and it's memory access operations
    // then it's a valid peripheral access
    assign d_valid = (EX_mem_write || EX_mem_read) & (addr >= PERIPHERAL_BASE);
    // load-use hazard, and block peripheral access
    assign stall_EX = (EX_mem_read & ((EX_W_regnum != 0) & ((ID_rs == EX_W_regnum) | ((ID_rt == EX_W_regnum) & ID_B_is_reg)))) | (d_valid & ~d_ready);

    // RAW hazard only for one cycle.
    wire stall_ID_RAW = IF_use_AU & (ID_W_regnum != 0) & ((IF_rs == ID_W_regnum) | ((IF_rt == ID_W_regnum) & IF_B_is_reg));

    // in ID stage there is an additional RAW hazard(AU dep on LU/lui result), not only load-use
    wire stall_ID_load_use = IF_use_AU & ID_mem_read & ((IF_rs == ID_W_regnum) | (IF_rt == ID_W_regnum));
    wire stall_ID_load_use_EX = IF_use_AU & EX_mem_read & ((IF_rs == EX_W_regnum) | (IF_rt == EX_W_regnum));
    assign stall_ID = stall_EX | (stall_ID_RAW & (~release_next)) | stall_ID_load_use | stall_ID_load_use_EX;

    always_ff @(posedge clock or posedge reset) begin
        $display("stall_ID=%b, stall_EX=%b, stall_ID_RAW=%b, stall_ID_load_use=%b, release_next=%b", stall_ID, stall_EX, stall_ID_RAW, stall_ID_load_use, release_next);
        if (reset) release_next <= 'b0;
        else if (!stall_EX) release_next <= stall_ID_RAW & ~release_next;
    end
endmodule
