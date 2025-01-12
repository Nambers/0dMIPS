import structures::EX_regs_t;
import structures::MEM_regs_t;

module core_MEM (
    input logic clock,
    input logic reset,
    /* verilator lint_off UNUSEDSIGNAL */
    input EX_regs_t EX_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] inst_addr,
    input logic [7:0] interrupt_sources,
    input logic [63:0] next_pc,
    input logic d_valid,
    input logic d_ready,
    input logic [63:0] d_rdata,
    output logic [31:0] inst,
    output MEM_regs_t MEM_regs
);
    logic [7:0] byte_load_out;
    logic [63:0] data_out, mem_out, alu_mem_out, alu_mem_d_out;
    logic [63:0] EPC, c0_rd_data, W_data;
    logic takenInterrupt  /* verilator public */;

    // -- mem --
    // {out[63:3], 3'b000} to align the data to the memory
    data_mem #(64) mem (
        data_out,
        EX_regs.out,
        EX_regs.B_data,
        EX_regs.word_we & ~d_valid,  // TODO ~timeraddr
        EX_regs.byte_we & ~d_valid,
        clock,
        reset,
        inst,
        inst_addr
    );
    mux8v #(8) byte_load_mux (
        byte_load_out,
        data_out[7:0],
        data_out[15:8],
        data_out[23:16],
        data_out[31:24],
        data_out[39:32],
        data_out[47:40],
        data_out[55:48],
        data_out[63:56],
        EX_regs.out[2:0]
    );
    mux2v #(64) mem_out_mux (
        mem_out,
        data_out,
        {{56{byte_load_out[7]}}, byte_load_out},
        EX_regs.byte_load
    );
    mux2v #(64) alu_mem_mux (
        alu_mem_out,
        EX_regs.slt_out,
        mem_out,
        EX_regs.mem_read
    );
    mux2v #(64) d_mux (
        alu_mem_d_out,
        alu_mem_out,
        d_rdata,
        d_valid && d_ready
    );

    // -- cp0 --
    cp0 cp (
        c0_rd_data,
        EPC,
        takenInterrupt,
        EX_regs.B_data,
        EX_regs.W_regnum,
        EX_regs.sel,
        next_pc,
        EX_regs.MTC0,
        EX_regs.ERET,
        interrupt_sources,
        clock,
        reset,
        EX_regs.overflow,
        EX_regs.reserved_inst_E,
        0,
        0
    );  // TODO syscall, break

    mux2v #(64) mfc0_mux (
        W_data,
        alu_mem_d_out,
        c0_rd_data,
        EX_regs.MFC0
    );

    always_ff @(posedge clock, posedge reset) begin
        // $display("write addr: %h, enable: %h, data: %h", EX_regs.out,
        //          EX_regs.byte_we | EX_regs.word_we, EX_regs.B_data);
        if (reset) begin
            MEM_regs <= '0;
        end else begin
            MEM_regs.EPC <= EPC;
            MEM_regs.W_data <= W_data;
            MEM_regs.W_regnum <= EX_regs.W_regnum;
            MEM_regs.write_enable <= EX_regs.write_enable;
            MEM_regs.takenInterrupt <= takenInterrupt;
            MEM_regs.mem_read <= EX_regs.mem_read;
        end
    end
endmodule
