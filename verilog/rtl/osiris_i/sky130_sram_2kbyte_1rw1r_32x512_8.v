// ------------------------------------------------------------------------
// SkyWater SKY130 2KB SRAM Module
// Module Name: sky130_sram_2kbyte_1rw1r_32x512_8
// Description: 
//   - A dual-port SRAM with:
//     - Port 0: Single Read/Write (1RW) port
//     - Port 1: Single Read-Only (1R) port
//   - Memory Size:
//     - 512 words of 32 bits each (512 x 32 bits)
//     - Total size: 2KB
//   - Write size granularity: 8 bits (byte-wise write enable)
// ------------------------------------------------------------------------

module sky130_sram_2kbyte_1rw1r_32x512_8 (
`ifdef USE_POWER_PINS
    vccd1,  // Positive power supply
    vssd1,  // Ground
`endif
    // Port 0: Read/Write Port
    clk0,  // Clock input for Port 0
    csb0,  // Chip Select (active low) for Port 0
    web0,  // Write Enable (active low) for Port 0
    wmask0,  // Write Mask for byte-wise write enable
    addr0,  // Address input for Port 0
    din0,  // Data input for Port 0
    dout0,  // Data output for Port 0
    // Port 1: Read-Only Port
    clk1,  // Clock input for Port 1
    csb1,  // Chip Select (active low) for Port 1
    addr1,  // Address input for Port 1
    dout1  // Data output for Port 1
);

    // ------------------------------
    // Parameter Declarations
    // ------------------------------
    parameter NUM_WMASKS = 4;  // Number of write mask bits (one per byte)
    parameter DATA_WIDTH = 32;  // Width of the data bus (32 bits)
    parameter ADDR_WIDTH = 9;  // Width of the address bus (512 addresses => 2^9)
    parameter RAM_DEPTH = 1 << ADDR_WIDTH;  // Depth of the memory (512 words)
    parameter DELAY = 3;  // Simulated delay for read operations
    parameter VERBOSE = 1;  // Verbosity flag for simulation messages
    parameter T_HOLD = 1;  // Hold time for outputs after clock edge

