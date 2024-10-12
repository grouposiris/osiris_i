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

module osiris_i #(
    parameter DATA_WIDTH = 32,
    ADDR_WIDTH = 32,
    parameter BAUD_RATE = 9600,
    parameter CLOCK_FREQ = 50000000  // 50 MHz
) (
    input wire clk,
    input wire rst,
    input wire uart_rx,
    input wire select_mem,
    input wire start_rx,  // * Added a signal to start the reception process to prevent unnecessary power consumption
    output wire uart_tx
);

    // ------------------------------------------
    // Internal Signals for Core and Wishbone
    // ------------------------------------------

    // wire [DATA_WIDTH-1:0] instr_wb_dat_o;
    // wire [DATA_WIDTH-1:0] data_wb_dat_o;
    wire [DATA_WIDTH-1:0] wb_dat_o;
    wire [ADDR_WIDTH-1:0] wb_adr;
    wire [ADDR_WIDTH-1:0] adr;
    wire wb_we, wb_stb, wb_cyc, wb_ack;


    wire [DATA_WIDTH-1:0] pc_IF;  // Program counter from core (IF stage)
    wire                  mem_write_M;  // Memory write signal from core (M stage)
    wire [DATA_WIDTH-1:0] data_addr_M;  // Data address from core (M stage)
    wire [DATA_WIDTH-1:0] write_data_M;  // Data to write from core (M stage)
    wire [DATA_WIDTH-1:0] instr_ID;  // Instruction input to core (from Wishbone)
    wire [DATA_WIDTH-1:0] read_data_M;  // Data read input to core (from Wishbone)

    mux_2x1 #(
        .DATA_WIDTH(ADDR_WIDTH)
    ) U_MUX_2x1 (
        .i_sel(wb_we),
        .i_a  (wb_adr),
        .i_b  (pc_IF),
        .o_mux(adr)
    );


    // ------------------------------------------
    // Instantiate the core module
    // ------------------------------------------
    core #(
        .DATA_WIDTH(DATA_WIDTH)
    ) U_CORE (
        .clk(clk),
        .rst(rst),
        .i_instr_ID(instr_ID),
        .i_read_data_M(read_data_M),
        .o_pc_IF(pc_IF),
        .o_mem_write_M(mem_write_M),
        .o_data_addr_M(data_addr_M),
        .o_write_data_M(write_data_M)
    );

    // ! check access of Data memory from both core and uart_wbs_bridge (avoid conflicts or synthesys issues that could occur)
    // ! check access of Instruction memory from both core and uart_wbs_bridge (avoid conflicts or synthesys issues that could occur)
    // todo: add a mux to select which memory uart_wbs_bridge is reading/writing
    // ------------------------------------------
    // Instantiate UART to Wishbone bridge
    // ------------------------------------------
    uart_wbs_bridge #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ)
    ) U_UART_WB_BRIDGE (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .start_rx(start_rx),
        .wb_cyc_o(wb_cyc),
        .wb_stb_o(wb_stb),
        .wb_we_o(wb_we),
        .wb_adr_o(wb_adr),
        .wb_dat_o(wb_dat_o),
        .wb_dat_i(wb_dat_i),
        .wb_ack_i(wb_ack)
    );

    // ------------------------------------------
    // Instantiate Instruction Memory
    // ------------------------------------------
    mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(10),
        .MEM_SIZE  (4)
    ) U_INST_MEM (
        .clk(clk),
        .rst(rst),
        .wb_adr_i(adr[9:0]),  // 10-bit address for 4KB memory
        .wb_dat_i(wb_dat_o),
        .wb_we_i(wb_we),
        .wb_stb_i(wb_stb),
        .wb_cyc_i(wb_cyc),
        .wb_dat_o(instr_ID),
        .wb_ack_o(wb_ack)
    );

    // ------------------------------------------
    // Instantiate Data Memory
    // ------------------------------------------
    mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(10),
        .MEM_SIZE  (4)
    ) U_DATA_MEM (
        .clk(clk),
        .rst(rst),
        .wb_adr_i(data_addr_M[9:0]),  // 10-bit address for 4KB memory
        .wb_dat_i(write_data_M),
        .wb_we_i(mem_write_M),
        .wb_stb_i(wb_stb),
        .wb_cyc_i(wb_cyc),
        .wb_dat_o(read_data_M),
        .wb_ack_o(wb_ack)
    );

endmodule

