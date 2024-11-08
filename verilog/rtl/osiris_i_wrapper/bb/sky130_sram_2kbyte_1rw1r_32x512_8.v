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
/// sta-blackbox

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


endmodule
