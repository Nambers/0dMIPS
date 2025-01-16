// only to simulation stdout
import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
import structures::STORE_WORD;
import configurations::STDOUT_BASE_ADDR;

module stdout (
    input  logic                   clock,
    input  logic                   reset,
    input  logic            [63:0] addr,
    input  mem_store_type_t        mem_store_type,
    input  logic            [63:0] w_data,
    output logic                   stdout_taken     /* verilator public */
);
    logic [63:0] buffer  /* verilator public */;
    wire [63:0] musk_origin = buffer & (~(64'hff << (8*(addr[2:0])))),
                new_data = (w_data & 64'hff) << (8 * (addr[2:0]));

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            buffer <= 64'h0;
        end else if (addr >= STDOUT_BASE_ADDR && addr < STDOUT_BASE_ADDR + 8) begin
            unique case (mem_store_type)
                STORE_BYTE: buffer <= musk_origin | new_data;
                STORE_WORD: begin
                    if (addr[2]) buffer[31:0] <= w_data[31:0];
                    else buffer[63:32] <= w_data[31:0];
                end
                STORE_DWORD: buffer <= w_data;
                default: ;
            endcase
        end
    end
endmodule
