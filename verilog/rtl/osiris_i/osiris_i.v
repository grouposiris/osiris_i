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
    input  wire clk,                 
    input  wire rst,                 
    input  wire [DATA_WIDTH-1:0] wb_dat_i,  
    input  wire                    wb_ack_i,           
    output wire [ADDR_WIDTH-1:0] wb_adr_o, 
    output wire [DATA_WIDTH-1:0] wb_dat_o,
    output wire wb_we_o,             
    output wire wb_stb_o,           
    output wire wb_cyc_o           
);

// ------------------------------------------
// Signals
// ------------------------------------------
wire [DATA_WIDTH-1:0] pc_IF;     
wire                  mem_write_M;                
wire [DATA_WIDTH-1:0] data_addr_M;
wire [DATA_WIDTH-1:0] write_data_M; 
wire [DATA_WIDTH-1:0] instr_ID;  
wire [DATA_WIDTH-1:0] read_data_M; 

// ------------------------------------------
// Instantiate the osiris_i_core
// ------------------------------------------
core #(.DATA_WIDTH(DATA_WIDTH)) U_CORE (
    .clk(clk),
    .rst(rst),
    .i_instr_ID(instr_ID),          
    .i_read_data_M(read_data_M),    
    .o_pc_IF(pc_IF),               
    .o_mem_write_M(mem_write_M),   
    .o_data_addr_M(data_addr_M),  
    .o_write_data_M(write_data_M)  
);

// ------------------------------------------
// Instantiate the wishbone_master
// ------------------------------------------
wishbone_master #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) U_WISHBONE_MASTER (
    .clk(clk),
    .rst(rst),
    .i_pc_IF(pc_IF),                
    .i_mem_write_M(mem_write_M),   
    .i_data_addr_M(data_addr_M),    
    .i_write_data_M(write_data_M),  
    .o_instr_ID(instr_ID),          
    .o_read_data_M(read_data_M),   
    .wb_adr_o(wb_adr_o),           
    .wb_dat_o(wb_dat_o),           
    .wb_we_o(wb_we_o),             
    .wb_stb_o(wb_stb_o),            
    .wb_cyc_o(wb_cyc_o),            
    .wb_dat_i(wb_dat_i),            
    .wb_ack_i(wb_ack_i)            
);

endmodule
