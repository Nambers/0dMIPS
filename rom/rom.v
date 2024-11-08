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
    data_start = 64'h10000000, data_words = 'h1000,  /* 1 M */
    data_length = data_words * 8;

    input clk, reset;

    // Inputs and ouptuts: Port 1
    output [63:0] data_out;  // Memory read data
    output [31:0] inst;
    input [63:0] inst_addr;
    input [63:0] addr;  // Memory address
    input [63:0] data_in;  // Memory write data
    input word_we;  // Write enable (active high)
    input byte_we;  // Write enable (active high)

    wire    [20:0] index;
    wire           valid_address;
    wire    [63:0] d_out;

    // Memory segments
    reg     [63:0] data_seg      [0:data_words-1];

    // Verilog implementation stuff
    integer        i;

    always @(reset)
        if (reset == 1'b1) begin
            // Initialize memory (prevents x-pessimism problem)
            for (i = 0; i < data_words; i = i + 1) data_seg[i] = 64'b0;

            // Grab initial memory values
            $readmemh("memory.text.mem", data_seg);
            $readmemh("memory.data.mem", data_seg);
        end

    assign valid_address = (addr >= data_start) && (addr < (data_start + data_words));
    assign data_out = (addr[2] == 1'b0) ? data_seg[addr[23:3]][31:0] : data_seg[addr[23:3]][63:32];
    assign inst = (inst_addr[2] == 1'b0) ? data_seg[inst_addr[23:3]][31:0] : data_seg[inst_addr[23:3]][63:32];

    always @(negedge clk) begin
        if ((reset == 1'b0) && (valid_address == 1'b1)) begin
            if (word_we == 1'b1) data_seg[index] <= data_in;
            else begin
                if (byte_we == 1'b1) begin
                    data_seg[index] <= (d_out & ~(64'hff << (8*(addr[2:0])))) | ((data_in & 64'hff) << (8*(addr[2:0])));
                end
            end
        end
    end


endmodule  // data_mem
