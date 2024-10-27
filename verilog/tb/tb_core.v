// Analysis of Potential Issues for Synthesis
// ------------------------------------------
// 1. Multiplexers and Control Signals: The current implementation uses `i_select_mem` and `uart_wb_stb_o` to select between the core and UART bridge for memory access. To ensure synthesis-friendly code:
//    - Confirm that control signals (`i_select_mem` and `uart_wb_stb_o`) are asserted in a mutually exclusive manner to prevent undefined behavior.
//    - Add arbitration logic or a bus lock mechanism to ensure no simultaneous conflicting access occurs.

// 2. Synchronous Reset: The reset signals (`rst_core` and `rst_mem_uart`) should be implemented as synchronous resets if your target technology or synthesis tools prefer synchronous resets for better timing control.

// 3. Memory Modules: The `mem` module is instantiated for instruction and data memory. Ensure that the memory technology being used (e.g., synthesized block RAM or instantiated from a library) is inferred correctly by your synthesis tool. You may need to provide vendor-specific memory attributes.

// 4. UART and Memory Arbitration: Currently, there is no explicit arbitration between the core and UART bridge for access to the memories. This could lead to bus contention or incorrect read/write operations. Adding arbitration or prioritization logic would be advisable for a real implementation.

// 5. Test for Combinational Loops: Synthesis tools often struggle with unintended combinational loops. Ensure that the multiplexing and signal assignments do not form any unintended loops.

// 6. Acknowledge Signal Handling: The acknowledge signals (`inst_mem_ack_o`, `data_mem_ack_o`) should be handled properly. As per the comments, the core does not use the acknowledge signals. This could cause issues during synthesis if not managed properly.

// Testbench for osiris_i Module
// ------------------------------
`timescale 1ns / 1ps
module tb_osiris_i ();
    // Parameters for simulation
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter INST_MEM_SIZE = 4;  // in KB
    parameter DATA_MEM_SIZE = 4;  // in KB
    parameter BAUD_RATE = 9600;
    parameter CLOCK_FREQ = 50000000;  // 50 MHz

    // Testbench Signals
    reg  clk;
    reg  rst_core;
    reg  rst_mem_uart;
    reg  i_uart_rx;
    reg  i_select_mem;
    reg  i_start_rx;
    wire o_uart_tx;

    // Instantiate the DUT (Device Under Test)
    osiris_i #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .INST_MEM_SIZE(INST_MEM_SIZE),
        .DATA_MEM_SIZE(DATA_MEM_SIZE),
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ)
    ) dut (
        .clk(clk),
        .rst_core(rst_core),
        .rst_mem_uart(rst_mem_uart),
        .i_uart_rx(i_uart_rx),
        .i_select_mem(i_select_mem),
        .i_start_rx(i_start_rx),
        .o_uart_tx(o_uart_tx)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50 MHz clock
    end

    // Reset and Initialization
    initial begin
        rst_core = 1;
        rst_mem_uart = 1;
        i_uart_rx = 0;
        i_select_mem = 0;
        i_start_rx = 0;

        // Apply reset
        #100;
        rst_core = 0;
        rst_mem_uart = 0;

        // Start UART communication
        #200;
        i_start_rx = 1;
        #20;
        i_start_rx = 0;

        // Select Data Memory for UART communication
        #500;
        i_select_mem = 1;

        // Simulate UART data reception
        #1000;
        i_uart_rx = 1;
        #40;
        i_uart_rx = 0;
    end

    // Simulate a Simple C Program
    initial begin
        // This block simulates a simple C program that writes and reads from memory
        // For example, writing a value to an address and then reading it back
        #1500;
        $display("Simulating simple C program...");
        // Assuming memory write operation through UART
        i_uart_rx = 1;
        #20;
        i_uart_rx = 0;
        #20;
        i_uart_rx = 1;
        #20;
        i_uart_rx = 0;

        // End of simulation
        #5000;
        $stop;
    end

endmodule
