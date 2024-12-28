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
    data_out,
    addr,
    data_in,
    word_we,
    byte_we,
    clk,
    reset,
    inst,
    inst_addr
);
    parameter  // size of data segment
    data_start = 64'h10000000, data_words = 'h4000;  /* 4 M */

    input clk, reset;

    // Inputs and ouptuts: Port 1
    output [63:0] data_out;  // Memory read data
    output [31:0] inst;
    /* verilator lint_off UNUSEDSIGNAL */
    input [63:0] inst_addr;
    /* verilator lint_on UNUSEDSIGNAL */
    input [63:0] addr;  // Memory address
    input [63:0] data_in;  // Memory write data
    input word_we;  // Write enable (active high)
    input byte_we;  // Write enable (active high)

    wire           valid_address;

    // Memory segments
    reg     [63:0] data_seg      [0:data_words-1];

    // Verilog implementation stuff
    integer        i;

    initial begin
        // Initialize memory (prevents x-pessimism problem)
        for (i = 0; i < data_words; i = i + 1) data_seg[i] = 64'b0;

        // Grab initial memory values
        $readmemh("memory.text.mem", data_seg);
        $readmemh("memory.data.mem", data_seg);
    end

    assign valid_address = (addr >= data_start) && (addr < (data_start + data_words));

    wire [13:0] index = addr[16:3];
    wire [63:0] d_out = data_seg[index];
    // TODO 32bit read
    assign data_out = d_out;
    assign inst = (inst_addr[2] == 1'b0) ? data_seg[inst_addr[16:3]][31:0] : data_seg[inst_addr[16:3]][63:32];

    always @(negedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            for (i = 0; i < data_words; i = i + 1) data_seg[i] <= 64'b0;
            $readmemh("memory.text.mem", data_seg);
            $readmemh("memory.data.mem", data_seg);
        end else if (valid_address == 1'b1) begin
            if (word_we == 1'b1) data_seg[index] <= data_in;
            else begin
                if (byte_we == 1'b1) begin
                    data_seg[index] <= (d_out & ~(64'hff << (8*(addr[2:0])))) | ((data_in & 64'hff) << (8*(addr[2:0])));
                end
            end
        end
    end


endmodule  // data_mem
