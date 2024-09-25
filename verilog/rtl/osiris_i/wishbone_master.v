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

module wishbone_master #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    clk,
    rst,
    i_pc_IF,
    i_mem_write_M,
    i_data_addr_M,
    i_write_data_M,
    o_instr_ID,
    o_read_data_M,
    wb_adr_o, 
    wb_dat_o,
    wb_we_o,
    wb_cyc_o,
    wb_stb_o,
    wb_dat_i,
    wb_ack_i
);

// ------------------------------------------
// IO declaration
// ------------------------------------------
    input  wire clk;
    input  wire rst;

    // Interface with osiris_i_core
    input wire [DATA_WIDTH-1:0] i_pc_IF;
    input wire                  i_mem_write_M;
    input wire [DATA_WIDTH-1:0] i_data_addr_M;
    input wire [DATA_WIDTH-1:0] i_write_data_M;

    output  wire [DATA_WIDTH-1:0] o_instr_ID;
    output  wire [DATA_WIDTH-1:0] o_read_data_M;

    // Wishbone Interface
    input  wire [DATA_WIDTH-1:0] wb_dat_i;     // Data input
    input  wire                  wb_ack_i;     // Acknowledge
    
    output reg  [ADDR_WIDTH-1:0] wb_adr_o;     // Address output
    output reg  [DATA_WIDTH-1:0] wb_dat_o;     // Data output
    output reg                   wb_we_o;      // Write enable
    output reg                   wb_stb_o;     // Strobe
    output reg                   wb_cyc_o;     // Cycle valid


// ------------------------------------------
// Signals deinitions
// ------------------------------------------

    // FSM States
    typedef enum logic [1:0] {
        IDLE,
        READ,
        WRITE,
        WAIT_ACK
    } state_t;

    state_t state, next_state;

    // Local signals
    reg [DATA_WIDTH-1:0] addr; // Address for read/write operations


// ------------------------------------------
// Logic
// ------------------------------------------
    // Sequential Logic: State Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // state <= IDLE;
            // wb_cyc_o <= 0;
            // wb_stb_o <= 0;
            // wb_we_o <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Combinational Logic: Next State and Outputs
    always @* begin
        // Default assignments
        next_state = state;
        wb_cyc_o = 0;
        wb_stb_o = 0;
        wb_we_o = 0;

        case (state)
            IDLE: begin
                // When a request is made from the core
                if (i_mem_write_M) begin
                    // Prepare for writing
                    wb_adr_o = i_data_addr_M;   // address from core
                    wb_dat_o = i_write_data_M;  // data from core
                    wb_we_o = i_mem_write_M;    // Write enable signal
                    wb_cyc_o = 1;               // Start cycle
                    wb_stb_o = 1;               // Enable strobe
                    next_state = WRITE;         // Move to WRITE state
                end else begin
                    // Prepare for reading
                    wb_stb_o = 1'b1;
                    wb_we_o = 1'b0;               // read operation
                    wb_adr_o = i_pc_IF;           // address instruction fetch
                    next_state = READ;          // Move to READ state
                end
            end
            
            READ: begin
                if (wb_ack_i) begin
                    next_state = IDLE; 
                end else begin
                    next_state = WAIT_ACK; 
                end
            end
            
            WRITE: begin
                if (wb_ack_i) begin
                    next_state = IDLE; 
                end else begin
                    next_state = WAIT_ACK; 
                end
            end
            
            WAIT_ACK: begin
                if (wb_ack_i) begin
                    next_state = IDLE; 
                end
            end
        endcase
    end

    assign o_read_data_M = (state == READ && wb_ack_i) ? wb_dat_i : 0;
    assign o_instr_ID = (state == READ && wb_ack_i) ? wb_dat_i : 0;

endmodule

