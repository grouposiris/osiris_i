module mem #(
    parameter DATA_WIDTH = 32,
    // parameter ADDR_WIDTH = 14   // 13 = 32kB, 14 = 64KB
    parameter MEM_SIZE   = 64   // in KB
) (
    clk,  // Clock
    rst,  // Reset
    // input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    wb_adr_i,  // Adjusted address input width
    wb_dat_i,  // Wishbone data input
    wb_we_i,  // Wishbone write enable
    wb_stb_i,  // Wishbone strobe
    wb_cyc_i,  // Wishbone cycle
    wb_dat_o,  // Wishbone data output
    wb_ack_o  // Wishbone acknowledge
);
    // Memory array: 64KB Memory, 32-bit wide
    // reg [DATA_WIDTH-1:0] mem[0:(MEM_SIZE * 1024 / 4) - 1];

    // // Memory depth calculation   based on ADDR_WIDTH
    // localparam MEM_DEPTH = 2 ** ADDR_WIDTH;
    // // Memory array with calculated depth
    // reg [DATA_WIDTH-1:0] mem[0:MEM_DEPTH - 1];

    // Calculate the memory depth (number of entries) based on MEM_SIZE and DATA_WIDTH
    localparam MEM_DEPTH = (MEM_SIZE * 1024 * 8) / DATA_WIDTH;

    // Define the memory array with calculated depth
    reg [DATA_WIDTH-1:0] mem[0:MEM_DEPTH-1];

    input wire clk;  // Clock
    input wire rst;  // Reset
    // input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    input wire [$clog2(MEM_DEPTH)-1:0] wb_adr_i;  // Adjusted address input width
    input wire [DATA_WIDTH-1:0] wb_dat_i;  // Wishbone data input
    input wire wb_we_i;  // Wishbone write enable
    input wire wb_stb_i;  // Wishbone strobe
    input wire wb_cyc_i;  // Wishbone cycle
    output wire [DATA_WIDTH-1:0] wb_dat_o;  // Wishbone data output
    output reg wb_ack_o;  // Wishbone acknowledge

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            wb_ack_o <= 0;
            // Reset all memory contents to zero
            for (i = 0; i < (MEM_SIZE * 1024 / 4); i = i + 1) begin
                // mem[i] <= {(DATA_WIDTH / 2) {2'b10}};
                mem[i] <= 32'h00000033;
                // mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (wb_cyc_i && wb_stb_i) begin
            wb_ack_o <= 1;
            if (wb_we_i) begin
                mem[wb_adr_i] <= wb_dat_i;  // Write operation
            end
        end else begin
            wb_ack_o <= 0;
        end
    end

    // Read operation
    assign wb_dat_o = (wb_cyc_i && wb_stb_i && !wb_we_i) ? mem[wb_adr_i] : {DATA_WIDTH{1'b0}};

endmodule
