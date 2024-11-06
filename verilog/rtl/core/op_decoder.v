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
    input logic [4:0] i_op;
    input logic [2:0] i_funct_3;
    input logic i_funct_7_5;

    output logic o_jump_ID;
    output logic o_branch_ID;
    output logic o_reg_write_ID;
    output logic [1:0] o_result_src_ID;
    output logic o_mem_write_ID;
    output logic o_alu_src_ID;
    output logic [2:0] o_imm_src_ID;
    output logic [2:0] o_alu_op;
    output logic o_addr_src_ID;
    output logic o_fence_ID;

    localparam logic [2:0] OP_LUI = 3'b000,  // 0 else: LUI
    OP_ARITH = 3'b001,  // 1 Arithmetic: R-type I-type
    OP_ADD_SUB = 3'b010,  // 2 add: R-type add, sub (just look at func7_bit5), load (imm + rs1), store (imm + rs1) , jalr (PC + imm), fence (???), auipc (PC + imm)
    OP_BRANCH = 3'b011,  // 3 branch
    OP_ADD = 3'b100;  // only JAL

    //localparam logic [4:0] AND = 5'b00000,  // 0 ok
    // OR = 5'b00001,  // 1 ok
    // XOR = 5'b00010,  // 2 ok
    // ADD = 5'b00011,  // 3 ok
    // SUB = 5'b00100,  // 4 check
    // SLL = 5'b00101,  // 5 ok
    // SRL = 5'b00110,  // 6 ok
    // SLT = 5'b00111,  // 7 check if it is signed comparison
    // SLTU = 5'b01000,  // 8 check unsigned
    // SRA = 5'b01001,  // 9 ok
    // BEQ = 5'b01010,  // 10 check -> // ' the ALU computes A − B and looks at the flags. If Z is asserted, the result is 0, so A = B. Otherwise, A is not equal to B.
    // BNE = 5'b01011,  // 11 check
    // BLT = 5'b01100,  // 12 check
    // BLTU = 5'b01101,  // 13 check
    // BGE = 5'b01110,  // 14 check
    // BGEU = 5'b01111,  // 15 check
    // LUI = 5'b10000,  // 16 ok
    // AUIPC = 5'b10001,  // 17 check
    // FENCE = 5'b10010,  // 18 dummy (check if it is necessary)
    // ECALL = 5'b10011,  // 19 dummy (check if it is necessary)
    // EBREAK = 5'b10100;  // 20 dummy (check if it is necessary)

    localparam logic [4:0] OP_R_TYPE = 5'b01100,  //
    OP_I_TYPE_LOAD = 5'b00000,  //
    OP_I_TYPE_ARITH = 5'b00100,  //
    OP_I_TYPE_JALR = 5'b11001,  //
    OP_J_TYPE_JAL = 5'b11011,  //
    OP_U_TYPE_LUI = 5'b01101,  //
    OP_U_TYPE_AUIPC = 5'b00101,  //
    OP_S_TYPE = 5'b01000,  //
    OP_B_TYPE = 5'b11000,  //
    OP_ECALL_EBREAK_TYPE = 5'b11100,  //
    OP_FENCE_TYPE = 5'b00011;  //


    // ------------------------------------------
    // Logic
    // ------------------------------------------

    assign o_jump_ID = (i_op == OP_J_TYPE_JAL) ? 1'b1 :  //
        (i_op == OP_I_TYPE_JALR) ? 1'b1 :  // 
        1'b0;  //ok

    assign o_branch_ID = (i_op == OP_B_TYPE) ? 1'b1 : 1'b0;  //ok

    assign o_reg_write_ID = (i_op == OP_U_TYPE_LUI | i_op == OP_U_TYPE_AUIPC |
                             i_op == OP_J_TYPE_JAL | i_op == OP_I_TYPE_JALR |  // ok
        i_op == OP_I_TYPE_LOAD | i_op == OP_I_TYPE_ARITH | i_op == OP_R_TYPE |
            i_op == OP_ECALL_EBREAK_TYPE) ? 1'b1 : 1'b0;

    // assign o_result_src_ID = (i_op == OP_U_TYPE_AUIPC) ?
    //     2'b11 : (i_op == 5'b11011) ? 2'b10 : (i_op == 5'b00000) ? 2'b01 :  // ok
    //     2'b00;

    // 00: alu
    // 01: PC + 4
    // 10: Data from Data Memory
    // 11:  PC + imm (comes from stage_execute.next_pc)
    // o_result_src_ID: write_back mux selection: stage_write_back.o_result_WB
    assign o_result_src_ID = (i_op == OP_R_TYPE) ? 2'b00 :  // ALU result
        // (i_op == OP_I_TYPE_LOAD) ? 2'b01 :  // PC + 4
        (i_op == OP_I_TYPE_LOAD) ? 2'b10 :  // 
        (i_op == OP_I_TYPE_ARITH) ? 2'b00 :  // ALU result
        (i_op == OP_I_TYPE_JALR) ? 2'b01 :  // Data from Data Memory
        (i_op == OP_J_TYPE_JAL) ? 2'b01 :  // PC + 4
        (i_op == OP_U_TYPE_LUI) ? 2'b00 :  // ALU result: add: 0 + imm ({upimm, 12'b0})
        (i_op == OP_U_TYPE_AUIPC) ? 2'b11 :  // next_pc result: add: PC + imm ({upimm, 12'b0})
        2'b00;  // bx

    assign o_mem_write_ID = (i_op == OP_S_TYPE) ? 1'b1 : 1'b0;  // ok

    assign o_alu_src_ID = (i_op == OP_U_TYPE_LUI | i_op == OP_U_TYPE_AUIPC |
                           i_op == OP_I_TYPE_JALR | i_op == OP_I_TYPE_LOAD |  // ok
        i_op == OP_S_TYPE | i_op == OP_I_TYPE_ARITH | i_op == OP_FENCE_TYPE) ? 1'b1 : 1'b0;

    assign o_imm_src_ID = (i_op == OP_U_TYPE_LUI) ?
        3'b100 : (i_op == OP_U_TYPE_AUIPC) ? 3'b100 : (i_op == OP_J_TYPE_JAL) ? 3'b011 :  // ok
        (i_op == OP_B_TYPE) ? 3'b010 : (i_op == OP_S_TYPE) ? 3'b001 : 3'b000;

    // assign o_alu_op = (i_op == OP_B_TYPE) ? 2'b11 :  //
    //     (i_op == OP_I_TYPE_ARITH & (i_funct_3 != 3'b000)) ? 2'b01 :  // ok
    //     (i_op == 5'b01100 & (i_funct_7_5 == 1'b1) & (i_funct_3 == 3'b000)) ? 2'b10 :  // 
    //     (i_op == 5'b01100 & (i_funct_3 != 3'b000)) ? 2'b01 : 2'b00;  // 



    // 00 else: LUI
    // 01 Arithmetic: R-type I-type
    // 10 add: R-type add, sub (just look at func7_bit5), load (imm + rs1), store (imm + rs1) , jalr (PC + imm), fence (???), auipc (PC + imm), ecall (??), ebreak (???)
    // 11 branch
    assign o_alu_op =
        // Branch instructions (e.g., BEQ, BNE)
        (i_op == OP_B_TYPE) ? OP_BRANCH :

        // // Immediate arithmetic instructions (e.g., AND, OR, etc.)
        // (i_op == OP_I_TYPE_ARITH) ? OP_ARITH :

        // Load instructions
        (i_op == OP_I_TYPE_LOAD) ? OP_ADD :

        // Store instructions
        (i_op == OP_S_TYPE) ? OP_ADD :


        // Immediate arithmetic instructions (e.g., ANDI, ORI, etc.)
        (i_op == OP_I_TYPE_ARITH) ? OP_ARITH :

        // Register-Register arithmetic instructions
        (i_op == OP_R_TYPE) ? (

        // SUB instruction (funct7[5] == 1 and funct3 == 000)
        (i_funct_3 == 3'b000) ? OP_ADD_SUB :

        // Other R-type instructions
        OP_ARITH) :

        // LUI instruction
        (i_op == OP_U_TYPE_LUI) ? OP_LUI :

        // AUIPC instruction
        (i_op == OP_U_TYPE_AUIPC) ? OP_ADD :

        // FENCE instruction
        (i_op == OP_FENCE_TYPE) ? OP_ADD_SUB :

        // ECALL and EBREAK instructions
        (i_op == OP_ECALL_EBREAK_TYPE) ? OP_ADD_SUB :

        // JALR instruction: PC = rs1 + imm, rd = PC + 4 (selects pc_plus4 instead of alu result)
        (i_op == OP_I_TYPE_JALR) ? OP_ADD :

        // JAL instruction: PC = PC + SignExt({imm20:1,1'b0}), rd = PC + 4;
        (i_op == OP_J_TYPE_JAL) ? OP_ADD :

        // // JAL instruction: PC = JTA, rd = PC + 4 (selects pc_plus4 instead of alu result)
        // (i_op == OP_J_TYPE_JAL) ? OP_ADD_SUB :


        // Default case
        // 2'bxx;
        OP_ADD_SUB;



    assign o_addr_src_ID = (i_op == OP_I_TYPE_JALR) ? 1'b1 : 1'b0;  //ok

    assign o_fence_ID = (i_op == OP_FENCE_TYPE) ? 1'b1 : 1'b0;  //ok


endmodule
