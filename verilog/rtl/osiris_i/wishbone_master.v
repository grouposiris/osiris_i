//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    wishbone_client.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       wishbone_client
// Description: Verilog module wishbone_client
////////////////////////////////////////////////////////////////////////////////

module wishbone_master #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32) (
    input  wire                   clk,                  // Clock
    input  wire                   rst,                  // Reset
    input  wire [ADDR_WIDTH-1:0]  wb_adr_i,             // Address from the Wishbone master
    input  wire [DATA_WIDTH-1:0]  wb_dat_i,             // Data from the Wishbone master
    input  wire                   wb_we_i,              // Write enable signal from the Wishbone master
    input  wire                   wb_stb_i,             // Strobe signal from the Wishbone master
    input  wire                   wb_cyc_i,             // Cycle valid signal from the Wishbone master
    output reg  [DATA_WIDTH-1:0]  wb_dat_o,             // Data to the Wishbone master
    output reg                    wb_ack_o,             // Acknowledge signal to the Wishbone master

    // Interface to the core module
    output reg  [DATA_WIDTH-1:0]  i_instr_ID,           // Instruction to the core
    output reg  [DATA_WIDTH-1:0]  i_read_data_M,        // Data read from memory for the core
    input  wire [DATA_WIDTH-1:0]  o_pc_IF,              // PC from the core
    input  wire                   o_mem_write_M,        // Memory write signal from the core
    input  wire [DATA_WIDTH-1:0]  o_data_addr_M,        // Data address from the core
    input  wire [DATA_WIDTH-1:0]  o_write_data_M        // Data to write from the core
);

assign wb_dat_o = 32'b1;
assign wb_ack_o = 1'b1;
assign i_instr_ID = 32'b1;
assign i_read_data_M = 32'b1;
// TO DO
/*
// ------------------------------------------
// Local Signals
// ------------------------------------------
// reg  [32:0] mem ;  // Simple memory for storing data (adjust size as needed)
reg  [32:0] addr_reg;     // Register to hold the address
reg                   write_en;    // Internal write enable
reg                   read_en;     // Internal read enable


assign write_en =

// ------------------------------------------
// Wishbone Slave Logic
// ------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wb_ack_o <= 1'b0;
        wb_dat_o <= {DATA_WIDTH{1'b0}};
        write_en <= 1'b0;
        read_en <= 1'b0;
        // addr_reg <= {ADDR_WIDTH{1'b0}};
    end else begin
        wb_ack_o <= 1'b0;  // Default no acknowledge

        // Check for valid cycle and strobe signal
        if (wb_cyc_i && wb_stb_i) begin
            addr_reg <= wb_adr_i;

            // Wishbone Write Operation
            if (wb_we_i) begin
                write_en <= 1'b1;
                wb_ack_o <= 1'b1;  // Acknowledge write
            end

            // Wishbone Read Operation
            else begin
                read_en <= 1'b1;
                wb_ack_o <= 1'b1;  // Acknowledge read
            end
        end
    end
end

// ------------------------------------------
// Write Operation to Memory
// ------------------------------------------
always @(posedge clk) begin
    if (write_en) begin
        //mem <= wb_dat_i;
        write_en <= 1'b0;  // Clear write enable
    end
end

// ------------------------------------------
// Read Operation from Memory
// ------------------------------------------
always @(posedge clk) begin
    if (read_en) begin
        //wb_dat_o <= mem;
        wb_dat_o <= 32'b1;
        read_en <= 1'b0;  // Clear read enable
    end
end

// ------------------------------------------
// Core Interface Handling
// ------------------------------------------
// The core should receive instructions and memory data based on the Wishbone transactions.

always @(posedge clk or posedge rst) begin
    if (rst) begin
        i_instr_ID <= {DATA_WIDTH{1'b0}};
        i_read_data_M <= {DATA_WIDTH{1'b0}};
    end else begin
        if (wb_we_i && wb_cyc_i && wb_stb_i) begin
            // Handle memory write operation in the core
            if (o_mem_write_M) begin
               // mem <= o_write_data_M;  // Store data from core to memory
            end
        end else begin
            // Provide data for the core to execute from memory (fetch instructions)
            //i_instr_ID <= mem;  // Provide instruction to core
            i_instr_ID <= 32'b1;  // Provide instruction to core

            //i_read_data_M <= mem;  // Provide data to core
            i_read_data_M <= 32'hF;  // Provide data to core
        end
    end
end*/

endmodule
