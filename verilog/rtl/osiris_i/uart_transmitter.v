module uart_transmitter #(
    parameter BAUD_RATE  = 9600,     // Default baud rate (9600 Bps)
    parameter CLOCK_FREQ = 50000000  // Default clock frequency (50 MHz)
) (
    input  wire       clk,
    input  wire       rst,
    output reg        tx,          // UART transmit line
    input  wire [7:0] data_in,     // Byte to transmit
    input  wire       data_valid,  // Assert to start transmission
    output reg        ready        // Indicates transmitter is ready for new data
);
    // Parameters for UART configuration
    localparam BIT_TIME = CLOCK_FREQ / BAUD_RATE;

    // Internal registers and signals
    reg [ 3:0] bit_index;  // Bit counter (0 to 9)
    reg [15:0] clock_count;  // Clock counter for bit timing
    reg [ 9:0] shift_reg;  // Shift register including start and stop bits
    // reg [ 7:0] shift_reg;  // Shift register including start and stop bits
    reg        transmitting;  // Flag indicating transmission is in progress

    // UART transmission logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx           <= 1;  // Idle state is high
            bit_index    <= 0;
            clock_count  <= 0;
            transmitting <= 0;
            ready        <= 1;
            shift_reg    <= 0;
        end else begin
            if (transmitting) begin
                if (clock_count == BIT_TIME - 1) begin
                    clock_count <= 0;
                    bit_index   <= bit_index + 1;
                    if (bit_index < 10) begin
                        tx <= shift_reg[bit_index];
                    end else begin
                        // Transmission complete
                        transmitting <= 0;
                        ready        <= 1;
                        tx           <= 1;  // Return to idle state
                    end
                end else begin
                    clock_count <= clock_count + 1;
                end
            end else begin
                if (data_valid && ready) begin
                    // Load data into shift register with start and stop bits
                    shift_reg    <= {1'b1, data_in, 1'b0};  // {Stop bit, Data[7:0], Start bit}
                    // shift_reg    <= data_in;  // {Stop bit, Data[7:0], Start bit}
                    bit_index    <= 1;
                    transmitting <= 1;
                    ready        <= 0;
                    clock_count  <= 0;
                    tx           <= 0;  // Start bit
                end
            end
        end
    end
endmodule
