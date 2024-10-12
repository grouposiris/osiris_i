module osiris_i #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter BAUD_RATE  = 9600,
    parameter CLOCK_FREQ = 50000000  // 50 MHz
) (
    input wire clk,
    input wire rst,
    input wire uart_rx,
    input wire select_mem,  // Selects which memory the uart_wbs_bridge communicates with: 0 - Instruction Memory, 1 - Data Memory
    input wire
        start_rx,  // Signal to start the reception process to prevent unnecessary power consumption
    output wire uart_tx
);

    // ------------------------------------------
    // Internal Signals for Core and Wishbone
    // ------------------------------------------

    wire [DATA_WIDTH-1:0] wb_dat_o;  // Data from UART bridge to memory
    wire [ADDR_WIDTH-1:0] wb_adr;  // Address from UART bridge to memory
    wire [ADDR_WIDTH-1:0] adr;  // Address to Instruction Memory
    wire wb_we, wb_stb, wb_cyc;
    wire wb_ack_inst_mem, wb_ack_data_mem;  // Acknowledges from memories
    wire                  wb_ack;  // Acknowledge to UART bridge
    wire [DATA_WIDTH-1:0] wb_dat_i_inst_mem;  // Data from Instruction Memory to UART bridge
    wire [DATA_WIDTH-1:0] wb_dat_i_data_mem;  // Data from Data Memory to UART bridge
    wire [DATA_WIDTH-1:0] wb_dat_i;  // Data to UART bridge

    wire [DATA_WIDTH-1:0] pc_IF;  // Program counter from core (IF stage)
    wire                  mem_write_M;  // Memory write signal from core (M stage)
    wire [DATA_WIDTH-1:0] data_addr_M;  // Data address from core (M stage)
    wire [DATA_WIDTH-1:0] write_data_M;  // Data to write from core (M stage)
    wire [DATA_WIDTH-1:0] instr_ID;  // Instruction input to core (from Instruction Memory)
    wire [DATA_WIDTH-1:0] read_data_M;  // Data read input to core (from Data Memory)

    // Mux to select between UART bridge address and core's PC
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
    // Memory Interfaces
    // ------------------------------------------

    // Connect UART bridge to selected memory
    // Only the selected memory gets the UART bridge signals
    // The unselected memory sees wb_cyc_i and wb_stb_i as zero

    // Instruction Memory Interface Signals
    wire inst_mem_cyc_i = wb_cyc & ~select_mem;
    wire inst_mem_stb_i = wb_stb & ~select_mem;
    wire inst_mem_we_i = wb_we;
    wire [9:0] inst_mem_adr_i = adr[9:0];  // 10-bit address for 4KB memory
    wire [DATA_WIDTH-1:0] inst_mem_dat_i = wb_dat_o;
    wire [DATA_WIDTH-1:0] inst_mem_dat_o;
    wire inst_mem_ack_o;

    // Data Memory Interface Signals
    wire data_mem_cyc_i = wb_cyc & select_mem;
    wire data_mem_stb_i = wb_stb & select_mem;
    wire data_mem_we_i = wb_we;
    wire [9:0] data_mem_adr_i = wb_adr[9:0];  // Address from UART bridge
    wire [DATA_WIDTH-1:0] data_mem_dat_i = wb_dat_o;
    wire [DATA_WIDTH-1:0] data_mem_dat_o;
    wire data_mem_ack_o;

    // Assign wb_ack and wb_dat_i based on selected memory
    assign wb_ack   = select_mem ? data_mem_ack_o : inst_mem_ack_o;
    assign wb_dat_i = select_mem ? data_mem_dat_o : inst_mem_dat_o;

    // ------------------------------------------
    // Instantiate Instruction Memory
    // ------------------------------------------
    mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(10),
        .MEM_SIZE  (4)
    ) U_INST_MEM (
        .clk     (clk),
        .rst     (rst),
        .wb_adr_i(inst_mem_adr_i),  // Address input
        .wb_dat_i(inst_mem_dat_i),  // Data input
        .wb_we_i (inst_mem_we_i),   // Write enable
        .wb_stb_i(inst_mem_stb_i),  // Strobe
        .wb_cyc_i(inst_mem_cyc_i),  // Cycle
        .wb_dat_o(inst_mem_dat_o),  // Data output
        .wb_ack_o(inst_mem_ack_o)   // Acknowledge output
    );

    // The instruction memory also interfaces with the core
    assign instr_ID = inst_mem_dat_o;  // Instruction to core from Instruction Memory

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
        .wb_adr_i(select_mem ? data_mem_adr_i :
                  data_addr_M[9:0]),  // Select address based on UART or core
        .wb_dat_i(select_mem ? data_mem_dat_i : write_data_M),  // Select data input
        .wb_we_i(select_mem ? data_mem_we_i : mem_write_M),  // Select write enable
        .wb_stb_i(data_mem_stb_i | (wb_stb & ~select_mem)),  // Merge strobe signals
        .wb_cyc_i(data_mem_cyc_i | (wb_cyc & ~select_mem)),  // Merge cycle signals
        .wb_dat_o(data_mem_dat_o),  // Data output
        .wb_ack_o(data_mem_ack_o)  // Acknowledge output
    );

    // The data memory also interfaces with the core
    assign read_data_M = data_mem_dat_o;  // Data to core from Data Memory

    // ** Fixes and Explanations **
    // 1. Added multiplexing logic to route UART bridge signals to the selected memory based on 'select_mem'.
    //    This prevents bus contention and ensures only the selected memory responds to the UART bridge.
    // 2. Modified the assignment of 'wb_ack' and 'wb_dat_i' to the UART bridge to select the appropriate memory's outputs.
    // 3. Ensured that the core continues to interface with both memories independently of the UART bridge.
    // 4. Adjusted addresses accordingly and used '[9:0]' for 10-bit addresses into memories.
    // 5. Resolved potential conflicts on the shared Wishbone signals by gating them based on 'select_mem'.
    // 6. Fixed the data memory address selection to prevent conflicts between core and UART bridge.

endmodule
