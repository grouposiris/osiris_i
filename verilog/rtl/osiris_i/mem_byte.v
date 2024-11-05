module mem_byte #(
    parameter DATA_WIDTH = 32,
    parameter MEM_SIZE_KB   = 64   // in KB
) (
    clk,       // Clock
    rst,       // Reset
    wb_adr_i,  // byte-addressable input
    wb_dat_i,  // Wishbone data input
    wb_we_i,   // Wishbone write enable
    wb_stb_i,  // Wishbone strobe
    wb_cyc_i,  // Wishbone cycle
    wb_dat_o,  // Wishbone data output
    wb_ack_o   // Wishbone acknowledge
);
    // xxx -> instr -> LSB 
    // 0000000000000001 10

    // Calculate the memory depth (number of entries)
    localparam MEM_DEPTH = (MEM_SIZE_KB * 1024) / (DATA_WIDTH / 8);
    // Calculate the address width
    localparam ADDR_WIDTH = $clog2(MEM_DEPTH);

    // Interface Declaration
    input  wire                  clk;       // Clock
    input  wire                  rst;       // Reset
    input  wire [ADDR_WIDTH-1:0] wb_adr_i;  // byte-addressable input
    input  wire [DATA_WIDTH-1:0] wb_dat_i;  // Wishbone data input
    input  wire                  wb_we_i;   // Wishbone write enable
    input  wire                  wb_stb_i;  // Wishbone strobe
    input  wire                  wb_cyc_i;  // Wishbone cycle
    output wire [DATA_WIDTH-1:0] wb_dat_o;  // Wishbone data output
    output reg                   wb_ack_o;  // Wishbone acknowledge

    // Define the memory array with calculated depth
    reg [DATA_WIDTH-1:0] mem[0:MEM_DEPTH-1];

    // Word address calculation (byte address divided by 4)
    wire [ADDR_WIDTH-1:0] word_addr            = wb_adr_i[ADDR_WIDTH-1:2];
    wire [1:0]            byte_selection       = wb_adr_i[1:0];
    reg  [3:0]            byte_one_hot_sel;

    integer i;

    // Byte Selection - One-Hot-Encoder
    always @(*) begin
        byte_one_hot_sel = 'b0;
        case (byte_selection)
            2'b00: byte_one_hot_sel[0] <= 1'b1;
            2'b01: byte_one_hot_sel[1] <= 1'b1;
            2'b10: byte_one_hot_sel[2] <= 1'b1;
            2'b11: byte_one_hot_sel[3] <= 1'b1;
        endcase
    end


    always @(posedge clk) begin
        if (rst) begin
            wb_ack_o <= 0;
            // Reset all memory contents to zero
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                mem[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            wb_ack_o <= 0;  // Deassert ack by default
            if (wb_cyc_i && wb_stb_i) begin
                wb_ack_o <= 1;  // Acknowledge the transaction
                if (wb_we_i) begin
                    // Write operation with byte enables
                    if (byte_one_hot_sel[0]) mem[word_addr][7:0]   <= wb_dat_i[7:0];
                    if (byte_one_hot_sel[1]) mem[word_addr][15:8]  <= wb_dat_i[15:8];
                    if (byte_one_hot_sel[2]) mem[word_addr][23:16] <= wb_dat_i[23:16];
                    if (byte_one_hot_sel[3]) mem[word_addr][31:24] <= wb_dat_i[31:24];
                end
            end
        end
    end
    // Read operation
    assign wb_dat_o = (wb_cyc_i && wb_stb_i && !wb_we_i) ? mem[wb_adr_i] : {DATA_WIDTH{1'b0}};

endmodule
