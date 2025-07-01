import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
import structures::STORE_WORD;
import structures::STORE_DWORD;

module data_mem #(
    // size of data segment
    parameter data_words = 'h4000,
    parameter index_bits = $clog2(data_words)
) (
    output logic [63:0] data_out,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] addr  /* verilator public */,
    /* verilator lint_on UNUSEDSIGNAL */
    input logic [63:0] data_in,
    input mem_store_type_t mem_store_type,
    input logic clk,
    input logic reset,
    output logic [31:0] inst,
    /* verilator lint_off UNUSEDSIGNAL */
    input logic [63:0] inst_addr
    /* verilator lint_on UNUSEDSIGNAL */
);
    // Memory segments
    // note: logic is a 0/1 type not a 4-state type
    logic   [63:0] data_seg[0:data_words-1]  /* verilator public */;

    // Verilog implementation stuff
    integer        i;

    initial begin
        // Grab initial memory values
        $readmemh("memory.mem", data_seg);
    end

    wire [index_bits-1:0] index = addr[index_bits+2:3], inst_index = inst_addr[index_bits+2:3];
    assign data_out = {
        data_seg[index][7:0],
        data_seg[index][15:8],
        data_seg[index][23:16],
        data_seg[index][31:24],
        data_seg[index][39:32],
        data_seg[index][47:40],
        data_seg[index][55:48],
        data_seg[index][63:56]
    };

    always_comb begin
        if (inst_addr[2])
            inst = {
                data_seg[inst_index][7:0],
                data_seg[inst_index][15:8],
                data_seg[inst_index][23:16],
                data_seg[inst_index][31:24]
            };
        else
            inst = {
                data_seg[inst_index][39:32],
                data_seg[inst_index][47:40],
                data_seg[inst_index][55:48],
                data_seg[inst_index][63:56]
            };
    end

    always @(negedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < data_words; i = i + 1) data_seg[i] <= 'b0;
            $readmemh("memory.mem", data_seg);
        end else begin
            unique case (mem_store_type)
                STORE_BYTE:
                unique case (addr[2:0])
                    'd7: data_seg[index][7:0] <= data_in[7:0];
                    'd6: data_seg[index][15:8] <= data_in[7:0];
                    'd5: data_seg[index][23:16] <= data_in[7:0];
                    'd4: data_seg[index][31:24] <= data_in[7:0];
                    'd3: data_seg[index][39:32] <= data_in[7:0];
                    'd2: data_seg[index][47:40] <= data_in[7:0];
                    'd1: data_seg[index][55:48] <= data_in[7:0];
                    'd0: data_seg[index][63:56] <= data_in[7:0];
                endcase
                STORE_WORD:
                if (addr[2])
                    data_seg[index][31:0] <= {
                        data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]
                    };
                else
                    data_seg[index][63:32] <= {
                        data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]
                    };
                STORE_DWORD: begin
                    data_seg[index] <= {
                        data_in[7:0],
                        data_in[15:8],
                        data_in[23:16],
                        data_in[31:24],
                        data_in[39:32],
                        data_in[47:40],
                        data_in[55:48],
                        data_in[63:56]
                    };
                end
                NO_STORE: ;  // we = 0
            endcase
        end
    end
endmodule  // data_mem
