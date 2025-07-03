import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
import structures::STORE_WORD;
import structures::STORE_DWORD;
import structures::mem_load_type_t;
import structures::NO_LOAD;
import structures::LOAD_BYTE;
import structures::LOAD_WORD;
import structures::LOAD_DWORD;

module data_mem #(
    // size of data segment
    parameter DATA_LEN = 'h20000,  // 0x4000 * 8, unit: byte
    parameter INDEX_LEN = $clog2(DATA_LEN)
) (
    output logic [63:0] data_out,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] addr  /* verilator public */,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] data_in,
    input logic flush,
    input logic signed_type,
    input mem_load_type_t mem_load_type,
    input mem_store_type_t mem_store_type,
    input logic clk,
    input logic reset,
    output logic [31:0] inst,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] inst_addr
    /* verilator lint_on UNUSEDSIGNAL */
);
    initial begin
        // Grab initial memory values
        $readmemh("memory.mem", data_seg);
    end

    logic [7:0] data_seg[0:DATA_LEN-1]  /* verilator public */;

    logic [INDEX_LEN-1:0] baddr, i_baddr;

    always_comb begin
        baddr   = addr[INDEX_LEN-1:0];
        i_baddr = inst_addr[INDEX_LEN-1:0];
    end

    // TODO move to async
    always_comb begin
        unique case (mem_load_type)
            LOAD_BYTE: data_out = {{56{signed_type & data_seg[baddr][7]}}, data_seg[baddr]};

            LOAD_WORD:
            data_out = {
                {32{signed_type & data_seg[baddr+3][7]}},
                data_seg[baddr+3],
                data_seg[baddr+2],
                data_seg[baddr+1],
                data_seg[baddr+0]
            };

            LOAD_DWORD:
            data_out = {
                data_seg[baddr+7],
                data_seg[baddr+6],
                data_seg[baddr+5],
                data_seg[baddr+4],
                data_seg[baddr+3],
                data_seg[baddr+2],
                data_seg[baddr+1],
                data_seg[baddr+0]
            };
            NO_LOAD: data_out = 'x;  // no load
        endcase

        if (!flush)
            inst = {
                data_seg[i_baddr+3], data_seg[i_baddr+2], data_seg[i_baddr+1], data_seg[i_baddr+0]
            };
        else inst = '0;
    end

    always_ff @(negedge clk or posedge reset) begin
        // TODO reset behavior
        unique case (mem_store_type)
            STORE_BYTE: data_seg[baddr] <= data_in[7:0];

            STORE_WORD: begin
                data_seg[baddr+0] <= data_in[7:0];
                data_seg[baddr+1] <= data_in[15:8];
                data_seg[baddr+2] <= data_in[23:16];
                data_seg[baddr+3] <= data_in[31:24];
            end

            STORE_DWORD: begin
                data_seg[baddr+0] <= data_in[7:0];
                data_seg[baddr+1] <= data_in[15:8];
                data_seg[baddr+2] <= data_in[23:16];
                data_seg[baddr+3] <= data_in[31:24];
                data_seg[baddr+4] <= data_in[39:32];
                data_seg[baddr+5] <= data_in[47:40];
                data_seg[baddr+6] <= data_in[55:48];
                data_seg[baddr+7] <= data_in[63:56];
            end

            NO_STORE: ;  // NO_STORE
        endcase
    end
endmodule  // data_mem
