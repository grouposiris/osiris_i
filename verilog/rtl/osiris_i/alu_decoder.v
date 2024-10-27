//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    alu_decoder.v
// Date:        18.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       alu_decoder
// Description: Verilog module alu_decoder
////////////////////////////////////////////////////////////////////////////////

module alu_decoder (
    i_alu_op,
    i_funct_3,
    i_funct_7_5,
    o_alu_ctrl_ID
);


    // ------------------------------------------
    // IO declaration
    // ------------------------------------------
    input logic [1:0] i_alu_op;
    input logic [2:0] i_funct_3;
    input logic i_funct_7_5;
    output logic [4:0] o_alu_ctrl_ID;

    // ------------------------------------------
    // Logic
    // ------------------------------------------
    assign o_alu_ctrl_ID = (i_alu_op == 2'b00) ? 5'b00011 :  // ADD
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b111)) ? 5'b00000 :  // AND and ANDI
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b110)) ? 5'b00001 :  // OR and ORI
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b100)) ? 5'b00010 :  // XOR and XORI
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b001)) ? 5'b00101 :  // SLL and SLLI
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b101) & (i_funct_7_5 == 1'b0)) ?
            5'b00110 :  // SRL and SRLI
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b010)) ? 5'b00111 :  // SLT and SLTI
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b011)) ? 5'b01000 :  // SLTU and SLTIU
        ((i_alu_op == 2'b01) & (i_funct_3 == 3'b101) & (i_funct_7_5 == 1'b1)) ?
            5'b01001 :  // SRA and SRAI
        ((i_alu_op == 2'b11) & (i_funct_3 == 3'b000)) ? 5'b01010 :  // BEQ
        ((i_alu_op == 2'b11) & (i_funct_3 == 3'b001)) ? 5'b01011 :  // BNE
        ((i_alu_op == 2'b11) & (i_funct_3 == 3'b100)) ? 5'b01100 :  // BLT 
        ((i_alu_op == 2'b11) & (i_funct_3 == 3'b110)) ? 5'b01101 :  // BLTU
        ((i_alu_op == 2'b11) & (i_funct_3 == 3'b101)) ? 5'b01110 :  // BGE
        ((i_alu_op == 2'b11) & (i_funct_3 == 3'b111)) ? 5'b01111 :  // BGEU
        (i_alu_op == 2'b10) ? 5'b00100 :  // SUB
        5'bzzzz;

    //   ((i_alu_op == 2'b01) & (i_funct_3 == 3'b000))  ? 5'b10000 : // LUI 
    //    ((i_alu_op == 2'b01) & (i_funct_3 == 3'b111))  ? 5'b10001 : // AUIPC
    //    ((i_alu_op == 2'b01) & (i_funct_3 == 3'b111))  ? 5'b10010 : // FENCE
    //    ((i_alu_op == 2'b01) & (i_funct_3 == 3'b111))  ? 5'b10011 : // ECALL
    //    ((i_alu_op == 2'b01) & (i_funct_3 == 3'b111))  ? 5'b10100 : // EBREAK

endmodule

