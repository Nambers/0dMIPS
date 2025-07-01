// only to simulation stdout
import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
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
                STORE_BYTE:
                unique case (addr[2:0])
                    'd7: buffer[7:0] <= w_data[7:0];
                    'd6: buffer[15:8] <= w_data[7:0];
                    'd5: buffer[23:16] <= w_data[7:0];
                    'd4: buffer[31:24] <= w_data[7:0];
                    'd3: buffer[39:32] <= w_data[7:0];
                    'd2: buffer[47:40] <= w_data[7:0];
                    'd1: buffer[55:48] <= w_data[7:0];
                    'd0: buffer[63:56] <= w_data[7:0];
                endcase
                STORE_WORD:
                if (addr[2])
                    buffer[31:0] <= {w_data[7:0], w_data[15:8], w_data[23:16], w_data[31:24]};
                else buffer[63:32] <= {w_data[7:0], w_data[15:8], w_data[23:16], w_data[31:24]};
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
