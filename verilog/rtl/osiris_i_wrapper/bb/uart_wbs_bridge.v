/// sta-blackbox
module uart_wbs_bridge #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter BAUD_RATE = 9600,
    parameter CLOCK_FREQ = 50000000,  // 50 MHz,
    parameter CMD_READ = 8'h01,  // Command to read from memory and send data via UART
    parameter CMD_WRITE =
        8'hAA  // Command to write data received via UART to memory (changed value for distinction)
) (

    `ifdef USE_POWER_PINS
        inout vccd1,
        inout vssd1,
    `endif
    input  wire clk,
    input  wire rst,
    input  wire uart_rx,  // UART receive line
    output wire uart_tx,  // UART transmit line
    // * Added a signal to start the reception process to prevent unnecessary power consumption
    input  wire start_rx,

    // Wishbone signals
    output reg                   wb_cyc_o,  // Wishbone cycle
    output reg                   wb_stb_o,  // Wishbone strobe
    output reg                   wb_we_o,   // Wishbone write enable: 0 = read, 1 = write
    output reg  [ADDR_WIDTH-1:0] wb_adr_o,  // Wishbone address
    output reg  [DATA_WIDTH-1:0] wb_dat_o,  // Wishbone data output
    input  wire [DATA_WIDTH-1:0] wb_dat_i,  // Wishbone data input
    input  wire                  wb_ack_i   // Wishbone acknowledge
);


endmodule
