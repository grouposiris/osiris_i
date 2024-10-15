//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021 Group of Open-Source Research in RISC-V Architectures for
// Integrated Systems. All rights reserved.
//
// Use, copy or distribution of this code is free without Group of Open-Source
// Research in RISC-V Architectures for Integrated Systems explicit written a 
// consent.
//////////////////////////////////////////////////////////////////////////////
// Filename:    apb_bus.sv
// Date:        31/08/2023
// Reviwer:     Rafael Oliveira
// Revision:    1.2
//////////////////////////////////////////////////////////////////////////////
// Company:     Group OSIRIS
// Project:     OSIRIS I
// Block:       apb_bus
// Description: RTL description for the APB bus block. The APB bus has 3 
//              operating states IDLE, SETUP and ACCESS
//////////////////////////////////////////////////////////////////////////////

module apb_bus #(
    parameter DATA_WIDTH = 32
) (
    pclk,
    i_preset_n,
    i_add,
    i_prdata,
    i_pready,

    o_psel,
    o_penable,
    o_paddr,
    o_pwrite,
    o_pwdata
);


    // ------------------------------------------
    // IO declaration
    // ------------------------------------------
    input logic pclk;  // ok
    input logic i_preset_n;  // ok
    input logic i_pready;  // ok
    input logic [1:0] i_add;
    input logic [DATA_WIDTH-1:0] i_prdata;  // ok


    output logic o_psel;  // ok
    output logic o_penable;  // ok
    output logic o_pwrite;  // ok
    output logic [DATA_WIDTH-1:0] o_paddr;  // ok
    output logic [DATA_WIDTH-1:0] o_pwdata;  // Ok                                     

    // ------------------------------------------
    // Localparams
    // ------------------------------------------
    typedef enum logic [1:0] {
        ST_IDLE,
        ST_SETUP,
        ST_ACCESS
    } apb_state;


    // ------------------------------------------
    // Signals deinitions
    // ------------------------------------------
    apb_state cur_state;
    apb_state nxt_state;

    logic apb_state_setup;
    logic apb_state_access;

    // ------------------------------------------
    // Logic
    // ------------------------------------------
    always @(posedge pclk or negedge i_preset_n) begin
        if (!i_preset_n) begin
            cur_state = ST_IDLE;
        end else begin
            cur_state <= nxt_state;
        end
    end

    always @(*) begin
        case (cur_state)
            ST_IDLE: begin
                if (i_add[0]) begin
                    nxt_state = ST_SETUP;
                end else begin
                    nxt_state = ST_IDLE;
                end
            end
            ST_SETUP: begin
                nxt_state = ST_ACCESS;
            end
            ST_ACCESS: begin
                if (i_pready) begin
                    nxt_state = ST_IDLE;
                end else begin
                    nxt_state = ST_ACCESS;
                end
            end
            default: begin
                nxt_state = ST_IDLE;
            end
        endcase
    end

    assign apb_state_setup = (cur_state == ST_SETUP);
    assign apb_state_access = (cur_state == ST_ACCESS);

    assign o_psel = apb_state_setup | apb_state_access;
    assign o_penable = apb_state_access;

    // APB Adress
    //assign o_paddr = {32{apb_state_access}} & 32'hA000;
    assign o_paddr = (apb_state_access) ? 32'hA000 : 32'h0;


endmodule
