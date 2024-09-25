//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    opcode_decoder.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       opcode_decoder
// Description: Verilog module opcode_decoder responsible for identifing the 
//              instruction to be executed by the ALU
////////////////////////////////////////////////////////////////////////////////

module op_decoder (
    i_op,
    i_funct_3,
    i_funct_7_5,
    o_jump_ID,
    o_branch_ID,
    o_reg_write_ID,
    o_result_src_ID,
    o_mem_write_ID,
    o_alu_src_ID,
    o_imm_src_ID,
    o_alu_op,
    o_addr_src_ID,
    o_fence_ID
);

// ------------------------------------------
// IO declaration
// ------------------------------------------
    input   logic [4:0]         i_op;
    input   logic [2:0]         i_funct_3;
    input   logic               i_funct_7_5;

    output  logic               o_jump_ID;
    output  logic               o_branch_ID;
    output  logic               o_reg_write_ID;
    output  logic [1:0]         o_result_src_ID;
    output  logic               o_mem_write_ID;
    output  logic               o_alu_src_ID;
    output  logic [2:0]         o_imm_src_ID;
    output  logic [1:0]         o_alu_op;
    output  logic               o_addr_src_ID;
    output  logic               o_fence_ID;


// ------------------------------------------
// Logic
// ------------------------------------------

    assign o_jump_ID = (i_op == 5'b11011)  ? 1'b1 : 1'b0; //ok
    assign o_branch_ID = (i_op == 5'b11000)  ? 1'b1 : 1'b0; //ok

    assign o_reg_write_ID = (i_op == 5'b01101 | 
                            i_op == 5'b00101 |
                            i_op == 5'b11011 |
                            i_op == 5'b11001 | // ok
                            i_op == 5'b00000 |
                            i_op == 5'b00100 |
                            i_op == 5'b01100 |
                            i_op == 5'b11100 
                            )  ? 1'b1 : 1'b0;

    assign o_result_src_ID = (i_op == 5'b00101) ? 2'b11 :
                             (i_op == 5'b11011) ? 2'b10 : 
                             (i_op == 5'b00000) ? 2'b01 : // ok
                                                  2'b00 ;

    assign o_mem_write_ID = (i_op == 5'b01000)  ? 1'b1 : 1'b0; // ok

    assign o_alu_src_ID = (i_op == 5'b01101 | 
                            i_op == 5'b00101 |
                            i_op == 5'b11001 | 
                            i_op == 5'b00000 |  // ok
                            i_op == 5'b01000 |
                            i_op == 5'b00100 |
                            i_op == 5'b11100 
                            )  ? 1'b1 : 1'b0;

    assign o_imm_src_ID = (i_op == 5'b01101) ? 3'b100 :
                          (i_op == 5'b00101) ? 3'b100 : 
                          (i_op == 5'b11011) ? 3'b011 : // ok
                          (i_op == 5'b11000) ? 3'b010 : 
                          (i_op == 5'b01000) ? 3'b001 : 
                                               3'b000 ;

    assign o_alu_op = (i_op == 5'b11000) ? 2'b11 :
                      (i_op == 5'b00100 & (i_funct_3 != 3'b000)) ? 2'b01 : // ok
                      (i_op == 5'b01100 & (i_funct_7_5 == 1'b1) & (i_funct_3 == 3'b000)) ? 2'b10 : 
                      (i_op == 5'b01100 & (i_funct_3 != 3'b000)) ? 2'b01 :
                                                                   2'b00 ;

    assign o_addr_src_ID = (i_op == 5'b11001)  ? 1'b1 : 1'b0; //ok

    assign o_fence_ID = (i_op == 5'b00011) ? 1'b1 : 1'b0; //ok


endmodule
