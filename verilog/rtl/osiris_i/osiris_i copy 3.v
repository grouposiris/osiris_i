module osiris_i #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter BAUD_RATE  = 9600,
    parameter CLOCK_FREQ = 50000000  // 50 MHz
) (
    input wire clk,
    input wire rst,
    input wire uart_rx,  // UART receive signal from external device
    input wire
        select_mem,  // Select memory for UART communication: 0 = Instruction Mem, 1 = Data Mem
    input wire start_rx,  // Control signal to start UART reception
    output wire uart_tx  // UART transmit signal to external device
);

    // ------------------------------------------
    // Internal Signals for Wishbone Communication
    // ------------------------------------------
    wire [DATA_WIDTH-1:0]
        u_uart_wb_bridge_dat_o_to_mem;  // Data from UART Wishbone bridge to memory
    wire [ADDR_WIDTH-1:0]
        u_uart_wb_bridge_adr_o_to_mem;  // Address from UART Wishbone bridge to memory
    wire [ADDR_WIDTH-1:0]
        u_core_pc_IF_to_inst_mem;  // Address from core (PC in IF stage) to Instruction Memory
    wire u_uart_wb_bridge_we_o_to_mem;  // Write enable from UART Wishbone bridge to memory
    wire u_uart_wb_bridge_stb_o_to_mem;  // Strobe signal from UART Wishbone bridge to memory
    wire u_uart_wb_bridge_cyc_o_to_mem;  // Cycle signal from UART Wishbone bridge to memory
    wire u_inst_mem_wb_ack_o;  // Acknowledge from Instruction Memory
    wire u_data_mem_wb_ack_o;  // Acknowledge from Data Memory
    wire u_selected_mem_wb_ack_o;  // Acknowledge signal from selected memory
    wire [DATA_WIDTH-1:0]
        u_inst_mem_wb_dat_o_to_uart_or_core;  // Data from Instruction Memory to UART bridge
    wire [DATA_WIDTH-1:0]
        u_data_mem_wb_dat_o_to_uart_or_core;  // Data from Data Memory to UART bridge or core
    wire [DATA_WIDTH-1:0] u_selected_mem_wb_dat_o;  // Data from selected memory to UART bridge

    // ------------------------------------------
    // Internal Signals for Core Communication
    // ------------------------------------------
    wire [DATA_WIDTH-1:0] u_core_pc_IF;  // Program Counter (IF stage) from core
    wire u_core_mem_write_M;  // Write enable from core (M stage)
    wire [DATA_WIDTH-1:0] u_core_data_addr_M;  // Data address from core (M stage)
    wire [DATA_WIDTH-1:0] u_core_write_data_M;  // Data to write from core (M stage)
    // wire [DATA_WIDTH-1:0] u_core_instr_ID;  // Instruction fetched from Instruction Memory to core
    // Direct assignment: Instruction Memory data is directly connected to the core
    wire [DATA_WIDTH-1:0] u_core_read_data_M =
        u_data_mem_wb_dat_o_to_uart_or_core;  // Data fetched from Data Memory to core

    // ------------------------------------------
    // Mux for Address Selection between UART and Core
    // ------------------------------------------
    mux_2x1 #(
        .DATA_WIDTH(ADDR_WIDTH)
    ) U_MUX_2x1 (
        .i_sel(u_uart_wb_bridge_we_o_to_mem),   // Select between UART address (1) or core (0)
        .i_a  (u_uart_wb_bridge_adr_o_to_mem),  // Address from UART bridge
        .i_b  (u_core_pc_IF),                   // Program Counter address from the core
        .o_mux(u_core_pc_IF_to_inst_mem)        // Output the selected address to Instruction Memory
    );

    // ------------------------------------------
    // Instantiate the RISC-V Core
    // ------------------------------------------
    core #(
        .DATA_WIDTH(DATA_WIDTH)
    ) U_CORE (
        .clk(clk),
        .rst(rst),
        .i_instr_ID(
            u_inst_mem_wb_dat_o_to_uart_or_core),  // Instruction from Instruction Memory to core
        .i_read_data_M(u_core_read_data_M),  // Data read from Data Memory to core
        .o_pc_IF(u_core_pc_IF),  // Program Counter output (IF stage)
        .o_mem_write_M(u_core_mem_write_M),  // Memory write signal output
        .o_data_addr_M(u_core_data_addr_M),  // Data address output from core (M stage)
        .o_write_data_M(u_core_write_data_M)  // Data to write output from core (M stage)
    );

    // ------------------------------------------
    // Instantiate UART to Wishbone Bridge
    // ------------------------------------------
    uart_wbs_bridge #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ)
    ) U_UART_WB_BRIDGE (
        .clk     (clk),
        .rst     (rst),
        .uart_rx (uart_rx),                        // UART receive signal
        .uart_tx (uart_tx),                        // UART transmit signal
        .start_rx(start_rx),                       // Start UART reception
        .wb_cyc_o(u_uart_wb_bridge_cyc_o_to_mem),  // Cycle output signal to memory
        .wb_stb_o(u_uart_wb_bridge_stb_o_to_mem),  // Strobe output signal to memory
        .wb_we_o (u_uart_wb_bridge_we_o_to_mem),   // Write enable output signal to memory
        .wb_adr_o(u_uart_wb_bridge_adr_o_to_mem),  // Address output signal to memory
        .wb_dat_o(u_uart_wb_bridge_dat_o_to_mem),  // Data output signal to memory
        .wb_dat_i(u_selected_mem_wb_dat_o),        // Data input signal from selected memory
        .wb_ack_i(u_selected_mem_wb_ack_o)         // Acknowledge input signal from selected memory
    );

    // ------------------------------------------
    // Memory Interface Multiplexing
    // ------------------------------------------
    // Mux to select between Instruction Memory and Data Memory
    assign u_selected_mem_wb_ack_o = select_mem ? u_data_mem_wb_ack_o : u_inst_mem_wb_ack_o;
    assign u_selected_mem_wb_dat_o = select_mem ? u_data_mem_wb_dat_o_to_uart_or_core :
        u_inst_mem_wb_dat_o_to_uart_or_core;

    // ------------------------------------------
    // Instantiate Instruction Memory
    // ------------------------------------------
    mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(10),
        .MEM_SIZE(4)  // 4KB Instruction Memory
    ) U_INST_MEM (
        .clk(clk),
        .rst(rst),
        .wb_adr_i(u_core_pc_IF_to_inst_mem[9:0]),  // 10-bit address for Instruction Memory
        .wb_dat_i(u_uart_wb_bridge_dat_o_to_mem),  // Data input from UART bridge
        .wb_we_i(u_uart_wb_bridge_we_o_to_mem),  // Write enable from UART bridge
        .wb_stb_i(u_uart_wb_bridge_stb_o_to_mem & ~select_mem)
        ,  // Strobe from UART bridge only when Instruction Memory is selected
        .wb_cyc_i(u_uart_wb_bridge_cyc_o_to_mem & ~select_mem)
        ,  // Cycle from UART bridge only when Instruction Memory is selected
        .wb_dat_o(u_inst_mem_wb_dat_o_to_uart_or_core),  // Data output to UART bridge
        .wb_ack_o(u_inst_mem_wb_ack_o)  // Acknowledge output to UART bridge
    );

    // Direct connection: Instruction Memory data to core
    // assign u_core_instr_ID = u_inst_mem_wb_dat_o_to_uart_or_core;  // Instruction from Instruction Memory to core
    // * so the Instruction Memory data output goes directly to core with 'u_core_instr_ID' and 'u_inst_mem_wb_dat_o_to_uart' goes to a mux to select between this signal or from Data Memory signal: 'u_data_mem_wb_dat_o_to_uart_or_core'

    // ------------------------------------------
    // Instantiate Data Memory
    // ------------------------------------------
    mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(10),
        .MEM_SIZE(4)  // 4KB Data Memory
    ) U_DATA_MEM (
        .clk(clk),
        .rst(rst),
        .wb_adr_i(select_mem ? u_uart_wb_bridge_adr_o_to_mem[9:0] :
                  u_core_data_addr_M[9:0]),  // Select address from UART or core
        .wb_dat_i(select_mem ? u_uart_wb_bridge_dat_o_to_mem :
                  u_core_write_data_M),  // Select data input from UART or core
        .wb_we_i(select_mem ? u_uart_wb_bridge_we_o_to_mem :
                 u_core_mem_write_M),  // Select write enable from UART or core
        .wb_stb_i(u_uart_wb_bridge_stb_o_to_mem &
                  select_mem),  // Strobe from UART bridge only when Data Memory is selected
        .wb_cyc_i(u_uart_wb_bridge_cyc_o_to_mem &
                  select_mem),  // Cycle from UART bridge only when Data Memory is selected
        .wb_dat_o(u_data_mem_wb_dat_o_to_uart_or_core),  // Data output to UART bridge or core
        .wb_ack_o(u_data_mem_wb_ack_o)  // Acknowledge output to UART bridge
    );

    // Direct connection: Data Memory data to core
    // Already connected with 'u_core_read_data_M = u_data_mem_wb_dat_o_to_uart_or_core'

endmodule
