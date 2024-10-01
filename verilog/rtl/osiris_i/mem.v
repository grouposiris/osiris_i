//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    instruction_mem.v
// Date:        15.05.2024
// Reviewer:    Rafael Oliveira
// Revision:    1.0
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     Osiris I
// Block:       instruction_mem
// Description: Verilog module for the 64KB memory. RAM memory
////////////////////////////////////////////////////////////////////////////////

module mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16, MEM_SIZE=64) (
    input  wire                   clk,                 // Clock
    input  wire                   rst,                 // Reset
    input  wire [ADDR_WIDTH-1:0]  wb_adr_i,            // Wishbone address input
    input  wire [DATA_WIDTH-1:0]  wb_dat_i,            // Wishbone data input
    input  wire                   wb_we_i,             // Wishbone write enable
    input  wire                   wb_stb_i,            // Wishbone strobe
    input  wire                   wb_cyc_i,            // Wishbone cycle
    output wire [DATA_WIDTH-1:0]  wb_dat_o,            // Wishbone data output
    output reg                    wb_ack_o             // Wishbone acknowledge
);
    
    reg [DATA_WIDTH-1:0] mem [0:(MEM_SIZE*1024/4)-1];  // 64KB Memory, 32-bit wide (16-bit addressing)

    always @(posedge clk) begin
        if (rst) begin
            wb_ack_o <= 0;
        end else if (wb_cyc_i && wb_stb_i) begin
            wb_ack_o <= 1;
            if (wb_we_i) begin
                mem[wb_adr_i] <= wb_dat_i;       // Write operation
            end
        end else begin
            wb_ack_o <= 0;
        end
    end

    assign wb_dat_o = (wb_cyc_i && wb_stb_i && !wb_we_i) ? mem[wb_adr_i] : {DATA_WIDTH{1'b0}}; // Read operation

endmodule
