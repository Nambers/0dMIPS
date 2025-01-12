////////////////////////////////////////////////////////////////////////
//
// Module: rom
//
// Author: Jared Smolens
//
// Description:
//  Reads a file named 'memory.dat' for 32-bit binary MIPS instructions.
//  Will read up to 256 instructions.
//
////////////////////////////////////////////////////////////////////////
// this file is modified

module data_mem (
    output logic [63:0] data_out,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] data_in,
    input logic word_we,
    input logic byte_we,
    input logic clk,
    input logic reset,
    output logic [31:0] inst,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] inst_addr
    /* verilator lint_on UNUSEDSIGNAL */
);
    parameter  // size of data segment
    data_words = 'h4000;  /* 4 M */

    // Memory segments
    logic   [63:0] data_seg[0:data_words-1]  /* verilator public */;

    // Verilog implementation stuff
    integer        i;

    initial begin
        // Initialize memory (prevents x-pessimism problem)
        for (i = 0; i < data_words; i = i + 1) data_seg[i] = 64'b0;

        // Grab initial memory values
        $readmemh("memory.text.mem", data_seg);
        $readmemh("memory.data.mem", data_seg);
    end

    wire [ 5:0] index = addr[8:3], inst_index = inst_addr[8:3];
    wire [63:0] d_out = data_seg[index];

    // TODO 32bit read
    always_comb begin
        data_out = data_seg[index];
        inst = (inst_addr[2] == 1'b0) ? data_seg[inst_index][31:0] : data_seg[inst_index][63:32];
    end

    always @(negedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < data_words; i = i + 1) data_seg[i] <= 64'b0;
            $readmemh("memory.text.mem", data_seg);
            $readmemh("memory.data.mem", data_seg);
        end else begin
            if (word_we) begin
                if (addr[2] == 1'b0) data_seg[index][31:0] <= data_in[31:0];
                else data_seg[index][63:32] <= data_in[31:0];
            end else begin
                if (byte_we)
                    data_seg[index] <= (d_out & ~(64'hff << (8*(addr[2:0])))) | ((data_in & 64'hff) << (8*(addr[2:0])));
            end
        end
    end


endmodule  // data_mem
