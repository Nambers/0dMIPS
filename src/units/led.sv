import structures::mem_store_type_t;
import structures::NO_STORE;
import structures::STORE_BYTE;
import structures::STORE_HALF;
import structures::STORE_WORD;
import configurations::LED_BASE_ADDR;

// 4 LEDs on board
module led #(
    parameter LED_INIT = 4'b1101
) (
    input  logic                   clock,
    input  logic                   reset,
    input  logic                   enable,
    input  logic            [63:0] addr,
    input  mem_store_type_t        mem_store_type,
    input  logic            [63:0] w_data,
    output logic            [ 3:0] led_out,
    output logic                   led_taken        /* verilator public */
);

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            led_out   <= LED_INIT;  // init value for debug purpose
            led_taken <= 1'b0;
        end else if (enable & (addr >= LED_BASE_ADDR && addr < LED_BASE_ADDR + 8)) begin
            if (mem_store_type != NO_STORE) begin
                led_out <= w_data[3:0];
            end
            led_taken <= 1'b1;
        end else begin
            led_taken <= 1'b0;
        end
    end
endmodule
