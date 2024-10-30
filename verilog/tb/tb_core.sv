`timescale 1ns / 1ps

module tb_core ();

    // Parameters for simulation
        parameter DATA_WIDTH = 32;
        parameter ADDR_WIDTH = 32;
        parameter INST_MEM_SIZE = 4;  // in KB
        parameter DATA_MEM_SIZE = 4;  // in KB
        parameter CLOCK_FREQ = 50000000;  // 50 MHz

    // Localparameters definition
        localparam INST_MEM_WORDS = (INST_MEM_SIZE * 1024 * 8) / 32; // Inst. Memory has fixed 32 bits (RV32E ISA)
        localparam DATA_MEM_WORDS = (DATA_MEM_SIZE * 1024 * 8 ) / DATA_WIDTH;
        localparam INST_MEM_ADDR_BITS = $clog2(INST_MEM_WORDS);
        localparam DATA_MEM_ADDR_BITS = $clog2(DATA_MEM_WORDS);

    // Testbench signals declaration
        // Global signals
            reg  clk;
            reg  rst_core;
            reg  [15:0] cycle_counter = 0;

        // DUT signals
            reg [DATA_WIDTH-1:0] core_instr_ID;
            reg [DATA_WIDTH-1:0] core_read_data_M;
            wire [DATA_WIDTH-1:0] core_pc_IF;
            wire core_mem_write_M;
            wire [DATA_WIDTH-1:0] core_data_addr_M;
            wire [DATA_WIDTH-1:0] core_write_data_M;

        // Memory Definitions
            reg [DATA_WIDTH-1:0] mem_instr [0:INST_MEM_WORDS-1];
            reg [DATA_WIDTH-1:0] mem_data [0:DATA_MEM_WORDS-1];

    // DUT instantiation
        core #(
            .DATA_WIDTH(DATA_WIDTH)
        ) dut (
            .clk           (clk),
            .rst           (rst_core),
            .i_instr_ID    (core_instr_ID),     // Instruction input to core
            .i_read_data_M (core_read_data_M),  // Data read input to core
            .o_pc_IF       (core_pc_IF),        // Program Counter output from core
            .o_mem_write_M (core_mem_write_M),  // Memory write enable output from core
            .o_data_addr_M (core_data_addr_M),  // Data address output from core
            .o_write_data_M(core_write_data_M)  // Data to write output from core
        );

    // Stimulus definitions

        // VCD dump for waveform viewing
            initial begin
                $dumpfile("tb_core.vcd");
                $dumpvars(0, tb_core);
            end

        // Clock Generation
            initial begin
                clk = 0;
                forever #10 clk = ~clk;  // 50 MHz clock
            end

        // Reset and Initialization
            initial begin
                rst_core = 1;
                $display("---------------------------------------");
                $display("Applying reset...");
                $display("---------------------------------------");
                #20;
                rst_core = 0;
                $display("---------------------------------------");
                $display("Release reset.");
                $display("---------------------------------------");
            end

        // Memory Initialization
            initial begin
                $display("---------------------------------------");
                $display("Initializing memories with zeroes...");
                $display("---------------------------------------");
                for (int i = 0; i < DATA_WIDTH; i++) begin
                    mem_instr[i] = {DATA_WIDTH{1'b0}};
                    mem_data[i] = {DATA_WIDTH{1'b0}};
                end
                mem_instr[0] = 32'h00000093;  // Example: addi x1, x0, 0 (loads 0 into x1)
                mem_instr[4] = 32'h00100113;  // Example: addi x2, x0, 1 (loads 1 into x2)
                mem_instr[8] = 32'h00202023;  // Example: sw x2 4(x0)    (store x2 into mem_data[4])
                $display("---------------------------------------");
                $display("Instruction memory and data memory initialized.");
                $display("---------------------------------------");
            end

        // Monitor register changes
            genvar i;
            generate
                for (i = 0; i < 16; i = i + 1) begin : monitor_registers
                    always @(dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]) begin
                        $display("Time %0t ps: Register[%0d] changed to %h", $time, i, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]);
                    end
                end
            endgenerate

        // Monitor data memory
            generate
                for (i = 0; i < DATA_WIDTH; i++) begin
                    always @(mem_data[i]) begin
                        $display("Time %0t ps: Data Memory [%0d] changed to %h", $time, i, mem_data[i]);
                    end
                end
            endgenerate

        // Monitor CPU cycle counter
            always @(cycle_counter) begin
                $display("Time %0t ps:                  Current Clock Counter: ", $time, cycle_counter);
            end

        // Incrementing the CPU clock counter
            always @(posedge clk & !rst_core) begin
                cycle_counter = cycle_counter + 1;
            end

        // Monitor changes in the PC register
            always @(core_pc_IF) begin
                $display("Time %0t ps: core_pc_IF changed to %h", $time, core_pc_IF);
            end

        // Monitor changes in the Instruction Register
            always @(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID) begin
                $display("Time %0t ps: i_instr_ID changed to %h, Assembly: %s", $time, dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
            end

        // Main Test Sequence
            initial begin
                // Run some simple test instructions
                @(negedge rst_core);
                //display_registers();  // Dump registers after reset


                // Custom tests for specific instructions
                //run_test_sequence();
                
                // Final register dump before simulation ends
                repeat(10) @(posedge clk);
                //display_registers();

                // End of simulation
                #100;
                $display("---------------------------------------");
                $display("Simulation complete.");
                $display("---------------------------------------");
                $finish;
            end

        // Simulate fetching instructions
            // Memory reads are asynchronous
            always @(*) begin
                if (!rst_core) begin
                    core_instr_ID <= mem_instr[core_pc_IF[INST_MEM_ADDR_BITS-1:0]];
                    //$display("Time %0t ps: Instruction Fetch: PC = %h, Instruction = %h, Assembly: %s", $time, core_pc_IF, core_instr_ID, decode_instruction(core_instr_ID));
                end else begin
                    core_instr_ID <= {DATA_WIDTH{1'b1}};
                    //$display("Time %0t ps: Instruction Fetch: PC = %h, Instruction = %h, Assembly: %s", $time, core_pc_IF, core_instr_ID, decode_instruction(core_instr_ID));
                end
            end

        // Simulating data memory reads/writes
            // Writes to the memory are synchronous
            always @(posedge clk) begin
                if (core_mem_write_M & !rst_core) begin
                    mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]] <= core_write_data_M;
                    //$display("Time %0t ps: [Data Memory] Write: Addr = %h, Data = %h",$time, core_data_addr_M, core_write_data_M);
                end
            end

        // Reads from the memory are asynchronous
            always @(*) begin
                if (!core_mem_write_M && !rst_core) begin
                    core_read_data_M <= mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]];
                    $display("Time %0t ps: [Data Memory] - Read - Addr = %h, Data = %h", $time, core_data_addr_M, core_read_data_M);
                end else begin
                    core_read_data_M <= {DATA_WIDTH{1'b1}};
                    $display("Time %0t ps: [Data Memory] - Read - Addr = %h, Data = %h", $time, core_data_addr_M, core_read_data_M);
                end
            end

        // Task to check correctness of results
            task check_result(
                input [DATA_WIDTH-1:0] expected_value,
                input [DATA_WIDTH-1:0] actual_value,
                input [31:0] test_id
            );
                if (expected_value !== actual_value) begin
                    $display("Test %0d FAILED: Expected %h, got %h", test_id, expected_value, actual_value);
                end else begin
                    $display("Test %0d PASSED", test_id);
                end
            endtask

        // Test sequence with instructions
            task run_test_sequence();
                integer test_id = 0;

                // Test example: Load immediate, store, etc.
                // Load immediate test
                mem_instr[0] = 32'h00000093;  // Example: addi x1, x0, 0 (loads 0 into x1)
                mem_instr[1] = 32'h00100113;  // Example: addi x2, x0, 1 (loads 1 into x2)
                //repeat(9) @(posedge clk);  // Allow time for execution

                // $display("Checking results for Load Immediate instructions...");
                // check_result(32'h0, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[1], test_id++);
                // check_result(32'h1, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[2], test_id++);

                // Store and Load test
                // Additional instructions here

                // Output final message
                $display("Test sequence completed.");
            endtask

        // Task to display all registers in the core
            task display_registers;
            integer i;
            begin
                $display("===== Register Dump =====");
                for (i = 0; i < 16; i = i + 1) begin
                    $display("Register[%0d] = %h", i, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]);
                end
                $display("=========================");
            end
            endtask
        
        // Function to decode RV32E instructions
            function string decode_instruction(input [31:0] instr);
                reg [6:0] opcode;
                reg [4:0] rd, rs1, rs2;
                reg [2:0] funct3;
                reg [6:0] funct7;
                reg [31:0] imm;
            begin
                // Extract fields
                opcode = instr[6:0];
                rd     = instr[11:7];
                funct3 = instr[14:12];
                rs1    = instr[19:15];
                rs2    = instr[24:20];
                funct7 = instr[31:25];
                
                // Default response for unknown instructions
                decode_instruction = "UNKNOWN_INSTRUCTION";

                // Decode based on opcode and funct3/funct7 fields
                case (opcode)
                    7'b0110011: begin  // R-Type Instructions (e.g., ADD, SUB, SLL)
                        case ({funct7, funct3})
                            {7'b0000000, 3'b000}: decode_instruction = $sformatf("ADD x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0100000, 3'b000}: decode_instruction = $sformatf("SUB x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0000000, 3'b001}: decode_instruction = $sformatf("SLL x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0000000, 3'b101}: decode_instruction = $sformatf("SRL x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0100000, 3'b101}: decode_instruction = $sformatf("SRA x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0000000, 3'b100}: decode_instruction = $sformatf("XOR x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0000000, 3'b110}: decode_instruction = $sformatf("OR x%0d, x%0d, x%0d", rd, rs1, rs2);
                            {7'b0000000, 3'b111}: decode_instruction = $sformatf("AND x%0d, x%0d, x%0d", rd, rs1, rs2);
                            default: decode_instruction = "UNKNOWN_R_TYPE";
                        endcase
                    end

                    7'b0010011: begin  // I-Type Instructions (e.g., ADDI, SLLI)
                        imm = {{20{instr[31]}}, instr[31:20]}; // Sign-extend immediate
                        case (funct3)
                            3'b000: decode_instruction = $sformatf("ADDI x%0d, x%0d, %0d", rd, rs1, imm);
                            3'b100: decode_instruction = $sformatf("XORI x%0d, x%0d, %0d", rd, rs1, imm);
                            3'b110: decode_instruction = $sformatf("ORI x%0d, x%0d, %0d", rd, rs1, imm);
                            3'b111: decode_instruction = $sformatf("ANDI x%0d, x%0d, %0d", rd, rs1, imm);
                            3'b001: decode_instruction = $sformatf("SLLI x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
                            3'b101: begin
                                if (funct7 == 7'b0000000)
                                    decode_instruction = $sformatf("SRLI x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
                                else
                                    decode_instruction = $sformatf("SRAI x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
                            end
                            default: decode_instruction = "UNKNOWN_I_TYPE";
                        endcase
                    end

                    7'b0000011: begin  // Load Instructions (I-Type)
                        imm = {{20{instr[31]}}, instr[31:20]}; // Sign-extend immediate
                        case (funct3)
                            3'b000: decode_instruction = $sformatf("LB x%0d, %0d(x%0d)", rd, imm, rs1);
                            3'b001: decode_instruction = $sformatf("LH x%0d, %0d(x%0d)", rd, imm, rs1);
                            3'b010: decode_instruction = $sformatf("LW x%0d, %0d(x%0d)", rd, imm, rs1);
                            default: decode_instruction = "UNKNOWN_LOAD_TYPE";
                        endcase
                    end

                    7'b0100011: begin  // Store Instructions (S-Type)
                        imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // Sign-extend immediate
                        case (funct3)
                            3'b000: decode_instruction = $sformatf("SB x%0d, %0d(x%0d)", rs2, imm, rs1);
                            3'b001: decode_instruction = $sformatf("SH x%0d, %0d(x%0d)", rs2, imm, rs1);
                            3'b010: decode_instruction = $sformatf("SW x%0d, %0d(x%0d)", rs2, imm, rs1);
                            default: decode_instruction = "UNKNOWN_STORE_TYPE";
                        endcase
                    end

                    7'b1100011: begin  // Branch Instructions (B-Type)
                        imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // Sign-extend and concatenate
                        case (funct3)
                            3'b000: decode_instruction = $sformatf("BEQ x%0d, x%0d, %0d", rs1, rs2, imm);
                            3'b001: decode_instruction = $sformatf("BNE x%0d, x%0d, %0d", rs1, rs2, imm);
                            3'b100: decode_instruction = $sformatf("BLT x%0d, x%0d, %0d", rs1, rs2, imm);
                            3'b101: decode_instruction = $sformatf("BGE x%0d, x%0d, %0d", rs1, rs2, imm);
                            3'b110: decode_instruction = $sformatf("BLTU x%0d, x%0d, %0d", rs1, rs2, imm);
                            3'b111: decode_instruction = $sformatf("BGEU x%0d, x%0d, %0d", rs1, rs2, imm);
                            default: decode_instruction = "UNKNOWN_BRANCH_TYPE";
                        endcase
                    end

                    7'b1101111: begin  // JAL (J-Type)
                        imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // Sign-extend and concatenate
                        decode_instruction = $sformatf("JAL x%0d, %0d", rd, imm);
                    end

                    7'b1100111: begin  // JALR (I-Type)
                        imm = {{20{instr[31]}}, instr[31:20]}; // Sign-extend immediate
                        decode_instruction = $sformatf("JALR x%0d, x%0d, %0d", rd, rs1, imm);
                    end

                    default: decode_instruction = "UNKNOWN_OPCODE";
                endcase
            end
            endfunction


        
endmodule
