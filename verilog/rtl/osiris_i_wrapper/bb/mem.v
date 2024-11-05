/// sta-blackbox
module mem #(
    parameter DATA_WIDTH = 32,
    // parameter ADDR_WIDTH = 14   // 13 = 32kB, 14 = 64KB
    parameter MEM_SIZE   = 1   // in KB
) (
`ifdef USE_POWER_PINS
    vccd1,
    vssd1,
`endif
    clk,  // Clock
    rst,  // Reset
    // input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    wb_adr_i,  // Adjusted address input width
    wb_dat_i,  // Wishbone data input
    wb_we_i,  // Wishbone write enable
    wb_stb_i,  // Wishbone strobe
    wb_cyc_i,  // Wishbone cycle
    wb_dat_o,  // Wishbone data output
    wb_ack_o  // Wishbone acknowledge
);

    localparam MEM_DEPTH = (MEM_SIZE * 128 * 8) / DATA_WIDTH;

    // Define the memory array with calculated depth
    `ifdef USE_POWER_PINS
    inout vccd1;
    inout vssd1;
    `endif
    input wire clk;  // Clock
    input wire rst;  // Reset
    // input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    input wire [$clog2(MEM_DEPTH)-1:0] wb_adr_i;  // Adjusted address input width
    input wire [DATA_WIDTH-1:0] wb_dat_i;  // Wishbone data input
    input wire wb_we_i;  // Wishbone write enable
    input wire wb_stb_i;  // Wishbone strobe
    input wire wb_cyc_i;  // Wishbone cycle
    output wire [DATA_WIDTH-1:0] wb_dat_o;  // Wishbone data output
    output reg wb_ack_o;  // Wishbone acknowledge

endmodule
