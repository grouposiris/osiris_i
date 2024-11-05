//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    core.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       core
// Description: Verilog module core
////////////////////////////////////////////////////////////////////////////////
/// sta-blackbox


module core #(
    parameter DATA_WIDTH = 32
) (
 `ifdef USE_POWER_PINS
    vccd1,
    vssd1,
`endif
    clk,
    rst,
    i_instr_ID,
    i_read_data_M,
    o_pc_IF,
    o_mem_write_M,
    o_data_addr_M,
    o_write_data_M
);


    // ------------------------------------------
    // IO declaration
    // ------------------------------------------
`ifdef USE_POWER_PINS
    inout vccd1;
    inout vssd1;
`endif
    input wire clk;
    input wire rst;
    input wire [DATA_WIDTH-1:0] i_instr_ID;  // Input instruction from instruction memory
    input wire [DATA_WIDTH-1:0] i_read_data_M;  // Input data from memory
    // input wire [DATA_WIDTH-1:0] loaded_data;  // load data

    output wire [DATA_WIDTH-1:0] o_pc_IF;  // Output program counter (IF stage)
    output wire o_mem_write_M;  // Output memory write enable (M stage)
    output wire [DATA_WIDTH-1:0] o_data_addr_M;  // Output data address (M stage)
    output wire [DATA_WIDTH-1:0] o_write_data_M;  // Output data to write (M stage)

                                    
    
endmodule
