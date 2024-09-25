//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    next_pc.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       next_pc_tb
// Description: Calculate the address fro the next intruction to be fetched from
//              instruction memory
//////////////////////////////////////////////////////////////////////////////

module next_pc ( 
    clk,
    i_pc_target_EX,
    i_pc_src_EX,
    i_rst_IF,
    i_en_IF,
    o_pcplus4_IF,
    o_pc_IF
);

// ------------------------------------------
// IO declaration
// ------------------------------------------
    input   logic               clk;
    input   logic   [31:0]      i_pc_target_EX;
    input   logic               i_pc_src_EX;
    input   logic               i_rst_IF;
    input   logic               i_en_IF;

    output  reg     [31:0]      o_pc_IF;
    output  reg     [31:0]      o_pcplus4_IF;
                                                          
// ------------------------------------------
// Localparams
// ------------------------------------------

// ------------------------------------------
// Signals deinitions
// ------------------------------------------
    logic [31:0]    muxed_input;
    logic [31:0]    current_pc;   
    logic [31:0]    pc_plus_4;

// ------------------------------------------
// Logic
// ------------------------------------------
    // next pc origin
    always @(*) begin
        if (!i_pc_src_EX) begin
            muxed_input = pc_plus_4;
        end
        else begin
            muxed_input = i_pc_target_EX;
        end
    end

    always @(posedge clk or posedge i_rst_IF) begin
        if (i_rst_IF) begin
            current_pc <= 32'h0; 
            pc_plus_4 <= 32'h4;
        end
        else begin
            if (i_en_IF) begin
                current_pc <= muxed_input;              // Load the muxed input
                pc_plus_4 <= muxed_input + 32'h4;       // PC+4 
            end
        end
    end

    assign o_pc_IF = current_pc;
    assign o_pcplus4_IF = pc_plus_4;

endmodule
