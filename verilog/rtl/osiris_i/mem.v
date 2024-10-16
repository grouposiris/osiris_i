module mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter MEM_SIZE   = 64   // in KB
) (
    input  wire                  clk,       // Clock
    input  wire                  rst,       // Reset
    input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    input  wire [DATA_WIDTH-1:0] wb_dat_i,  // Wishbone data input
    input  wire                  wb_we_i,   // Wishbone write enable
    input  wire                  wb_stb_i,  // Wishbone strobe
    input  wire                  wb_cyc_i,  // Wishbone cycle
    output wire [DATA_WIDTH-1:0] wb_dat_o,  // Wishbone data output
    output reg                   wb_ack_o   // Wishbone acknowledge
);

    // Memory array: 64KB Memory, 32-bit wide
    reg [DATA_WIDTH-1:0] mem[0:(MEM_SIZE * 1024 / 4) - 1];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            wb_ack_o <= 0;
            // Reset all memory contents to zero
            for (i = 0; i < (MEM_SIZE * 1024 / 4); i = i + 1) begin
                mem[i] <= {DATA_WIDTH{1'b0}};
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
