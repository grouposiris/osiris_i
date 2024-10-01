//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    instruction_mem.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       instruction_mem
// Description: Verilog module for the UART-Wishbone bridge
////////////////////////////////////////////////////////////////////////////////
module uart_wbs_bridge #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 uart_rx,        // UART receive line
    output wire                 uart_tx,        // UART transmit line
    output reg                  wb_cyc_o,       // Wishbone cycle
    output reg                  wb_stb_o,       // Wishbone strobe
    output reg                  wb_we_o,        // Wishbone write enable
    output reg [ADDR_WIDTH-1:0] wb_adr_o,       // Wishbone address
    output reg [DATA_WIDTH-1:0] wb_dat_o,       // Wishbone data output
    input  wire                 wb_ack_i        // Wishbone acknowledge
);

    reg [7:0]               uart_buffer;        // Buffer for receiving UART data
    reg [3:0]               byte_count;         // Byte counter
    reg [ADDR_WIDTH-1:0]    addr_reg;           // Address register
    reg [DATA_WIDTH-1:0]    data_reg;           // Data register
    reg [1:0]               state;              // State machine for UART interface

    // UART interface logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_count <= 0;
            wb_stb_o <= 0;
            wb_cyc_o <= 0;
            wb_we_o <= 0;
            uart_buffer <= 0;
            state <= 0;
        end else begin
            case (state)
                2'b00: begin
                    // Wait for a byte from UART
                    if (uart_rx_valid) begin
                        uart_buffer <= uart_rx_data; // Load received byte into buffer
                        byte_count <= 0;
                        state <= 2'b01;
                    end
                end
                2'b01: begin
                    // Load instruction data and address
                    if (byte_count == 0) begin
                        addr_reg[7:0] <= uart_buffer;
                        byte_count <= 1;
                    end else if (byte_count == 1) begin
                        addr_reg[ADDR_WIDTH-1:8] <= uart_buffer;
                        byte_count <= 2;
                    end else if (byte_count == 2) begin
                        data_reg[7:0] <= uart_buffer;
                        byte_count <= 3;
                    end else if (byte_count == 3) begin
                        data_reg[DATA_WIDTH-1:8] <= uart_buffer;
                        // Set Wishbone signals to write the data
                        wb_adr_o <= addr_reg;
                        wb_dat_o <= data_reg;
                        wb_we_o <= 1;
                        wb_stb_o <= 1;
                        wb_cyc_o <= 1;
                        state <= 2'b10;
                    end
                end
                2'b10: begin
                    // Wait for Wishbone acknowledge
                    if (wb_ack_i) begin
                        wb_stb_o <= 0;
                        wb_cyc_o <= 0;
                        wb_we_o <= 0;
                        state <= 2'b00;  // Go back to wait for next UART byte
                    end
                end
            endcase
        end
    end

    // UART logic (dummy for simulation, real UART implementation needed)
    assign uart_rx_valid = (uart_buffer != 8'h00);  // Simulate valid data when buffer is not zero
    assign uart_rx_data  = uart_buffer;              // Echo received data
    assign uart_tx       = uart_buffer[0];           // Simple transmit logic (just the LSB for testing)

endmodule

