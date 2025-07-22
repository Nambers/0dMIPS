import structures::EX_regs_t;
import structures::MEM_regs_t;

module core_MEM (
    input logic clock,
    input logic reset,
    /* verilator lint_off UNUSEDSIGNAL */
    input EX_regs_t EX_regs,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] fetch_pc,
    input logic [63:0] ID_pc,
    input logic [7:0] interrupt_sources,
    input logic flush,
    input logic ID_ERET,
    input logic d_valid,
    input logic d_ready,
    input logic [63:0] d_rdata,
    output logic [31:0] inst,
    output MEM_regs_t MEM_regs
);
    logic [63:0] data_out, mem_out, alu_mem_d_out, EPC, c0_rd_data, W_data, W_data_lui_linkpc;
    logic takenHandler  /* verilator public */;

    // -- mem --
    data_mem #('h2000) mem (
        .clk(clock),
        .reset(reset),
        .addr(EX_regs.out),
        .data_in(EX_regs.B_data),
        .flush(flush),
        .signed_type(EX_regs.signed_mem_out),
        .mem_load_type(EX_regs.mem_load_type & {3{~d_valid}}), // mmio use memory load type but not load from
        .mem_store_type(EX_regs.mem_store_type & {3{~d_valid}}), // mmio use memory store type but not store into
        .data_out(data_out),
        .inst_addr(fetch_pc),
        .inst(inst)
    );

    mux4v #(64) alu_mem_mux (
        alu_mem_d_out,
        EX_regs.out,
        data_out,
        'x,  // periph write, mem_out will not be used
        d_rdata,
        {d_valid, |EX_regs.mem_load_type}
    );

    // -- cp0 --
    cp0 cp0_ (
        .rd_data(c0_rd_data),
        .EPC(EPC),
        .takenHandler(takenHandler),
        .wr_data(EX_regs.B_data),
        .regnum(EX_regs.cp0_rd),
        .sel(EX_regs.sel),
        .curr_pc(ID_pc),
        .MTC0(EX_regs.MTC0),
        .ERET(ID_ERET),
        .interrupt_source(interrupt_sources),
        .clock(clock),
        .reset(reset),
        .overflow(EX_regs.overflow),
        .reserved_inst(EX_regs.reserved_inst_E),
        .syscall(EX_regs.syscall),
        .break_(1'b0)  // TODO syscall, break
    );

    mux2v #(64) mfc0_mux (
        W_data,
        alu_mem_d_out,
        c0_rd_data,
        EX_regs.MFC0
    );

    mux2v #(64) linkpc_mux (
        W_data_lui_linkpc,
        W_data,
        EX_regs.pc4,
        EX_regs.linkpc
    );

    always_ff @(posedge clock, posedge reset) begin
`ifdef DEBUG
        if (|EX_regs.mem_load_type) begin
            $display("read addr: %h, data: %h, final: %h, reg=$%d, type = %d", EX_regs.out,
                     data_out, W_data_lui_linkpc, EX_regs.W_regnum, EX_regs.mem_load_type);
        end
        if (|EX_regs.mem_store_type) begin
            $display("write addr: %h, data: %h, type: %d", EX_regs.out, EX_regs.B_data,
                     EX_regs.mem_store_type);
        end
`endif
        if (reset) begin
            MEM_regs <= '0;
        end else begin
            MEM_regs.EPC <= EPC;
            MEM_regs.W_data <= W_data_lui_linkpc;
            MEM_regs.W_regnum <= EX_regs.W_regnum;
            MEM_regs.write_enable <= EX_regs.write_enable;
            MEM_regs.takenHandler <= takenHandler;
`ifdef DEBUGGER
            MEM_regs.pc   <= EX_regs.pc;
            MEM_regs.inst <= EX_regs.inst;
`endif
        end
    end
endmodule