`ifdef USE_POWER_PINS
    // Power pins (used in physical design)
    inout vccd1;  // Power supply
    inout vssd1;  // Ground
`endif

    // ------------------------------
    // Port 0 Signals (Read/Write Port)
    // ------------------------------
    input clk0;  // Clock input for Port 0
    input csb0;  // Chip Select (active low) for Port 0
    input web0;  // Write Enable (active low) for Port 0
    input [NUM_WMASKS-1:0] wmask0;  // Write Mask for byte-wise write enable (4 bits)
    input [ADDR_WIDTH-1:0] addr0;  // Address input for Port 0 (9 bits)
    input [DATA_WIDTH-1:0] din0;  // Data input for Port 0 (32 bits)
    output [DATA_WIDTH-1:0] dout0;  // Data output for Port 0 (32 bits)

    // ------------------------------
    // Port 1 Signals (Read-Only Port)
    // ------------------------------
    input clk1;  // Clock input for Port 1
    input csb1;  // Chip Select (active low) for Port 1
    input [ADDR_WIDTH-1:0] addr1;  // Address input for Port 1 (9 bits)
    output [DATA_WIDTH-1:0] dout1;  // Data output for Port 1 (32 bits)

    // ------------------------------
    // Internal Registers and Wires
    // ------------------------------

    // Registers for Port 0 (captured on the positive edge of clk0)
    reg csb0_reg;  // Registered Chip Select for Port 0
    reg web0_reg;  // Registered Write Enable for Port 0
    reg [NUM_WMASKS-1:0] wmask0_reg;  // Registered Write Mask for Port 0
    reg [ADDR_WIDTH-1:0] addr0_reg;  // Registered Address for Port 0
    reg [DATA_WIDTH-1:0] din0_reg;  // Registered Data Input for Port 0
    reg [DATA_WIDTH-1:0] dout0;  // Data Output for Port 0 (registered)

    // Registers for Port 1 (captured on the positive edge of clk1)
    reg csb1_reg;  // Registered Chip Select for Port 1
    reg [ADDR_WIDTH-1:0] addr1_reg;  // Registered Address for Port 1
    reg [DATA_WIDTH-1:0] dout1;  // Data Output for Port 1 (registered)

    // Memory array declaration
    reg [DATA_WIDTH-1:0] mem[0:RAM_DEPTH-1];  // Memory array (512 x 32 bits)

    // ------------------------------
    // Port 0 Input Registration
    // ------------------------------
    // Capture the inputs on the positive edge of clk0
    always @(posedge clk0) begin
        csb0_reg   <= csb0;  // Register Chip Select
        web0_reg   <= web0;  // Register Write Enable
        wmask0_reg <= wmask0;  // Register Write Mask
        addr0_reg  <= addr0;  // Register Address
        din0_reg   <= din0;  // Register Data Input

        // After T_HOLD time units, set dout0 to unknown if csb0 is inactive
        // #(T_HOLD)
        // dout0 <= (csb0_reg) ? {DATA_WIDTH{1'bx}} : dout0;

        // Optional verbosity for simulation
        if (!csb0_reg && web0_reg && VERBOSE)
            // $display($time, " Reading from Port 0: addr0=%h dout0=%h", addr0_reg, mem[addr0_reg]);
            if (!csb0_reg && !web0_reg && VERBOSE)
                $display(
                    $time,
                    " Writing to Port 0: addr0=%h din0=%h wmask0=%b",
                    addr0_reg,
                    din0_reg,
                    wmask0_reg
                );
    end

    // ------------------------------
    // Port 1 Input Registration
    // ------------------------------
    // Capture the inputs on the positive edge of clk1
    always @(posedge clk1) begin
        csb1_reg  <= csb1;  // Register Chip Select
        addr1_reg <= addr1;  // Register Address

        // // After T_HOLD time units, set dout1 to unknown if csb1 is inactive
        // #(T_HOLD) dout1 <= (csb1_reg) ? {DATA_WIDTH{1'bx}} : dout1;

        // Optional verbosity for simulation
        if (!csb1_reg && VERBOSE)
            $display($time, " Reading from Port 1: addr1=%h dout1=%h", addr1_reg, mem[addr1_reg]);
    end

    // ------------------------------
    // Memory Write Operation (Port 0)
    // ------------------------------
    // Perform write operation on the negative edge of clk0
    always @(negedge clk0) begin
        // Check if Port 0 is active and write operation is enabled
        if (!csb0_reg && !web0_reg) begin
            // Byte-wise write operation using write mask
            if (wmask0_reg[0]) mem[addr0_reg][7:0] <= din0_reg[7:0];  // Write byte 0
            if (wmask0_reg[1]) mem[addr0_reg][15:8] <= din0_reg[15:8];  // Write byte 1
            if (wmask0_reg[2]) mem[addr0_reg][23:16] <= din0_reg[23:16];  // Write byte 2
            if (wmask0_reg[3]) mem[addr0_reg][31:24] <= din0_reg[31:24];  // Write byte 3
        end
    end

    // ------------------------------
    // Memory Read Operation (Port 0)
    // ------------------------------
    // Perform read operation on the negative edge of clk0
    always @(negedge clk0) begin
        // Check if Port 0 is active and read operation is enabled
        if (!csb0_reg && web0_reg) begin
            // dout0 <= #(DELAY) mem[addr0_reg];  // Read data with simulated delay
            dout0 <= mem[addr0_reg];  // Read data with simulated delay
        end
    end

    // ------------------------------
    // Memory Read Operation (Port 1)
    // ------------------------------
    // Perform read operation on the negative edge of clk1
    always @(negedge clk1) begin
        // Check if Port 1 is active
        if (!csb1_reg) begin
            // dout1 <= #(DELAY) mem[addr1_reg];  // Read data with simulated delay
            dout1 <= mem[addr1_reg];  // Read data with simulated delay
        end
    end

    // ------------------------------
    // Conflict Detection (Optional)
    // ------------------------------
    // Issue a warning if both ports access the same address simultaneously
    always @(posedge clk0 or posedge clk1) begin
        if (!csb0 && !web0 && !csb1 && (addr0 == addr1)) begin
            $display(
                $time,
                " WARNING: Simultaneous write and read to the same address (%h) on different ports!",
                addr0);
        end
    end

endmodule
