`timescale 1ns / 1ps

module tb_uart_wbs_bridge;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter BAUD_RATE = 1e9;
    parameter CLOCK_FREQ = 10e9;  // 50 MHz clock
    // parameter CLOCK_FREQ = 50000000;  // 50 MHz clock
    parameter CLK_PERIOD = 1e9 / CLOCK_FREQ;  // Clock period in nanoseconds
    // Read/Write command values
    localparam CMD_READ = 8'h01;  // Command to read from memory and send data via UART
    localparam CMD_WRITE =
        8'hFF;  // Command to write data received via UART to memory (changed value for distinction)

    // Clock and Reset
    reg                   clk;
    reg                   rst;

    // UART Signals
    reg                   uart_rx;
    wire                  uart_tx;

    // Control Signals
    reg                   start_rx;

    // Wishbone Signals
    wire                  wb_cyc_o;
    wire                  wb_stb_o;
    wire                  wb_we_o;
    wire [ADDR_WIDTH-1:0] wb_adr_o;
    wire [DATA_WIDTH-1:0] wb_dat_o;
    reg  [DATA_WIDTH-1:0] wb_dat_i;
    reg                   wb_ack_i;

    // Instantiate the UART Wishbone Bridge
    uart_wbs_bridge #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BAUD_RATE (BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ),
        .CMD_READ  (CMD_READ),
        .CMD_WRITE (CMD_WRITE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .start_rx(start_rx),
        .wb_cyc_o(wb_cyc_o),
        .wb_stb_o(wb_stb_o),
        .wb_we_o(wb_we_o),
        .wb_adr_o(wb_adr_o),
        .wb_dat_o(wb_dat_o),
        .wb_dat_i(wb_dat_i),
        .wb_ack_i(wb_ack_i)
    );

    // Memory Model for Wishbone Interface
    reg [DATA_WIDTH-1:0] memory[0:(1<<ADDR_WIDTH)-1];  // Simple memory array

    // UART Signals for Testbench Communication
    reg [7:0] uart_tx_buffer[0:1023];  // Buffer to hold UART data to send to DUT
    integer uart_tx_ptr;  // Pointer for UART transmit buffer
    reg [7:0] uart_rx_buffer[0:1023];  // Buffer to hold UART data received from DUT
    integer uart_rx_ptr;  // Pointer for UART receive buffer

    // Test Variables
    integer i;
    reg test_passed;

    initial begin
        $dumpfile("uart_wbs_bridge.vcd");  // Specify VCD output file
        $dumpvars(0, tb_uart_wbs_bridge);  // Dump all variables in this testbench
        // #400 $finish;
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
        uart_rx = 1;  // UART line idle (high)
        wb_ack_i = 0;
        wb_dat_i = 0;
        #100;
        rst = 0;
        start_rx = 1;  // Enable UART reception
    end

    // Main Test Sequence
    initial begin
        test_passed = 1;
        uart_tx_ptr = 0;
        uart_rx_ptr = 0;

        $display("Starting uart_wbs_bridge Testbench...");
        #200;  // Wait for reset to deassert

        // Test 1: Write Data to Memory via UART and Wishbone
        $display("\nTest 1: Writing Data to Memory...");
        test_write_to_memory(16'hBB11, 32'hDEADBEEF);


        #100;
        // Test 2: Read Data from Memory via UART and Wishbone
        $display("\nTest 2: Reading Data from Memory...");
        test_read_from_memory(16'h0010);

        // // Check if the read data matches the written data
        // if (memory[16'h0010] !== 32'hDEADBEEF) begin
        //     $display("ERROR: Data mismatch! Expected 0xDEADBEEF, Got 0x%08X", memory[16'h0010]);
        //     test_passed = 0;
        // end else begin
        //     $display("Data verification successful.");
        // end

        // Final Test Result
        if (test_passed) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\nSome tests FAILED.");
        end

        $finish;
    end
    // always @(posedge clk) begin
    //     $display(uut.uart_rx_inst.bit_index);
    // end

    // Task to Test Writing Data to Memory
    task test_write_to_memory(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_WRITE command
            uart_send_byte(CMD_WRITE);
            $display("Sent CMD_WRITE Command.");

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%0h", address);

            // Send Data (LSB first)
            uart_send_word(data, DATA_WIDTH);
            $display("Sent Data: 0x%0h", data);

            // Wait for Wishbone Write Acknowledge
            $display("uut.state=%b", uut.state);
            wait (uut.state == uut.WB_WRITE);
            wb_ack_i = 1;
            #CLK_PERIOD;
            wb_ack_i = 0;

            // Update memory model
            memory[address] = data;
            $display("Memory at Address 0x%0h updated with Data 0x%0h", address, data);
        end
    endtask

    // Task to Test Reading Data from Memory
    task test_read_from_memory(input [ADDR_WIDTH-1:0] address);
        reg [DATA_WIDTH-1:0] received_data;
        begin
            // Send CMD_READ command
            uart_send_byte(CMD_READ);
            $display("Sent CMD_READ Command.");

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%0h", address);

            // Provide data from memory model
            wait (uut.state == uut.WB_READ);
            wb_dat_i = memory[address];
            wb_ack_i = 1;
            #CLK_PERIOD;
            wb_ack_i = 0;

            // Receive Data via UART
            uart_receive_word(received_data);
            $display("Received Data: 0x%0h", received_data);

            // Verify Data
            if (received_data !== memory[address]) begin
                $display("ERROR: Data mismatch! Expected 0x%08X, Got 0x%08X", memory[address],
                         received_data);
                test_passed = 0;
            end else begin
                $display("Data read matches memory content.");
            end
        end
    endtask

    // Task to Send a Byte via UART to DUT
    task uart_send_byte(input [7:0] data);
        integer bit_idx;
        begin
            // Start Bit
            uart_rx = 0;
            $display("uart_send_byte: sending Start bit = 0");
            #(BIT_PERIOD);

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx = data[bit_idx];
                $display("uart_send_byte: sending bit[%1d] = %b", bit_idx, data[bit_idx]);
                #(BIT_PERIOD);
            end

            // Stop Bit
            uart_rx = 1;
            $display("uart_send_byte: sending Stop bit = 1");
            #(BIT_PERIOD);

            // Wait a bit before next byte
            #(10 * BIT_PERIOD);
        end
    endtask

    // Task to Send a Word (multiple bytes) via UART to DUT
    task uart_send_word(input [DATA_WIDTH-1:0] data, input integer width);
        integer byte_count;
        reg [7:0] byte_data;
        begin
            for (byte_count = 0; byte_count < (width / 8); byte_count = byte_count + 1) begin
                byte_data = data[8*byte_count+:8];  // Extract byte
                uart_send_byte(byte_data);
            end
        end
    endtask

    // Task to Receive a Word (multiple bytes) via UART from DUT
    task automatic uart_receive_word(output reg [DATA_WIDTH-1:0] data);
        integer byte_count;
        reg [7:0] received_byte;
        begin
            data = 0;
            for (byte_count = 0; byte_count < (DATA_WIDTH / 8); byte_count = byte_count + 1) begin
                uart_capture_byte(received_byte);
                data = data | (received_byte << (8 * byte_count));
            end
        end
    endtask

    // // Function to Capture a Byte Sent from DUT via UART
    // function [7:0] uart_capture_byte;
    //     integer bit_idx;
    //     reg [7:0] data;
    //     begin
    //         // Wait for Start Bit
    //         wait (uart_tx == 0);
    //         #(BIT_PERIOD / 2);  // Sample in the middle of the bit

    //         // Data Bits (LSB first)
    //         for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
    //             #(BIT_PERIOD);
    //             data[bit_idx] = uart_tx;
    //         end

    //         // Stop Bit
    //         #(BIT_PERIOD);

    //         uart_capture_byte = data;
    //     end
    // endfunction
    // Task to Capture a Byte Sent from DUT via UART
    task uart_capture_byte;
        output [7:0] data;  // Output for captured byte
        integer bit_idx;  // Loop index for capturing each bit
        begin
            // Wait for Start Bit
            wait (uart_tx == 0);
            #(BIT_PERIOD / 2);  // Sample in the middle of the start bit

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                #(BIT_PERIOD);
                data[bit_idx] = uart_tx;
            end

            // Stop Bit
            #(BIT_PERIOD);
        end
    endtask


    // Calculate Bit Period Based on Baud Rate
    real BIT_PERIOD;
    initial begin
        BIT_PERIOD = 1e9 / BAUD_RATE;  // Bit period in nanoseconds
    end

endmodule
