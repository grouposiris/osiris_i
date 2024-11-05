/// sta-blackbox
module mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 10, MEM_SIZE=1) (
    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif
    input  wire                   clk,                 // Clock
    input  wire                   rst,                 // Reset
    input  wire [ADDR_WIDTH-1:0]  wb_adr_i,            // Wishbone address input
    input  wire [DATA_WIDTH-1:0]  wb_dat_i,            // Wishbone data input
    input  wire                   wb_we_i,             // Wishbone write enable
    input  wire                   wb_stb_i,            // Wishbone strobe
    input  wire                   wb_cyc_i,            // Wishbone cycle
    output wire [DATA_WIDTH-1:0]  wb_dat_o,            // Wishbone data output
    output reg                    wb_ack_o             // Wishbone acknowledge
);


endmodule
