//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    osiris_i.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       osiris_i
// Description: Verilog module osiris_i
////////////////////////////////////////////////////////////////////////////////
module osiris_i #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32) (
    input  wire                   clk,                 // Clock
    input  wire                   rst,                 // Reset
    input  wire [DATA_WIDTH-1:0]  wb_dat_i,            // Data input from the Wishbone master
    input  wire                   wb_we_i,             // Write enable input from the Wishbone master
    input  wire                   wb_stb_i,            // Strobe input from the Wishbone master
    input  wire                   wb_cyc_i,            // Cycle valid input from the Wishbone master
    input  wire [ADDR_WIDTH-1:0]  wb_adr_i,            // Address input from the Wishbone master
    output wire [DATA_WIDTH-1:0]  wb_dat_o,            // Data output to the Wishbone master
    output wire                   wb_ack_o             // Acknowledge output to Wishbone master
);

// ------------------------------------------
// Internal Signals for Core and Wishbone
// ------------------------------------------
wire [DATA_WIDTH-1:0] pc_IF;           // Program counter from core (IF stage)
wire                  mem_write_M;     // Memory write signal from core (M stage)
wire [DATA_WIDTH-1:0] data_addr_M;     // Data address from core (M stage)
wire [DATA_WIDTH-1:0] write_data_M;    // Data to write from core (M stage)
wire [DATA_WIDTH-1:0] instr_ID;        // Instruction input to core (from Wishbone)
wire [DATA_WIDTH-1:0] read_data_M;     // Data read input to core (from Wishbone)

// ------------------------------------------
// Instantiate the core module
// ------------------------------------------
core #(.DATA_WIDTH(DATA_WIDTH)) U_CORE (
    .clk(clk),
    .rst(rst),
    .i_instr_ID(instr_ID),              // Instruction input from Wishbone slave
    .i_read_data_M(read_data_M),        // Read data from Wishbone slave
    .o_pc_IF(pc_IF),                    // Program counter output to Wishbone slave
    .o_mem_write_M(mem_write_M),        // Memory write enable to Wishbone slave
    .o_data_addr_M(data_addr_M),        // Data address output to Wishbone slave
    .o_write_data_M(write_data_M)       // Data to write output to Wishbone slave
);

// ------------------------------------------
// Instantiate the wishbone_slave module
// ------------------------------------------
wishbone_master #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) U_WISHBONE_SLAVE (
    .clk(clk),
    .rst(rst),
    .wb_adr_i(wb_adr_i),                // Address input from Wishbone master
    .wb_dat_i(wb_dat_i),                // Data input from Wishbone master
    .wb_we_i(wb_we_i),                  // Write enable input from Wishbone master
    .wb_stb_i(wb_stb_i),                // Strobe input from Wishbone master
    .wb_cyc_i(wb_cyc_i),                // Cycle valid input from Wishbone master
    .wb_dat_o(wb_dat_o),                // Data output to Wishbone master
    .wb_ack_o(wb_ack_o),                // Acknowledge output to Wishbone master
    
    // Core interface signals
    .i_instr_ID(instr_ID),              // Instruction input to core
    .i_read_data_M(read_data_M),        // Read data input to core
    .o_pc_IF(pc_IF),                    // Program counter output from core
    .o_mem_write_M(mem_write_M),        // Memory write enable from core
    .o_data_addr_M(data_addr_M),        // Data address output from core
    .o_write_data_M(write_data_M)       // Write data output from core
);

endmodule

