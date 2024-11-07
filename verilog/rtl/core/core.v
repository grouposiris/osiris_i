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
    o_funct3_MEM,
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

    output wire [2:0] o_funct3_MEM;
    output wire [DATA_WIDTH-1:0] o_pc_IF;  // Output program counter (IF stage)
    output wire o_mem_write_M;  // Output memory write enable (M stage)
    output wire [DATA_WIDTH-1:0] o_data_addr_M;  // Output data address (M stage)
    output wire [DATA_WIDTH-1:0] o_write_data_M;  // Output data to write (M stage)

    // ------------------------------------------
    // Signals deinitions
    // ------------------------------------------
    wire       pc_src_EX;
    wire       o_jump_ID;
    wire       o_branch_ID;
    wire       o_reg_write_ID;
    wire [1:0] o_result_src_ID;
    wire       o_mem_write_ID;
    wire [4:0] o_alu_ctrl_ID;
    wire       o_alu_src_ID;
    wire       o_addr_src_ID;
    wire [2:0] o_imm_src_ID;
    wire       o_fence_ID;

    wire       o_jump_EX;
    wire       o_branch_EX;
    wire       o_zero;

    wire [4:0] o_op;
    wire [2:0] o_funct3;
    wire       o_funct_7_5;

    wire [1:0] load_type;
    // ------------------------------------------
    // Logic
    // ------------------------------------------

    // ------------------------------------------
    // Instantiate Control Unit
    // ------------------------------------------
    control_unit U_CONTROL_UNIT (
        .i_op           (o_op),             // Opcode from datapath
        .i_funct_3      (o_funct3),         // Funct3 from datapath
        .i_funct_7_5    (o_funct_7_5),      // Funct7[5] from datapath
        .i_zero         (o_zero),           // Zero flag from datapath
        .i_branch_EX    (o_branch_EX),      // Branch signal from EX stage
        .i_jump_EX      (o_jump_EX),        // Jump signal from EX stage
        .o_pc_src_EX    (pc_src_EX),        // PC source from EX stage
        .o_jump_ID      (o_jump_ID),        // Jump signal for ID stage
        .o_branch_ID    (o_branch_ID),      // Branch signal for ID stage
        .o_reg_write_ID (o_reg_write_ID),   // RegWrite signal for ID stage
        .o_result_src_ID(o_result_src_ID),  // Result source signal for ID stage
        .o_mem_write_ID (o_mem_write_ID),   // Memory write enable signal for ID stage
        .o_alu_src_ID   (o_alu_src_ID),     // ALU source signal for ID stage
        .o_imm_src_ID   (o_imm_src_ID),     // Immediate source for ID stage
        .o_alu_ctrl_ID  (o_alu_ctrl_ID),    // ALU control signal for ID stage
        .o_addr_src_ID  (o_addr_src_ID),    // Address source for ID stage
        .o_fence_ID     (o_fence_ID)        // Fence signal for ID stage
    );


    // ------------------------------------------
    // Instantiate Datapath
    // ------------------------------------------
    datapath #(
        .DATA_WIDTH(DATA_WIDTH)
    ) U_DATAPATH (
        .clk            (clk),
        .rst            (rst),
        .i_pc_src_EX    (pc_src_EX),
        .i_jump_ID      (o_jump_ID),
        .i_branch_ID    (o_branch_ID),
        .i_reg_write_ID (o_reg_write_ID),
        .i_result_src_ID(o_result_src_ID),
        .i_mem_write_ID (o_mem_write_ID),
        .i_alu_ctrl_ID  (o_alu_ctrl_ID),
        .i_alu_src_ID   (o_alu_src_ID),
        .i_addr_src_ID  (o_addr_src_ID),
        .i_imm_src_ID   (o_imm_src_ID),
        .i_fence_ID     (o_fence_ID),
        .i_instr_IF     (i_instr_ID),       // Instruction input from instruction memory
        .i_read_data_M  (i_read_data_M),    // Data read from memory (optional)

        .o_jump_EX(o_jump_EX),
        .o_branch_EX(o_branch_EX),
        .o_zero(o_zero),
        .o_mem_write_M(o_mem_write_M),
        .o_write_data_M(o_write_data_M),
        .o_data_addr_M(o_data_addr_M),
        .o_op(o_op),
        .o_funct3(o_funct3),
        .o_funct_7_5(o_funct_7_5),
        .o_pc_IF(o_pc_IF),
        .o_funct3_MEM(o_funct3_MEM)
    );

endmodule
