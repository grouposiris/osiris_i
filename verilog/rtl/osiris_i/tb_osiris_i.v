`timescale 1ns / 1ps

module tb_osiris_i;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter BAUD_RATE = 9600;
    parameter CLOCK_FREQ = 50000000;  // 50 MHz clock
    parameter CLK_PERIOD = 1e9 / CLOCK_FREQ;  // Clock period in nanoseconds

    // Clock and Reset
    reg  clk;
    reg  rst;

    // UART Signals
    reg  uart_rx;
    wire uart_tx;

    // Control Signals
    reg  start_rx;
    reg  select_mem;  // Control signal to select which memory to communicate with

    // Instantiate the osiris_i module (Device Under Test)
    osiris_i #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ)
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .select_mem(select_mem),
        .start_rx(start_rx)
    );

    // UART Timing
    real BIT_PERIOD;
    initial begin
        BIT_PERIOD = 1e9 / BAUD_RATE;  // Bit period in nanoseconds
    end

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;  // Toggle clock every half period
    end

    // Reset Sequence
    initial begin
        rst = 1;
        start_rx = 0;
        select_mem = 0;
        uart_rx = 1;  // UART line idle (high)
        #100;
        rst = 0;
        start_rx = 1;  // Enable UART reception
    end

    // Test Variables
    integer i;
    reg test_passed;
    reg [DATA_WIDTH-1:0] read_data;
    reg [DATA_WIDTH-1:0] expected_data;
    reg [ADDR_WIDTH-1:0] test_address;

    // Main Test Sequence
    initial begin
        test_passed = 1;

        $display("Starting osiris_i Testbench...");
        #200;  // Wait for reset to deassert

        // Test 1: Write Data to Instruction Memory via UART and Verify
        $display("\nTest 1: Writing Data to Instruction Memory...");
        select_mem = 0;  // Select Instruction Memory
        test_address = 32'h00000010;  // Address to write to
        expected_data = 32'hA5A5A5A5;  // Data to write

        test_write_to_memory(test_address, expected_data);

        // Test 2: Read Data from Instruction Memory via UART and Verify
        $display("\nTest 2: Reading Data from Instruction Memory...");
        test_read_from_memory(test_address, read_data);

        if (read_data !== expected_data) begin
            $display("ERROR: Instruction Memory Data Mismatch! Expected 0x%08X, Got 0x%08X",
                     expected_data, read_data);
            test_passed = 0;
        end else begin
            $display("Instruction Memory Data Verified Successfully.");
        end

        // Test 3: Write Data to Data Memory via UART and Verify
        $display("\nTest 3: Writing Data to Data Memory...");
        select_mem = 1;  // Select Data Memory
        test_address = 32'h00000020;  // Address to write to
        expected_data = 32'h5A5A5A5A;  // Data to write

        test_write_to_memory(test_address, expected_data);

        // Test 4: Read Data from Data Memory via UART and Verify
        $display("\nTest 4: Reading Data from Data Memory...");
        test_read_from_memory(test_address, read_data);

        if (read_data !== expected_data) begin
            $display("ERROR: Data Memory Data Mismatch! Expected 0x%08X, Got 0x%08X",
                     expected_data, read_data);
            test_passed = 0;
        end else begin
            $display("Data Memory Data Verified Successfully.");
        end

        // Final Test Result
        if (test_passed) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\nSome tests FAILED.");
        end

        $finish;
    end

    // Task to Test Writing Data to Memory
    task test_write_to_memory(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_WRITE command
            uart_send_byte(8'hAA);
            $display("Sent CMD_WRITE Command.");

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%0h", address);

            // Send Data (LSB first)
            uart_send_word(data, DATA_WIDTH);
            $display("Sent Data: 0x%0h", data);

            // Wait for UART bridge to complete the write operation
            wait (dut.U_UART_WB_BRIDGE.state == dut.U_UART_WB_BRIDGE.WB_WRITE);
            wait (dut.U_UART_WB_BRIDGE.state == dut.U_UART_WB_BRIDGE.IDLE);
            #CLK_PERIOD;

            $display("Data Written to Memory at Address 0x%0h", address);
        end
    endtask

    // Task to Test Reading Data from Memory
    task test_read_from_memory(input [ADDR_WIDTH-1:0] address, output reg [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_READ command
            uart_send_byte(8'h01);
            $display("Sent CMD_READ Command.");

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%0h", address);

            // Receive Data via UART
            data = uart_receive_word(DATA_WIDTH);
            $display("Received Data: 0x%0h", data);
        end
    endtask

    // Task to Send a Byte via UART to DUT
    task uart_send_byte(input [7:0] data);
        integer bit_idx;
        begin
            // Start Bit
            uart_rx = 0;
            #(BIT_PERIOD);

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx = data[bit_idx];
                #(BIT_PERIOD);
            end

            // Stop Bit
            uart_rx = 1;
            #(BIT_PERIOD);

            // Wait a bit before next byte
            #(BIT_PERIOD);
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

    // Function to Capture a Byte Sent from DUT via UART
    function [7:0] uart_capture_byte;
        integer bit_idx;
        reg [7:0] data;
        begin
            // Wait for Start Bit
            wait (uart_tx == 0);
            #(BIT_PERIOD / 2);  // Sample in the middle of the bit

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                #(BIT_PERIOD);
                data[bit_idx] = uart_tx;
            end

            // Stop Bit
            #(BIT_PERIOD);

            uart_capture_byte = data;
        end
    endfunction

    // Task to Receive a Word (multiple bytes) via UART from DUT
    task automatic uart_receive_word(output reg [DATA_WIDTH-1:0] data);
        integer byte_count;
        reg [7:0] received_byte;
        begin
            data = 0;
            for (byte_count = 0; byte_count < (DATA_WIDTH / 8); byte_count = byte_count + 1) begin
                received_byte = uart_capture_byte();
                data = data | (received_byte << (8 * byte_count));
            end
        end
    endtask

endmodule
