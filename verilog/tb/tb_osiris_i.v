`timescale 1ns / 1ps

module osiris_i_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    // parameter BAUD_RATE = 9600;
    // parameter CLOCK_FREQ = 50000000;  // 50 MHz clock
    parameter BAUD_RATE = 1e9;
    parameter CLOCK_FREQ = 10e9;  // 50 MHz clock
    parameter CLK_PERIOD = 1e9 / CLOCK_FREQ;  // Clock period in nanoseconds

    // UART Command Values
    localparam CMD_READ = 8'h01;  // Command to read from memory and send data via UART
    localparam CMD_WRITE = 8'hAA;  // Command to write data received via UART to memory

    // Calculate Bit Period Based on Baud Rate
    localparam real BIT_PERIOD = 1e9 / BAUD_RATE;  // Bit period in nanoseconds
    localparam WAIT_BETWEEN_UART_SEND_BYTE = (10 * BIT_PERIOD);
    localparam WAIT_BETWEEN_UART_SEND_CMD = 50;
    localparam WAIT_BETWEEN_STEPS = 100;


    // UART Wishbone Bridge State Encoding (from uart_wbs_bridge)
    localparam STATE_IDLE = 3'd0;
    localparam STATE_READ_ADDR = 3'd2;
    localparam STATE_READ_DATA = 3'd3;
    localparam STATE_WB_WRITE = 3'd4;
    localparam STATE_WB_READ = 3'd5;
    localparam STATE_SEND_DATA = 3'd6;

    // Clock and Reset
    reg  clk;
    reg  rst;

    // UART Signals
    reg  i_uart_rx;
    wire o_uart_tx;

    // Control Signals
    reg  i_start_rx;
    reg  i_select_mem;  // Control signal to select memory: 0 - Instruction Mem, 1 - Data Mem

    // Instantiate the osiris_i module (Device Under Test)
    osiris_i #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ),
        .CMD_READ  (CMD_READ),
        .CMD_WRITE (CMD_WRITE)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .i_uart_rx   (i_uart_rx),
        .o_uart_tx   (o_uart_tx),
        .i_select_mem(i_select_mem),
        .i_start_rx  (i_start_rx)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;  // Toggle clock every half period
    end

    // Reset Sequence
    initial begin
        rst = 1;
        i_start_rx = 0;
        i_select_mem = 0;
        i_uart_rx = 1;  // UART line idle (high)
        #100;
        rst = 0;
        i_start_rx = 1;  // Enable UART reception
        // #100000 $finish;
    end

    // VCD Dump for Waveform Viewing
    initial begin
        $dumpfile("osiris_i.vcd");
        $dumpvars(0, osiris_i_tb);
    end

    // Test Variables
    integer i;
    reg test_passed;
    reg [DATA_WIDTH-1:0] read_data;
    reg [DATA_WIDTH-1:0] expected_data;
    reg [ADDR_WIDTH-1:0] test_address;
    integer step;

    // Main Test Sequence
    initial begin
        test_passed = 1;

        $display("Starting osiris_i Testbench...");
        #200;  // Wait for reset to deassert

        step = 1;
        // --------------------------------------------
        // Test 1: Write Data to Instruction Memory via UART and Verify
        // --------------------------------------------
        $display("\nTest 1: Writing Data to Instruction Memory via UART...");
        i_select_mem  = 0;  // Select Instruction Memory
        test_address  = 32'h0000BB11;  // Starting address for program
        expected_data = 32'hDEADBEEF;  //

        // Test 1: Write Data to Memory via UART and Wishbone
        $display("\nTest 1: Writing Data to Memory...");
        test_write_to_memory(test_address, expected_data);

        #100;
        // // Test 2: Read Data from Memory via UART and Wishbone
        // $display("\nTest 2: Reading Data from Memory...");
        // test_read_from_memory(test_address, read_data);

        // ----------------
        test_address  = 32'h00000000;  // Starting address for program
        expected_data = 32'h00000093;  // Example instruction (e.g., NOP in RISC-V)

        // Send multiple instructions to Instruction Memory
        for (i = 0; i < 4; i = i + 1) begin
            test_write_to_memory(test_address + i * 4, expected_data + i);
        end

        #(WAIT_BETWEEN_STEPS);
        step = 2;
        // // --------------------------------------------
        // // Test 2: Read Data from Instruction Memory via UART and Verify
        // // --------------------------------------------
        // $display("\nTest 2: Reading Data from Instruction Memory via UART...");
        // for (i = 0; i < 4; i = i + 1) begin
        //     test_read_from_memory(test_address + i * 4, read_data);
        //     if (read_data !== (expected_data + i)) begin
        //         $display(
        //             "ERROR: Instruction Memory Data Mismatch at address 0x%08X! Expected 0x%08X, Got 0x%08X",
        //             test_address + i * 4, expected_data + i, read_data);
        //         test_passed = 0;
        //     end else begin
        //         $display("Instruction at address 0x%08X verified: 0x%08X", test_address + i * 4,
        //                  read_data);
        //     end
        // end

        #(WAIT_BETWEEN_STEPS);
        step = 3;
        // // --------------------------------------------
        // // Test 3: Write Data to Data Memory via UART and Verify
        // // --------------------------------------------
        // $display("\nTest 3: Writing Data to Data Memory via UART...");
        // i_select_mem  = 1;  // Select Data Memory
        // test_address  = 32'h00000000;  // Starting address in Data Memory
        // expected_data = 32'hA5A5A5A5;  // Data to write

        // test_write_to_memory(test_address, expected_data);

        #(WAIT_BETWEEN_STEPS);
        step = 4;
        // // --------------------------------------------
        // // Test 4: Read Data from Data Memory via UART and Verify
        // // --------------------------------------------
        // $display("\nTest 4: Reading Data from Data Memory via UART...");
        // test_read_from_memory(test_address, read_data);

        // if (read_data !== expected_data) begin
        //     $display("ERROR: Data Memory Data Mismatch! Expected 0x%08X, Got 0x%08X",
        //              expected_data, read_data);
        //     test_passed = 0;
        // end else begin
        //     $display("Data Memory Data Verified Successfully.");
        // end

        #(WAIT_BETWEEN_STEPS);
        step = 5;
        // // --------------------------------------------
        // // Test 5: Run Program on Core and Verify Result in Data Memory
        // // --------------------------------------------
        // $display("\nTest 5: Running Program on Core and Verifying Result...");
        // i_select_mem = 0;  // Select Instruction Memory

        // // Simple program to write 0xDEADBEEF to Data Memory at address 0x00000010
        // // Instructions (RISC-V machine code):
        // // 0x00000000: LUI x1, 0xDEADB      (opcode: 0xDEADB137)
        // // 0x00000004: ADDI x1, x1, 0xEEF   (opcode: 0xEEF31313)
        // // 0x00000008: SW x1, 0x10(x0)      (opcode: 0x01012023)
        // // 0x0000000C: NOP                  (opcode: 0x00000013)

        // // Loading instructions into Instruction Memory
        // test_write_to_memory(32'h00000000, 32'hDEADB137);  // LUI x1, 0xDEADB
        // test_write_to_memory(32'h00000004, 32'hEEF31313);  // ADDI x1, x1, 0xEEF
        // test_write_to_memory(32'h00000008, 32'h01012023);  // SW x1, 0x10(x0)
        // test_write_to_memory(32'h0000000C, 32'h00000013);  // NOP

        // // Allow some time for the core to execute the program
        // #1000;  // Adjust timing as needed for the core to complete execution

        // // Read back the result from Data Memory
        // i_select_mem  = 1;  // Select Data Memory
        // test_address  = 32'h00000010;  // Address where data should have been written
        // expected_data = 32'hDEADBEEF;  // Expected data

        // test_read_from_memory(test_address, read_data);

        // if (read_data !== expected_data) begin
        //     $display(
        //         "ERROR: Program Execution Failed! Expected Data 0x%08X at Address 0x%08X, Got 0x%08X",
        //         expected_data, test_address, read_data);
        //     test_passed = 0;
        // end else begin
        //     $display("Program Execution Successful. Data at Address 0x%08X is 0x%08X",
        //              test_address, read_data);
        // end

        // --------------------------------------------
        // Final Test Result
        // --------------------------------------------
        if (test_passed) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\nSome tests FAILED.");
        end

        $finish;
    end

    // Task to Test Writing Data to Memory via UART
    task test_write_to_memory(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_WRITE command
            uart_send_byte(CMD_WRITE);
            $display("Sent CMD_WRITE Command.");
            #(WAIT_BETWEEN_UART_SEND_CMD);

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%08X", address);

            // Send Data (LSB first)
            uart_send_word(data, DATA_WIDTH);
            $display("Sent Data: 0x%08X", data);

            // Wait for UART bridge to return to IDLE state
            wait (dut.U_UART_WB_BRIDGE.state == STATE_IDLE);
            #CLK_PERIOD;
        end
    endtask

    // Task to Test Reading Data from Memory via UART
    task test_read_from_memory(input [ADDR_WIDTH-1:0] address, output reg [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_READ command
            uart_send_byte(CMD_READ);
            $display("Sent CMD_READ Command.");
            #(WAIT_BETWEEN_UART_SEND_CMD);

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%08X", address);

            // Receive Data via UART
            uart_receive_word(data);
            $display("Received Data: 0x%08X", data);
        end
    endtask

    // Task to Send a Byte via UART to DUT
    task uart_send_byte(input [7:0] data);
        integer bit_idx;
        begin
            // Start Bit
            i_uart_rx = 0;
            #(BIT_PERIOD);

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                i_uart_rx = data[bit_idx];
                #(BIT_PERIOD);
            end

            // Stop Bit
            i_uart_rx = 1;
            #(BIT_PERIOD);

            // Wait a bit before next byte
            #(WAIT_BETWEEN_UART_SEND_BYTE);
        end
    endtask

    // Task to Send a Word (multiple bytes) via UART to DUT
    task uart_send_word(input [DATA_WIDTH-1:0] data, input integer width);
        integer byte_count;
        reg [7:0] byte_data;
        begin
            for (byte_count = 0; byte_count < (width / 8); byte_count = byte_count + 1) begin
                byte_data = data[8*byte_count+:8];  // Extract byte (LSB first)
                uart_send_byte(byte_data);
            end
        end
    endtask

    // Task to Capture a Byte Sent from DUT via UART
    task uart_capture_byte;
        output reg [7:0] data;  // Output for captured byte
        integer bit_idx;  // Loop index for capturing each bit
        begin
            // Wait for Start Bit
            wait (o_uart_tx == 0);
            #(BIT_PERIOD / 2);  // Sample in the middle of the start bit

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                #(BIT_PERIOD);
                data[bit_idx] = o_uart_tx;
            end

            // Stop Bit
            #(BIT_PERIOD);
        end
    endtask

    // Task to Receive a Word (multiple bytes) via UART from DUT
    task automatic uart_receive_word(output reg [DATA_WIDTH-1:0] data);
        integer byte_count;
        reg [7:0] received_byte;
        begin
            data = 0;
            for (byte_count = 0; byte_count < (DATA_WIDTH / 8); byte_count = byte_count + 1) begin
                uart_capture_byte(received_byte);  // Call the task with output argument
                data = data | (received_byte << (8 * byte_count));
            end
        end
    endtask

endmodule
