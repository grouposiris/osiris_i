/// sta-blackbox
module mem_byte #(
    parameter DATA_WIDTH  = 32,
    parameter MEM_SIZE_KB = 1    // Memory size in KB
) (
    clk,  // Clock
    rst,  // Reset
    // input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    wb_adr_i,  // Adjusted address input width
    wb_dat_i,  // Wishbone data input
    wb_we_i,  // Wishbone write enable
    wb_stb_i,  // Wishbone strobe
    wb_cyc_i,  // Wishbone cycle
    funct3,
    wb_dat_o,  // Wishbone data output
    wb_ack_o  // Wishbone acknowledge
);

    // Calculate total memory size in bytes
    localparam        MEM_SIZE_BYTES = MEM_SIZE_KB * 128;  // convert KB to Bytes --> total Bytes = 1000 Bytes
    // localparam MEM_DEPTH = (MEM_SIZE_KB * 1024 * 8) / DATA_WIDTH;

    input wire clk;  // Clock
    input wire rst;  // Reset
    input wire [$clog2(MEM_SIZE_BYTES)-1:0] wb_adr_i;  // Adjusted address input width // if MEM_SIZE_BYTES = 256, clog2(MEM_SIZE_BYTES) = 8 bits for addressing
    input wire [DATA_WIDTH-1:0] wb_dat_i;  // Wishbone data input
    input wire wb_we_i;  // Wishbone write enable
    input wire wb_stb_i;  // Wishbone strobe
    input wire wb_cyc_i;  // Wishbone cycle
    input wire [2:0] funct3;  // RISC-V funct3 field to specify operation
    output wire [DATA_WIDTH-1:0] wb_dat_o;  // Wishbone data output
    output reg wb_ack_o;  // Wishbone acknowledge

endmodule
