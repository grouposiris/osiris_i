module uart_receiver #(
    parameter BAUD_RATE  = 1,  // Default baud rate (9600 Bps)
    parameter CLOCK_FREQ = 10  // Default clock frequency (50 MHz)
) (
    input wire clk,  // System clock
    input wire rst,  // Reset signal (active high)
    input wire i_rx,  // UART receive line (input from UART)
    input wire i_start_rx,  // * Added a signal to start the reception process to prevent unnecessary power consumption
    output reg [7:0] o_data,  // Output byte of received data
    output reg o_data_valid  // Asserted when a complete byte is received
);

    // UART Configuration Parameters
    // parameter BAUD_RATE = 9600;  // Baud rate of UART communication (bits per second)
    // parameter CLOCK_FREQ = 50000000;  // Frequency of the system clock (e.g., 50 MHz)
    localparam BIT_TIME = CLOCK_FREQ / BAUD_RATE;  // Number of clock cycles per bit (bit duration)
    localparam HALF_BIT_TIME = BIT_TIME /
        2;  // Half of bit duration for accurate sampling (median value for noise reduction)

    // Internal Registers
    reg [ 3:0] bit_index;  // Counter to keep track of the number of bits received (0 to 7)
    reg [15:0] clock_count;  // Counter to time the duration of each bit
    reg [ 7:0] shift_reg;  // Register to shift in the received bits (to assemble the final byte)
    reg        receiving;  // Flag to indicate that we are currently receiving data
    reg
        rx_sync_1,
        rx_sync_2;  // * Added double FF synchronizer for 'rx' input to avoid metastability issues

    // * Double Flip-Flop Synchronizer to synchronize 'rx' input to the clock domain
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync_1 <= 1'b1;  // Initialize to idle state (high)
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= i_rx;  // First flip-flop to synchronize 'rx' input
            rx_sync_2 <= rx_sync_1;  // Second flip-flop to avoid metastability
        end
    end

    // Main UART reception logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all internal registers to their initial state
            bit_index <= 0;
            clock_count <= 0;
            shift_reg <= 0;
            receiving <= 0;
            o_data_valid <= 0;
            o_data <= 0;
        end else begin
            o_data_valid <= 0;  // Clear the 'data_valid' flag unless a new byte is received
            //        clock period
            // start: 1 2 3 4 5 6 7 8 9 10
            // bit 0: 1 2 3 4 5 6 7 8 9 10
            // bit 1: 1 2 3 4 5 6 7 8 9 10
            // bit 2: 1 2 3 4 5 6 7 8 9 10
            // bit 3: 1 2 3 4 5 6 7 8 9 10
            // bit 4: 1 2 3 4 5 6 7 8 9 10
            // bit 5: 1 2 3 4 5 6 7 8 9 10
            // bit 6: 1 2 3 4 5 6 7 8 9 10
            // bit 7: 1 2 3 4 5 6 7 8 9 10


            // * Add a check to ensure the i_start_rx signal is high before starting the reception process
            if (!receiving && i_start_rx) begin
                // $display("[uart_receiver 1]: !receiving && i_start_rx; rx_sync_2=%b", rx_sync_2);
                // We are in the idle state, waiting for the start bit (i_rx line goes low)
                bit_index <= 0;  // Reset bit counter
                clock_count <= HALF_BIT_TIME
                    ;  // Set the counter to half the bit time for median value sampling

                if (rx_sync_2 == 0) begin
                    receiving <= 1;  // Start receiving data
                end else begin
                    receiving <= 0;  // Start receiving data
                end
            end else if (receiving) begin
                // $display("[uart_receiver 2]: receiving, i_start_rx=%b", i_start_rx);
                // We are currently receiving data
                if ({16'b0, clock_count} == BIT_TIME - 1) begin
                    // $display("[uart_receiver 2.A]: clock_count == BIT_TIME - 1");
                    // If the counter reaches the duration of one bit
                    clock_count <= 0;  // Reset the counter for the next bit

                    if (bit_index == 0) begin
                        bit_index <= bit_index + 1;  // Increment bit counter
                    end else if (bit_index < (8 + 1)) begin
                        // $display("--------------------------------------->[uart_receiver 2.A.a]: bit_index < 8");
                        // If we are still in the data portion (8 bits total), shift the incoming bits
                        shift_reg[bit_index-1] <= rx_sync_2;  // * Median value from rx_sync_2 (second FF) to reduce noise/interference
                        bit_index <= bit_index + 1;  // Increment bit counter
                    end else begin
                        // $display("############################################# [uart_receiver 2.A.b]: bit_index >= 8");
                        // We've received all 8 bits, so now we expect the stop bit (ignore it)
                        receiving <= 0;  // Stop the reception process
                        o_data <= shift_reg;  // Move the received data to 'data_out'
                        o_data_valid <=
                            1;  // Assert 'data_valid' to indicate a complete byte has been received
                    end
                end else begin
                    // Increment the clock count to keep track of bit duration
                    clock_count <= clock_count + 1;
                    // $display("[uart_receiver 3]: clock_count=%d, BIT_TIME=%d", clock_count,
                    //          BIT_TIME);
                end
            end else begin
                // $display("[uart_receiver 4]: ~receiving, i_start_rx=%b", i_start_rx);
            end
        end
    end
endmodule
