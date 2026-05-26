`ifdef VERILATOR
// Behavioral subset of Vivado's xpm_memory_sdpram for Verilator builds.
//
// This intentionally models only the configuration used by data_mem:
// simple dual-port RAM, equal read/write widths, one write-enable lane,
// READ_LATENCY_B == 1, and no ECC.
module xpm_memory_sdpram #(
    parameter integer MEMORY_SIZE        = 2048,
    parameter         MEMORY_PRIMITIVE   = "auto",
    parameter         CLOCKING_MODE      = "common_clock",
    parameter         ECC_MODE           = "no_ecc",
    parameter         ECC_TYPE           = "NONE",
    parameter         ECC_BIT_RANGE      = "[7:0]",
    parameter         MEMORY_INIT_FILE   = "none",
    parameter         MEMORY_INIT_PARAM  = "",
    parameter integer USE_MEM_INIT       = 1,
    parameter integer USE_MEM_INIT_MMI   = 0,
    parameter         WAKEUP_TIME        = "disable_sleep",
    parameter integer AUTO_SLEEP_TIME    = 0,
    parameter integer MESSAGE_CONTROL    = 0,
    parameter integer USE_EMBEDDED_CONSTRAINT = 0,
    parameter         MEMORY_OPTIMIZATION     = "true",
    parameter integer CASCADE_HEIGHT          = 0,
    parameter         RAM_DECOMP              = "auto",
    parameter integer SIM_ASSERT_CHK          = 0,
    parameter integer WRITE_PROTECT           = 1,
    parameter integer IGNORE_INIT_SYNTH       = 0,

    parameter integer WRITE_DATA_WIDTH_A = 32,
    parameter integer BYTE_WRITE_WIDTH_A = WRITE_DATA_WIDTH_A,
    parameter integer ADDR_WIDTH_A       = $clog2(MEMORY_SIZE / WRITE_DATA_WIDTH_A),
    parameter         RST_MODE_A         = "SYNC",

    parameter integer READ_DATA_WIDTH_B  = WRITE_DATA_WIDTH_A,
    parameter integer ADDR_WIDTH_B       = $clog2(MEMORY_SIZE / READ_DATA_WIDTH_B),
    parameter         READ_RESET_VALUE_B = "0",
    parameter integer READ_LATENCY_B     = 2,
    parameter         WRITE_MODE_B       = "no_change",
    parameter         RST_MODE_B         = "SYNC"
) (
    input  wire                                               sleep,

    input  wire                                               clka,
    input  wire                                               ena,
    input  wire [(WRITE_DATA_WIDTH_A / BYTE_WRITE_WIDTH_A)-1:0] wea,
    input  wire [ADDR_WIDTH_A-1:0]                            addra,
    input  wire [WRITE_DATA_WIDTH_A-1:0]                      dina,
    input  wire                                               injectsbiterra,
    input  wire                                               injectdbiterra,

    input  wire                                               clkb,
    input  wire                                               rstb,
    input  wire                                               enb,
    input  wire                                               regceb,
    input  wire [ADDR_WIDTH_B-1:0]                            addrb,
    output logic [READ_DATA_WIDTH_B-1:0]                      doutb,
    output wire                                               sbiterrb,
    output wire                                               dbiterrb
);
    localparam integer NUM_WORDS = MEMORY_SIZE / READ_DATA_WIDTH_B;
    localparam integer WE_LANES  = WRITE_DATA_WIDTH_A / BYTE_WRITE_WIDTH_A;

    logic [READ_DATA_WIDTH_B-1:0] mem[0:NUM_WORDS-1]  /* verilator public */;

    assign sbiterrb = 1'b0;
    assign dbiterrb = 1'b0;

    initial begin
        if (WRITE_DATA_WIDTH_A != READ_DATA_WIDTH_B) begin
            $fatal("xpm_memory_sdpram_verilator: asymmetric widths are not modeled");
        end
        if (ADDR_WIDTH_A != ADDR_WIDTH_B) begin
            $fatal("xpm_memory_sdpram_verilator: asymmetric address widths are not modeled");
        end
        if (READ_LATENCY_B != 1) begin
            $fatal("xpm_memory_sdpram_verilator: only READ_LATENCY_B == 1 is modeled");
        end
        if (WE_LANES != 1) begin
            $fatal("xpm_memory_sdpram_verilator: only full-line writes are modeled");
        end

        doutb = '0;
        if (USE_MEM_INIT != 0 && MEMORY_INIT_FILE != "none") begin
            $readmemh(MEMORY_INIT_FILE, mem);
        end
    end

    always_ff @(posedge clka) begin
        if (!sleep && ena && wea[0]) begin
            mem[addra] <= dina;
        end
    end

    always_ff @(posedge clkb) begin
        if (rstb) begin
            doutb <= '0;
        end else if (!sleep && enb && regceb) begin
            doutb <= mem[addrb];
        end
    end
endmodule
`endif
