// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module osiris_i_wrapper #(
    parameter BITS = 16,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,


    // Logic Analyzer Signals


    // IOs
    input  [BITS-1:0] io_in,
    output [BITS-1:0] io_out,

    // IRQ
);


    assign io_out[15:1] = {15'h0};


    // ------------------------------------------
    // Internal Signals for UART Wishbone Bridge
    // ------------------------------------------
    wire [DATA_WIDTH-1:0] uart_wb_dat_o;  // Data output from UART bridge to memory
    wire [ADDR_WIDTH-1:0] uart_wb_adr_o;  // Address output from UART bridge to memory
    wire                  uart_wb_we_o;  // Write enable output from UART bridge to memory
    wire                  uart_wb_stb_o;  // Strobe output from UART bridge to memory
    wire                  uart_wb_cyc_o;  // Cycle output from UART bridge to memory
    wire [DATA_WIDTH-1:0] uart_wb_dat_i;  // Data input from memory to UART bridge
    wire                  uart_wb_ack_i;  // Acknowledge input from memory to UART bridge

    // ------------------------------------------
    // Internal Signals for Core
    // ------------------------------------------
    wire [DATA_WIDTH-1:0] core_pc_IF;  // Program Counter (IF stage) from core
    wire                  core_mem_write_M;  // Memory write enable from core (M stage)
    wire [DATA_WIDTH-1:0] core_data_addr_M;  // Data address from core (M stage)
    wire [DATA_WIDTH-1:0] core_write_data_M;  // Data to write from core (M stage)
    wire [DATA_WIDTH-1:0] core_instr_ID;  // Instruction fetched from Instruction Memory to core
    wire [DATA_WIDTH-1:0] core_read_data_M;  // Data read from Data Memory to core

    // ------------------------------------------
    // UART to Wishbone Bridge Instance
    // ------------------------------------------
    uart_wbs_bridge U_UART_WB_BRIDGE (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),	// User area 1 1.8V power
            .vssd1(vssd1),	// User area 1 digital ground
        `endif
        .clk     (wb_clk_i),
        .rst     (io_in[5]),
        .i_uart_rx (io_in[6]),        // UART receive signal
        .o_uart_tx (io_out[0]),        // UART transmit signal
        .i_start_rx(io_in[8]),       // Start UART reception

        .wb_cyc_o(uart_wb_cyc_o),  // Cycle output to memory
        .wb_stb_o(uart_wb_stb_o),  // Strobe output to memory
        .wb_we_o (uart_wb_we_o),   // Write enable output to memory
        .wb_adr_o(uart_wb_adr_o),  // Address output to memory
        .wb_dat_o(uart_wb_dat_o),  // Data output to memory
        .wb_dat_i(uart_wb_dat_i),  // Data input from memory
        .wb_ack_i(uart_wb_ack_i)   // Acknowledge input from memory
    );

    // ------------------------------------------
    // Core Instance
    // ------------------------------------------
    core U_CORE (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),	// User area 1 1.8V power
            .vssd1(vssd1),	// User area 1 digital ground
        `endif
        .clk           (wb_clk_i),
        .rst           (io_in[5]),
        .i_instr_ID    (core_instr_ID),     // Instruction input to core
        .i_read_data_M (core_read_data_M),  // Data read input to core
        .o_pc_IF       (core_pc_IF),        // Program Counter output from core
        .o_mem_write_M (core_mem_write_M),  // Memory write enable output from core
        .o_data_addr_M (core_data_addr_M),  // Data address output from core
        .o_write_data_M(core_write_data_M)  // Data to write output from core
    );

    // ------------------------------------------
    // Instruction Memory Interface
    // ------------------------------------------
    wire [4:0] inst_mem_adr_i;
    wire [DATA_WIDTH-1:0] inst_mem_dat_i;
    wire inst_mem_we_i;
    wire inst_mem_stb_i;
    wire inst_mem_cyc_i;
    wire [DATA_WIDTH-1:0] inst_mem_dat_o;
    wire inst_mem_ack_o;

    // Mux between core and UART bridge for Instruction Memory access
    assign inst_mem_adr_i = (io_in[7] == 1'b0 && uart_wb_stb_o) ? uart_wb_adr_o[9:0] :
        core_pc_IF[9:0];
    assign inst_mem_dat_i = uart_wb_dat_o;  // Only UART bridge writes to Instruction Memory
    assign inst_mem_we_i = (io_in[7] == 1'b0 && uart_wb_stb_o) ? uart_wb_we_o :
        1'b0;  // Core does not write to Instruction Memory

    // todo: fix the code below here
    assign inst_mem_stb_i = (io_in[7] == 1'b0 && uart_wb_stb_o) ? uart_wb_stb_o :
        1'b1;  // Core always reads instructions // ! here it should be activated only based on core instruction. if is a i-type instruction of Load-type, then ResultSrc would be 2'b01
    assign inst_mem_cyc_i = (io_in[7] == 1'b0 && uart_wb_cyc_o) ? uart_wb_cyc_o :
        1'b1;  // Core always reads instructions

    // Connect instruction memory data output to core
    assign core_instr_ID = inst_mem_dat_o;

    // ------------------------------------------
    // Data Memory Interface
    // ------------------------------------------
    wire [4:0] data_mem_adr_i;
    wire [DATA_WIDTH-1:0] data_mem_dat_i;
    wire data_mem_we_i;
    wire data_mem_stb_i;
    wire data_mem_cyc_i;
    wire [DATA_WIDTH-1:0] data_mem_dat_o;
    wire data_mem_ack_o;

    // Mux between core and UART bridge for Data Memory access
    assign data_mem_adr_i = (io_in[7] == 1'b1 && uart_wb_stb_o) ? uart_wb_adr_o[9:0] :
        core_data_addr_M[9:0];
    assign
        data_mem_dat_i = (io_in[7] == 1'b1 && uart_wb_stb_o) ? uart_wb_dat_o : core_write_data_M;
    assign data_mem_we_i = (io_in[7] == 1'b1 && uart_wb_stb_o) ? uart_wb_we_o : core_mem_write_M;
    assign data_mem_stb_i = (io_in[7] == 1'b1 && uart_wb_stb_o) ? uart_wb_stb_o :
        1'b1;  // Core accesses Data Memory when not overridden
    assign data_mem_cyc_i = (io_in[7] == 1'b1 && uart_wb_cyc_o) ? uart_wb_cyc_o : 1'b1;

    // Connect data memory data output to core
    assign core_read_data_M = data_mem_dat_o;

    // Acknowledge handling
    //assign uart_wb_ack_i = (select_mem == 1'b1) ? data_mem_ack_o : uart_wb_ack_i;
    assign uart_wb_ack_i = (io_in[7] == 1'b1) ? data_mem_ack_o : 1'b1;   // <---- REVIEW

    // ------------------------------------------
    // Instantiate Instruction Memory
    // ------------------------------------------
    mem U_INST_MEM (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),	// User area 1 1.8V power
            .vssd1(vssd1),	// User area 1 digital ground
        `endif
        .clk     (wb_clk_i),
        .rst     (io_in[5]),
        .wb_adr_i(inst_mem_adr_i),  // Address input
        .wb_dat_i(inst_mem_dat_i),  // Data input
        .wb_we_i (inst_mem_we_i),   // Write enable input
        .wb_stb_i(inst_mem_stb_i),  // Strobe input
        .wb_cyc_i(inst_mem_cyc_i),  // Cycle input
        .wb_dat_o(inst_mem_dat_o),  // Data output
        .wb_ack_o(inst_mem_ack_o)   // Acknowledge output
    );

    // ------------------------------------------
    // Instantiate Data Memory
    // ------------------------------------------
    mem U_DATA_MEM (
        `ifdef USE_POWER_PINS
            .vccd1(vccd1),	// User area 1 1.8V power
            .vssd1(vssd1),	// User area 1 digital ground
        `endif
        .clk     (wb_clk_i),
        .rst     (io_in[5]),
        .wb_adr_i(data_mem_adr_i),  // Address input
        .wb_dat_i(data_mem_dat_i),  // Data input
        .wb_we_i (data_mem_we_i),   // Write enable input
        .wb_stb_i(data_mem_stb_i),  // Strobe input
        .wb_cyc_i(data_mem_cyc_i),  // Cycle input
        .wb_dat_o(data_mem_dat_o),  // Data output
        .wb_ack_o(data_mem_ack_o)   // Acknowledge output
    );

    // ------------------------------------------
    // Acknowledge Signal to UART Bridge
    // ------------------------------------------

    // Data input to UART bridge
    assign uart_wb_dat_i = (io_in[7] == 1'b1) ?
        data_mem_dat_o : (io_in[7] == 1'b0) ? inst_mem_dat_o : {DATA_WIDTH{1'b0}};

    // ------------------------------------------
    // Comments and Explanations
    // ------------------------------------------

    // 1. **Signal Naming:** All signals are named to clearly indicate their sources:
    //    - `uart_*`: Signals originating from the UART Wishbone bridge.
    //    - `core_*`: Signals originating from the core.
    //    - `*_mem_*`: Signals related to memory interfaces.

    // 2. **Multiplexing Logic:**
    //    - For both Instruction and Data Memories, multiplexers are used to select signals from either the UART bridge or the core.
    //    - The selection is based on the `select_mem` signal and whether the UART bridge is asserting `uart_wb_stb_o`.

    // 3. **Instruction Memory Access:**
    //    - The core always reads instructions from the Instruction Memory. //! //todo: this should be fixed to only read at right time
    //    - The UART bridge can write to the Instruction Memory when `select_mem == 0`.
    //    - The core does not write to the Instruction Memory.

    //! 4. **Data Memory Access:**
    //    - Both the core and the UART bridge can read from and write to the Data Memory.
    //    - When the UART bridge is accessing the Data Memory (`select_mem == 1` and `uart_wb_stb_o` is asserted), the core's access is not hindered due to the way the strobe (`data_mem_stb_i`) and cycle (`data_mem_cyc_i`) signals are managed.
    //*    - However, to prevent bus conflicts, in a real-world scenario, additional arbitration logic might be necessary.
    //todo: check this and fix

    // 5. **Acknowledge Signals:**
    //    - The acknowledge signals from the memories are routed to the UART bridge based on which memory is selected.
    //    - The core does not use the acknowledge signals in this simplified design. // * a logic can be done to this based on the actual instruction (get from stage registers  -> check on which register we can get at the right time)

    // 6. **Memory Modules:**
    //    - The `mem.v` module remains unchanged as per your request.
    //    - The memories are synchronous and use the Wishbone interface for communication.

    // 7. **Potential Improvements:**
    //    - In a full design, you might need to implement bus arbitration to handle simultaneous access attempts by the core and UART bridge to the same memory.
    //    - Implementing wait states or a handshaking mechanism would ensure data integrity and prevent conflicts.

    // 8. **Ensuring No Bus Conflicts:**
    //    - For this design, it's assumed that the UART bridge access to the memories is infrequent or managed externally to prevent conflicts.
    //    - Alternatively, you could introduce a signal that pauses the core when the UART bridge is accessing the memories.

endmodule

`default_nettype wire
