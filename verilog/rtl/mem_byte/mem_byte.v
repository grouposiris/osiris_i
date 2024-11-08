module mem_byte #(
    parameter DATA_WIDTH  = 32,
    parameter MEM_SIZE_KB = 2    // Memory size in KB
) (
    clk,  // Clock
    rst,  // Reset
    // input  wire [ADDR_WIDTH-1:0] wb_adr_i,  // Wishbone address input
    wb_adr_i,  // Adjusted address input width
    wb_dat_i,  // Wishbone data input
    wb_we_i,  // Wishbone write enable
    wb_stb_i,  // Wishbone strobe
    wb_cyc_i,  // Wishbone cycle
    funct3,
    wb_dat_o,  // Wishbone data output
    wb_ack_o  // Wishbone acknowledge
);
    // Calculate total memory size in bytes
    localparam MEM_SIZE_BYTES = MEM_SIZE_KB * 1024;
    localparam MEM_DEPTH = (MEM_SIZE_KB * 1024 * 8) / DATA_WIDTH;

    input wire clk;  // Clock
    input wire rst;  // Reset
    input wire [$clog2(MEM_DEPTH)-1:0] wb_adr_i;  // Adjusted address input width
    input wire [DATA_WIDTH-1:0] wb_dat_i;  // Wishbone data input
    input wire wb_we_i;  // Wishbone write enable
    input wire wb_stb_i;  // Wishbone strobe
    input wire wb_cyc_i;  // Wishbone cycle
    input wire [2:0] funct3;  // RISC-V funct3 field to specify operation
    output wire [DATA_WIDTH-1:0] wb_dat_o;  // Wishbone data output
    output reg wb_ack_o;  // Wishbone acknowledge


    // Define the memory array as bytes
    reg [7:0] mem[0:MEM_SIZE_BYTES-1];

    // Data register for read operations
    reg [DATA_WIDTH-1:0] data_reg;
    // assign wb_dat_o = data_reg;

    // Internal wire for address
    wire [$clog2(MEM_DEPTH)-1:0] addr;
    assign addr = wb_adr_i;

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_ack_o <= 1'b0;
            // Initialize memory contents if needed
            for (i = 0; i < (MEM_SIZE_BYTES / 4); i = i + 4) begin
                mem[i]   <= 8'h33;
                mem[i+1] <= 8'b0;
                mem[i+2] <= 8'b0;
                mem[i+3] <= 8'b0;
            end
        end else begin
            // if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
            if (wb_cyc_i && wb_stb_i) begin
                wb_ack_o <= 1'b1;  // Acknowledge the transaction
                if (wb_we_i) begin
                    // Write operation
                    case (funct3)
                        3'b000: begin  // sb (Store Byte)
                            mem[addr] <= wb_dat_i[7:0];
                        end
                        3'b001: begin  // sh (Store Halfword)
                            mem[addr]   <= wb_dat_i[7:0];
                            mem[addr+1] <= wb_dat_i[15:8];
                        end
                        3'b010: begin  // sw (Store Word)
                            mem[addr]   <= wb_dat_i[7:0];
                            mem[addr+1] <= wb_dat_i[15:8];
                            mem[addr+2] <= wb_dat_i[23:16];
                            mem[addr+3] <= wb_dat_i[31:24];
                        end
                        default: begin  // sw (Store Word)
                            mem[addr]   <= wb_dat_i[7:0];
                            mem[addr+1] <= wb_dat_i[15:8];
                            mem[addr+2] <= wb_dat_i[23:16];
                            mem[addr+3] <= wb_dat_i[31:24];
                            // Unsupported operation
                        end
                    endcase
                end
                // synchronous reading
                // end else begin
                //     // Read operation
                //     case (funct3)
                //         3'b000: begin  // lb (Load Byte): rd = SignExt([wb_adr_i]7:0)
                //             data_reg <= {{24{mem[addr][7]}}, mem[addr]};
                //         end
                //         3'b001: begin  // lh (Load Halfword): rd = SignExt([wb_adr_i]15:0)
                //             data_reg <= {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};
                //         end
                //         3'b010: begin  // lw (Load Word): rd = [wb_adr_i]31:0
                //             data_reg <= {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
                //         end
                //         3'b100: begin  // lbu (Load Byte Unsigned): rd = ZeroExt([wb_adr_i]7:0
                //             data_reg <= {24'b0, mem[addr]};
                //         end
                //         3'b101: begin  // lhu (Load Halfword Unsigned): rd = ZeroExt([wb_adr_i]15:0
                //             data_reg <= {16'b0, mem[addr+1], mem[addr]};
                //         end
                //         default: begin
                //             data_reg <= {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
                //         end
                //     endcase
                // end
            end else begin
                wb_ack_o <= 1'b0;  // De-assert acknowledge
            end
        end
    end

    // asynchronous reading
    always @(*) begin
        if (rst) begin
            data_reg = {DATA_WIDTH{1'b0}};
        end else begin

            case (funct3)
                3'b000: begin  // lb (Load Byte): rd = SignExt([wb_adr_i]7:0)
                    data_reg = {{24{mem[addr][7]}}, mem[addr]};
                end
                3'b001: begin  // lh (Load Halfword): rd = SignExt([wb_adr_i]15:0)
                    data_reg = {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};
                end
                3'b010: begin  // lw (Load Word): rd = [wb_adr_i]31:0
                    data_reg = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
                end
                3'b100: begin  // lbu (Load Byte Unsigned): rd = ZeroExt([wb_adr_i]7:0
                    data_reg = {24'b0, mem[addr]};
                end
                3'b101: begin  // lhu (Load Halfword Unsigned): rd = ZeroExt([wb_adr_i]15:0
                    data_reg = {16'b0, mem[addr+1], mem[addr]};
                end
                default: begin
                    data_reg = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
                end
            endcase
        end
    end
    // Assign data output asynchronously
    assign wb_dat_o = (wb_cyc_i && wb_stb_i && !wb_we_i) ? data_reg : {DATA_WIDTH{1'b0}};
endmodule
