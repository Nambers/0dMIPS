// only to simulation stdout
import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
import structures::STORE_HALF;
import structures::STORE_WORD;
import configurations::STDOUT_BASE_ADDR;

module stdout (
    input  logic                   clock,
    input  logic                   reset,
    input  logic                   enable,
    input  logic            [63:0] addr,
    input  mem_store_type_t        mem_store_type,
    input  logic            [63:0] w_data,
    output logic                   stdout_taken     /* verilator public */
);
    logic [63:0] buffer  /* verilator public */;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            buffer <= 64'h0;
        end else if (enable & (addr >= STDOUT_BASE_ADDR && addr < STDOUT_BASE_ADDR + 8)) begin
            unique case (mem_store_type)
                // auto append null terminator
                STORE_BYTE: buffer[63:64-8-8] <= {w_data[7:0], 8'b0};
                STORE_HALF:
                buffer[63:64-16-8] <= {w_data[7:0], w_data[15:8], 8'b0};
                STORE_WORD:
                buffer[63:64-32-8] <= {
                    w_data[7:0],
                    w_data[15:8],
                    w_data[23:16],
                    w_data[31:24],
                    8'b0
                };
                STORE_DWORD: begin
                    buffer <= {
                        w_data[7:0],
                        w_data[15:8],
                        w_data[23:16],
                        w_data[31:24],
                        w_data[39:32],
                        w_data[47:40],
                        w_data[55:48],
                        w_data[63:56]
                    };
                end
                NO_STORE: ;  // we = 0
            endcase
            stdout_taken <= 1'b1;
        end else begin
            stdout_taken <= 1'b0;
        end
    end
endmodule
