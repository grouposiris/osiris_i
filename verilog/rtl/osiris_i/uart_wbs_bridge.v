module uart_wbs_bridge #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  uart_rx,   // UART receive line
    output wire                  uart_tx,   // UART transmit line
    // Wishbone signals
    output reg                   wb_cyc_o,  // Wishbone cycle
    output reg                   wb_stb_o,  // Wishbone strobe
    output reg                   wb_we_o,   // Wishbone write enable: 0 = read, 1 = write
    output reg  [ADDR_WIDTH-1:0] wb_adr_o,  // Wishbone address
    output reg  [DATA_WIDTH-1:0] wb_dat_o,  // Wishbone data output
    input  wire [DATA_WIDTH-1:0] wb_dat_i,  // Wishbone data input
    input  wire                  wb_ack_i   // Wishbone acknowledge
);

    // UART interface signals
    wire       uart_rx_valid;  // Asserted when a byte is received
    wire [7:0] uart_rx_data;  // Received byte from UART
    reg        uart_tx_valid;  // Asserted when a byte is to be transmitted
    reg  [7:0] uart_tx_data;  // Byte to be transmitted via UART
    wire       uart_tx_ready;  // UART transmitter ready to accept data

    // Instantiate UART receiver module
    // todo : fix with new interface
    uart_receiver uart_rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .data_out(uart_rx_data),
        .data_valid(uart_rx_valid)
    );

    // todo: check new interface
    // Instantiate UART transmitter module
    uart_transmitter uart_tx_inst (
        .clk(clk),
        .rst(rst),
        .tx(uart_tx),
        .data_in(uart_tx_data),
        .data_valid(uart_tx_valid),
        .ready(uart_tx_ready)
    );

    // Internal registers
    reg [           7:0] cmd_reg;  // Command register
    reg [ADDR_WIDTH-1:0] addr_reg;  // Address register
    reg [DATA_WIDTH-1:0] data_reg;  // Data register
    reg [           3:0] byte_count;  // Byte counter
    reg [           2:0] state;  // State machine register

    // Read/Write command values
    localparam CMD_READ = 8'h01;  // Command to read from memory and send data via UART
    localparam CMD_WRITE =
        8'hAA;  // Command to write data received via UART to memory (changed value for distinction)

    // * CMD_READ read steps:
    //   1. IDLE      -> Wait for the UART command (CMD_READ).
    //   2. READ_ADDR -> Capture the address being sent via UART (this is where the memory should be read from).
    //   3. WB_READ   -> After receiving the complete address, initiate the read operation from memory using the Wishbone protocol.
    //   4. SEND_DATA -> After receiving the data from the Wishbone bus, send it back to the external UART device.

    // * CMD_WRITE write steps:
    //   1. IDLE      -> Wait for the UART command (CMD_WRITE).
    //   2. READ_ADDR -> Capture the address being sent via UART (this is where the data should be written).
    //   3. READ_DATA -> After receiving the address, capture the data to be written to the specified address via UART. // todo: check possible bugs with external UART giving data before this bridge is ready
    //   4. WB_WRITE  -> Initiate the write operation to the memory using the Wishbone protocol.
    //   5. IDLE      -> After the write operation is complete, return to the IDLE state, waiting for the next command.


    // State encoding
    localparam IDLE = 3'd0;
    localparam READ_ADDR = 3'd2;
    localparam READ_DATA = 3'd3;
    localparam WB_WRITE = 3'd4;
    localparam WB_READ = 3'd5;
    localparam SEND_DATA = 3'd6;

    // Main state machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all outputs and registers
            state         <= IDLE;
            wb_cyc_o      <= 0;
            wb_stb_o      <= 0;
            wb_we_o       <= 0;
            wb_adr_o      <= 0;
            wb_dat_o      <= 0;
            cmd_reg       <= 0;
            addr_reg      <= 0;
            data_reg      <= 0;
            byte_count    <= 0;
            uart_tx_valid <= 0;
            uart_tx_data  <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Wait for a command byte from UART
                    wb_cyc_o      <= 0;
                    wb_stb_o      <= 0;
                    wb_we_o       <= 0;
                    uart_tx_valid <= 0;
                    if (uart_rx_valid) begin
                        cmd_reg <= uart_rx_data;
                        byte_count <= 0;

                        if (uart_rx_data == CMD_READ) begin
                            // Read command received: valid command, so preceeds to read the desired address
                            state <= READ_ADDR;
                        end else if (uart_rx_data == CMD_WRITE) begin
                            // Write command received: valid command, so preceeds to read the desired address
                            state <= READ_ADDR;
                        end else begin
                            // Invalid command, stay in IDLE
                            state <= IDLE;
                        end
                    end
                end
                READ_ADDR: begin
                    // Receive address bytes

                    // if (uart_rx_valid) begin
                    // * Here 'addr_reg' is getting one byte per cycle
                    addr_reg <= addr_reg |
                        (uart_rx_data << (8 * byte_count));  // todo: check correct byte order


                    // * after 2 bytes byte_count = 1 (read complete address)
                    if (byte_count == ((ADDR_WIDTH / 8) - 1)) begin
                        byte_count <= 0;
                        if (cmd_reg == CMD_WRITE) begin
                            // Write command, proceed to read data bytes
                            state <= READ_DATA;
                        end else if (cmd_reg == CMD_READ) begin
                            // todo: check this values
                            // Read command, initiate Wishbone read
                            wb_adr_o <= addr_reg;
                            wb_we_o  <= 0;  // Read operation
                            wb_stb_o <= 1;
                            wb_cyc_o <= 1;
                            state    <= WB_READ;
                        end else begin
                            // Invalid command
                            state <= IDLE;
                        end
                    end else begin
                        byte_count <= byte_count + 1;
                    end
                    // end
                end

                READ_DATA: begin
                    // todo: chck this values
                    // Receive data bytes for write operation
                    // * The READ_DATA state specifically handles data reception via UART, not memory.
                    // Receiving data from UART (READ_DATA state): This state captures data being sent from an external UART device

                    // * Interacting with Wishbone Memory (WB_READ and WB_WRITE states):
                    // Once the bridge has fully received the data and address via UART (e.g., command, address, or payload), it will move to states like WB_READ or WB_WRITE to perform the actual memory transaction (read/write) via the Wishbone interface.
                    // If the UART command was a read request, the bridge reads from memory in the WB_READ state, retrieves the data, and later sends it back via UART.

                    // if (uart_rx_valid) begin
                    data_reg   <= data_reg | (uart_rx_data << (8 * byte_count));
                    byte_count <= byte_count + 1;
                    if (byte_count == (DATA_WIDTH / 8 - 1)) begin
                        // All data bytes received, initiate Wishbone write
                        wb_adr_o <= addr_reg;
                        wb_dat_o <= data_reg;
                        wb_we_o  <= 1;  // Write operation
                        wb_stb_o <= 1;
                        wb_cyc_o <= 1;
                        state    <= WB_WRITE;
                    end
                    // end
                end

                WB_WRITE: begin
                    // todo: review this
                    // Wait for Wishbone write acknowledge
                    if (wb_ack_i) begin
                        wb_stb_o <= 0;
                        wb_cyc_o <= 0;
                        wb_we_o  <= 0;
                        state    <= IDLE;  // Return to IDLE state
                    end
                end

                WB_READ: begin
                    // todo: review this
                    // Wait for Wishbone read acknowledge
                    if (wb_ack_i) begin
                        wb_stb_o <= 0;
                        wb_cyc_o <= 0;
                        wb_we_o  <= 0;
                        byte_count <= 0;
                        state    <= SEND_DATA;  // Proceed to send data via UART
                    end
                end

                SEND_DATA: begin
                    // todo: review this
                    // Send read data bytes via UART
                    if (uart_tx_ready && !uart_tx_valid) begin
                        uart_tx_data  <= wb_dat_i[8*byte_count +: 8];
                        uart_tx_valid <= 1;
                        byte_count    <= byte_count + 1;
                        if (byte_count == (DATA_WIDTH / 8 - 1)) begin
                            // All data bytes sent
                            uart_tx_valid <= 0;
                            state <= IDLE;
                        end
                    end else begin
                        uart_tx_valid <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
