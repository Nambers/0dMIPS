module core_hazard #(
    parameter PERIPHERAL_BASE = 64'h2000_0000
) (
    // --- load-use ---
    input logic [4:0] IF_rs,
    input logic [4:0] IF_rt,
    input logic IF_B_is_reg,
    input logic [4:0] ID_W_regnum,
    input logic ID_mem_read,
    input logic [4:0] EX_W_regnum,
    // input logic EX_mem_read,
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
    logic load_use, d_valid_tmp, EX_load_use, MEM1_load_use;
    always_comb begin
        d_valid = (EX_mem_write || EX_mem_read) && (addr >= PERIPHERAL_BASE);
        // if addr is in the peripheral range and it's memory access operations
        // then it's a valid peripheral access
        EX_load_use = ID_mem_read &&
                  (ID_W_regnum != 0) &&
                  ((IF_rs == ID_W_regnum) || (IF_B_is_reg && (IF_rt == ID_W_regnum)));
        MEM1_load_use = EX_mem_read &&
                   (EX_W_regnum != 0) &&
                   ((IF_rs == EX_W_regnum) || (IF_B_is_reg && (IF_rt == EX_W_regnum)));
        load_use = EX_load_use || MEM1_load_use;

        d_valid_tmp = (EX_mem_write || EX_mem_read) && (addr >= PERIPHERAL_BASE);
        stall = load_use || (d_valid_tmp && !d_ready);

        $display("t=%0t, stall = %d, %d %d", $time, stall, load_use, (d_valid_tmp && !d_ready));
    end
endmodule
