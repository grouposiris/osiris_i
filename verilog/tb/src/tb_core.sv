// `timescale 1ns / 1ps

module tb_core ();

    // Parameters for simulation
        parameter DATA_WIDTH = 32;
        parameter ADDR_WIDTH = 32;
        parameter INST_MEM_SIZE = 4;  // in KB
        parameter DATA_MEM_SIZE = 4;  // in KB
        parameter CLOCK_FREQ = 50000000;  // 50 MHz
        parameter CLK_PERIOD = 1;  // Clock period in nanoseconds

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
            integer f_osiris_core_state_dump;

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

            reg [31:0] encoded_instr;
            string decoded_inst;

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
                $dumpfile("core.vcd");
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
                // #20;
                // rst_core = 0;
                // $display("---------------------------------------");
                // $display("Release reset.");
                // $display("---------------------------------------");
            end


        // Monitor register changes
            genvar i;
            generate
                for (i = 0; i < 16; i = i + 1) begin : monitor_registers
                    always @(dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]) begin
                        $display("      -----> Time %0t ps: Register[x%0d] changed to %d<-  = %b = %h\n\n", $time, i, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i],dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i],dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]);
                        $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | Register[x%0d] changed to %d<-  = %b  = %h\n\n", cycle_counter, i, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i],dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i],dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]);
                    end
                end
            endgenerate

        // Monitor data memory
            generate
                for (i = 0; i < DATA_MEM_WORDS; i++) begin
                    always @(mem_data[i]) begin
                        $display("Time %0t ps: Data Memory [%0d]= [%b] changed to %d<<<--- =%b \n\n", $time, i, i, mem_data[i],mem_data[i]);
                    end
                end
            endgenerate

        // Monitor CPU cycle counter
            always @(cycle_counter) begin
                $display("  Current Clock Counter: %d, at Time %0t ps", cycle_counter, $time);
            end

        // Incrementing the CPU clock counter
            always @(posedge clk & !rst_core) begin
                cycle_counter = cycle_counter + 1;
            end

        // Monitor changes in the PC register
            always @(core_pc_IF) begin
                $display("  Time %0t ps: [Program Counter] core_pc_IF changed to %0d", $time, core_pc_IF);
                $fdisplay(f_osiris_core_state_dump, "   Clock Cycle: %d | [Program Counter] changed to %h", cycle_counter, core_pc_IF);
            end

        // Monitor changes in the Instruction Register
            always @(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID) begin
                $display("  Time %0t ps: [Instruction Register]  i_instr_ID changed to %h, Assembly: %s", $time, dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
                $fdisplay(f_osiris_core_state_dump, "   Clock Cycle: %d | [Instruction Register] changed to %h, Assembly: %s", cycle_counter, dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
            end

        // Main Test Sequence
            initial begin
                // Run some simple test instructions
                // @(negedge rst_core);
                //display_registers();  // Dump registers after reset

                // Seting up the testbench
                // Open the file to store the state of osiris core
                f_osiris_core_state_dump = $fopen("osiris_core_state.dump", "w");
                if (f_osiris_core_state_dump == 0) begin
                    $display("[Error] - Failed to open the file: osiris_core_state.dump");
                end

                $display("---------------------------------------");
                $display("Initializing memories with zeroes...");
                $display("---------------------------------------");
                for (int i = 0; i < INST_MEM_WORDS; i++) begin
                    // mem_instr[i] = {DATA_WIDTH{1'b0}};
                    mem_instr[i] = 32'h00000033;
                    // mem_data[i] = {DATA_WIDTH{1'b0}};
                    mem_data[i] = 32'hAAAAAAAA;
                end
                // mem_instr[0] = 32'h00000093;  // Example: addi x1, x0, 0 (loads 0 into x1)
                // mem_instr[4] = 32'h00100113;  // Example: addi x2, x0, 1 (loads 1 into x2)
                // mem_instr[8] = 32'h00202023;  // Example: sw x2 0(x0)    (store x2 into mem_data[4])
                // mem_instr[8] = 32'h002020a3;  // Example: sw x2 4(x0)    (store x2 into mem_data[4])
                #(10*CLK_PERIOD);
                $display("---------------------------------------");
                $display("Instruction memory and data memory initialized.");
                $display("---------------------------------------");
                #(1*CLK_PERIOD);


                //$display("\n\n\n");
                //encode_instruction_string("sw x7, 16(x2)", encoded_instr);
                //$display("Encoded Instruction for 'sw x7, 16(x2)': %h", encoded_instr);
                //$display("\n\n\n");


                $display("---------------------------------------");
                $display("Initializing memories with instructions...");
                $display("---------------------------------------");
                
                upload_instructions();

                #(1000*CLK_PERIOD);

                rst_core = 0;
                $display("---------------------------------------");
                $display("Release reset.");
                $display("---------------------------------------");

                // Custom tests for specific instructions
                //run_test_sequence();
                
                // Final register dump before simulation ends
                // repeat(10) @(posedge clk);
                //display_registers();

                // End of simulation
                #2000;
                $display("---------------------------------------");
                $display("Simulation complete.");
                $display("---------------------------------------");
                $finish;
            end

        // Simulate fetching instructions
            // Memory reads are asynchronous
            always @(*) begin
                if (!rst_core) begin
                    // if (core_instr_ID!= 0) begin
                        core_instr_ID = mem_instr[core_pc_IF[INST_MEM_ADDR_BITS-1:0]];
                        // $display("->Time %0t ps: Instruction Fetch: PC = %d, Instruction = %h, Assembly: %s", $time, core_pc_IF, core_instr_ID, decode_instruction(core_instr_ID));
                        $display("->Time %0t ps: Instruction Fetch: PC[%d], Instruction = %h, Assembly: %s --------------", $time, core_pc_IF, core_instr_ID, decode_instruction(core_instr_ID));
                    // end
                    // decoded_inst = decode_instruction(core_instr_ID);
                end else begin
                    core_instr_ID = {DATA_WIDTH{1'b1}};
                    //$display("Time %0t ps: Instruction Fetch: PC[%h], Instruction = %h, Assembly: %s", $time, core_pc_IF, core_instr_ID, decode_instruction(core_instr_ID));
                    // decoded_inst = decode_instruction(core_instr_ID);
                end
            end

        // Simulating data memory reads/writes
            // Writes to the memory are synchronous
            always @(posedge clk) begin
                if (core_mem_write_M & !rst_core) begin
                    mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]] <= core_write_data_M;
                    $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | [Data Memory] - Write - Addr = %h, Data = %h", cycle_counter, core_data_addr_M, mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]]);
                    //$display("Time %0t ps: [Data Memory] Write: Addr = %h, Data = %h",$time, core_data_addr_M, core_write_data_M);
                end
            end

        // Reads from the memory are asynchronous // looking at mem.v it seems synchronous // the read operation just uses an 'assign', so it is asynchronous
            // Looking at mem.v, always that a change occurs in the 'wb_adr_i', the value of 'wb_dat_o' also changes. Neither one of those values are registered
            always @(*) begin
                if (!core_mem_write_M && !rst_core) begin
                    core_read_data_M = mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]];
                    if (core_data_addr_M != 32'hxxxxxxxx && core_read_data_M != 32'hFFFFFFFF) begin
                        $display("Time %0t ps: [Data Memory] - Read - Addr = %h, Data = %h", $time, core_data_addr_M, core_read_data_M);
                        $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | [Data Memory] - Read - Addr = %h, Data = %h", cycle_counter, core_data_addr_M, core_read_data_M);
                    end
                end else begin
                    core_read_data_M = {DATA_WIDTH{1'b1}};
                    if (core_data_addr_M != 32'hxxxxxxxx && core_read_data_M != 32'hFFFFFFFF) begin
                        $display("Time %0t ps: [Data Memory] - Read - Addr = %h, Data = %h", $time, core_data_addr_M, core_read_data_M);
                    end
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

        // function to decode instructions from to assembly
        function string decode_instruction(input [31:0] instr);
            reg [6:0] opcode;
            reg [4:0] rd, rs1, rs2;
            reg [2:0] funct3;
            reg [6:0] funct7;
            reg signed [31:0] imm;
            reg [19:0] imm20;
            reg [11:0] imm12;
            reg [12:0] imm13;
            reg [4:0] shamt;
        begin
            // Extract common fields
            opcode = instr[6:0];
            rd     = instr[11:7];
            funct3 = instr[14:12];
            rs1    = instr[19:15];
            rs2    = instr[24:20];
            funct7 = instr[31:25];
            shamt  = instr[24:20]; // For shift instructions

            case (opcode)
                7'b0110011: begin // R-type instructions
                    case (funct3)
                        3'b000: begin
                            if (funct7 == 7'b0000000)
                                decode_instruction = $sformatf("add x%0d, x%0d, x%0d", rd, rs1, rs2);
                            else if (funct7 == 7'b0100000)
                                decode_instruction = $sformatf("sub x%0d, x%0d, x%0d", rd, rs1, rs2);
                            else
                                decode_instruction = "Unknown R-type instruction";
                        end
                        3'b001: begin
                            decode_instruction = $sformatf("sll x%0d, x%0d, x%0d", rd, rs1, rs2);
                        end
                        3'b010: begin
                            decode_instruction = $sformatf("slt x%0d, x%0d, x%0d", rd, rs1, rs2);
                        end
                        3'b011: begin
                            decode_instruction = $sformatf("sltu x%0d, x%0d, x%0d", rd, rs1, rs2);
                        end
                        3'b100: begin
                            decode_instruction = $sformatf("xor x%0d, x%0d, x%0d", rd, rs1, rs2);
                        end
                        3'b101: begin
                            if (funct7 == 7'b0000000)
                                decode_instruction = $sformatf("srl x%0d, x%0d, x%0d", rd, rs1, rs2);
                            else if (funct7 == 7'b0100000)
                                decode_instruction = $sformatf("sra x%0d, x%0d, x%0d", rd, rs1, rs2);
                            else
                                decode_instruction = "Unknown shift instruction";
                        end
                        3'b110: begin
                            decode_instruction = $sformatf("or x%0d, x%0d, x%0d", rd, rs1, rs2);
                        end
                        3'b111: begin
                            decode_instruction = $sformatf("and x%0d, x%0d, x%0d", rd, rs1, rs2);
                        end
                        default: decode_instruction = "Unknown R-type instruction";
                    endcase
                end

                7'b0010011: begin // I-type instructions
                    imm = {{20{instr[31]}}, instr[31:20]}; // Sign-extend immediate
                    case (funct3)
                        3'b000: decode_instruction = $sformatf("addi x%0d, x%0d, %0d", rd, rs1, imm);
                        3'b010: decode_instruction = $sformatf("slti x%0d, x%0d, %0d", rd, rs1, imm);
                        3'b011: decode_instruction = $sformatf("sltiu x%0d, x%0d, %0d", rd, rs1, imm);
                        3'b100: decode_instruction = $sformatf("xori x%0d, x%0d, %0d", rd, rs1, imm);
                        3'b110: decode_instruction = $sformatf("ori x%0d, x%0d, %0d", rd, rs1, imm);
                        3'b111: decode_instruction = $sformatf("andi x%0d, x%0d, %0d", rd, rs1, imm);
                        3'b001: begin // Shift left immediate
                            if (funct7 == 7'b0000000)
                                decode_instruction = $sformatf("slli x%0d, x%0d, %0d", rd, rs1, shamt);
                            else
                                decode_instruction = "Unknown shift immediate instruction";
                        end
                        3'b101: begin
                            if (funct7 == 7'b0000000)
                                decode_instruction = $sformatf("srli x%0d, x%0d, %0d", rd, rs1, shamt);
                            else if (funct7 == 7'b0100000)
                                decode_instruction = $sformatf("srai x%0d, x%0d, %0d", rd, rs1, shamt);
                            else
                                decode_instruction = "Unknown shift immediate instruction";
                        end
                        default: decode_instruction = "Unknown I-type instruction";
                    endcase
                end

                7'b0000011: begin // Load instructions (I-type)
                    imm = {{20{instr[31]}}, instr[31:20]};
                    case (funct3)
                        3'b000: decode_instruction = $sformatf("lb x%0d, %0d(x%0d)", rd, imm, rs1);
                        3'b001: decode_instruction = $sformatf("lh x%0d, %0d(x%0d)", rd, imm, rs1);
                        3'b010: decode_instruction = $sformatf("lw x%0d, %0d(x%0d)", rd, imm, rs1);
                        3'b100: decode_instruction = $sformatf("lbu x%0d, %0d(x%0d)", rd, imm, rs1);
                        3'b101: decode_instruction = $sformatf("lhu x%0d, %0d(x%0d)", rd, imm, rs1);
                        default: decode_instruction = "Unknown load instruction";
                    endcase
                end

                7'b0100011: begin // S-type instructions (Store)
                    imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                    case (funct3)
                        3'b000: decode_instruction = $sformatf("sb x%0d, %0d(x%0d)", rs2, imm, rs1);
                        3'b001: decode_instruction = $sformatf("sh x%0d, %0d(x%0d)", rs2, imm, rs1);
                        3'b010: decode_instruction = $sformatf("sw x%0d, %0d(x%0d)", rs2, imm, rs1);
                        default: decode_instruction = "Unknown store instruction";
                    endcase
                end

                7'b1100011: begin // B-type instructions (Branch)
                    imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
                    case (funct3)
                        3'b000: decode_instruction = $sformatf("beq x%0d, x%0d, %0d", rs1, rs2, imm);
                        3'b001: decode_instruction = $sformatf("bne x%0d, x%0d, %0d", rs1, rs2, imm);
                        3'b100: decode_instruction = $sformatf("blt x%0d, x%0d, %0d", rs1, rs2, imm);
                        3'b101: decode_instruction = $sformatf("bge x%0d, x%0d, %0d", rs1, rs2, imm);
                        3'b110: decode_instruction = $sformatf("bltu x%0d, x%0d, %0d", rs1, rs2, imm);
                        3'b111: decode_instruction = $sformatf("bgeu x%0d, x%0d, %0d", rs1, rs2, imm);
                        default: decode_instruction = "Unknown branch instruction";
                    endcase
                end

                7'b0110111: begin // U-type LUI
                    imm20 = instr[31:12];
                    decode_instruction = $sformatf("lui x%0d, 0x%05x", rd, imm20);
                end

                7'b0010111: begin // U-type AUIPC
                    imm20 = instr[31:12];
                    decode_instruction = $sformatf("auipc x%0d, 0x%05x", rd, imm20);
                end

                7'b1101111: begin // J-type JAL
                    imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
                    decode_instruction = $sformatf("jal x%0d, %0d", rd, imm);
                end

                7'b1100111: begin // I-type JALR
                    imm = {{20{instr[31]}}, instr[31:20]};
                    decode_instruction = $sformatf("jalr x%0d, x%0d, %0d", rd, rs1, imm);
                end

                default: decode_instruction = "Unknown instruction";
            endcase
        end
        endfunction

    task upload_instructions;
        integer inst;
    begin
        // # I-Type Instructions

        // lb (Load byte)
        #(CLK_PERIOD) $display("Sending lb x1, 0(x2)");
        mem_instr[16] = 32'h00010083;  // lb x1, 0(x2)  // Load byte from address x2 + 0 into x1 (value depends on memory content)
        #(CLK_PERIOD) $display("Sending lb x3, -4(x4)");
        mem_instr[20] = 32'hffc20183;  // lb x3, -4(x4)  // Load byte from address x4 - 4 into x3 (value depends on memory content)

        // // lh (Load halfword)
        // #(CLK_PERIOD) $display("Sending lh x5, 2(x6)");
        // mem_instr[392] = 32'h00231283;  // lh x5, 2(x6)  // Load halfword from address x6 + 2 into x5 (value depends on memory content)
        // #(CLK_PERIOD) $display("Sending lh x7, -8(x8)");
        // mem_instr[396] = 32'hff841383;  // lh x7, -8(x8)  // Load halfword from address x8 - 8 into x7 (value depends on memory content)

        // // lw (Load word)
        // #(CLK_PERIOD) $display("Sending lw x9, 4(x10)");
        // mem_instr[400] = 32'h00452483;  // lw x9, 4(x10)  // Load word from address x10 + 4 into x9 (value depends on memory content)
        // #(CLK_PERIOD) $display("Sending lw x11, -12(x12)");
        // mem_instr[404] = 32'hff462583;  // lw x11, -12(x12)  // Load word from address x12 - 12 into x11 (value depends on memory content)

        // // lbu (Load byte unsigned)
        // #(CLK_PERIOD) $display("Sending lbu x13, 0(x14)");
        // mem_instr[408] = 32'h00074683;  // lbu x13, 0(x14)  // Load byte from address x14 + 0 into x13 (unsigned, value depends on memory content)
        // #(CLK_PERIOD) $display("Sending lbu x15, -4(x1)");
        // mem_instr[412] = 32'hffc0c783;  // lbu x15, -4(x1)  // Load byte from address x1 - 4 into x15 (unsigned, value depends on memory content)

        // // lhu (Load halfword unsigned)
        // #(CLK_PERIOD) $display("Sending lhu x2, 2(x3)");
        // mem_instr[416] = 32'h0021d103;  // lhu x2, 2(x3)  // Load halfword from address x3 + 2 into x2 (unsigned, value depends on memory content)
        // #(CLK_PERIOD) $display("Sending lhu x4, -8(x5)");
        // mem_instr[420] = 32'hff82d203;  // lhu x4, -8(x5)  // Load halfword from address x5 - 8 into x4 (unsigned, value depends on memory content)



        // // andi (AND immediate)
        // #(CLK_PERIOD) $display("Sending andi x1, x2, 0xF");
        // mem_instr[360] = 32'h00f17093;  // andi x1, x2, 0xF  // x1 = x2 & 0xF = 2
        // #(CLK_PERIOD) $display("Sending andi x3, x4, 0xA");
        // mem_instr[364] = 32'h00a27193;  // andi x3, x4, 0xA  // x3 = x4 & 0xA = 0
        // #(CLK_PERIOD) $display("Sending andi x5, x6, 0xFF");
        // mem_instr[368] = 32'h0ff37293;  // andi x5, x6, 0xFF  // x5 = x6 & 0xFF = 6

        // // ori (OR immediate)
        // #(CLK_PERIOD) $display("Sending ori x1, x2, 0x1");
        // mem_instr[372] = 32'h00116093;  // ori x1, x2, 0x1  // x1 = x2 | 0x1 = 3
        // #(CLK_PERIOD) $display("Sending ori x3, x4, 0xA");
        // mem_instr[376] = 32'h00a26193;  // ori x3, x4, 0xA  // x3 = x4 | 0xA = 14
        // #(CLK_PERIOD) $display("Sending ori x5, x6, 0xFF");
        // mem_instr[380] = 32'h0x0ff36293;  // ori x5, x6, 0xFF  // x5 = x6 | 0xFF = 255


        // // # xori
        // #(CLK_PERIOD) $display("Sending xori x1, x2, 0x2");
        // mem_instr[0] = 32'h00214093;  // xori x1, x2, 0x2  // x1 = x2 ^ 0x2 = 2 ^ 2 = 0
        // #(CLK_PERIOD) $display("Sending xori x3, x4, 0x8");
        // mem_instr[4] = 32'h00824193;  // xori x3, x4, 0x8  // x3 = x4 ^ 0x8 = 4 ^ 8 = 12
        // #(CLK_PERIOD) $display("Sending xori x5, x6, 0xF");
        // mem_instr[8] = 32'h00F34293;  // xori x5, x6, 0xF  // x5 = x6 ^ 0xF = 6 ^ 15 = 9

    //     // # slti
    //     #(CLK_PERIOD) $display("Sending slti x7, x8, 10");
    //     mem_instr[12] = 32'h00A42393;  // slti x7, x8, 10  // x7 = (x8 < 10) ? 1 : 0 = (8 < 10) ? 1 : 0 = 1
    //     #(CLK_PERIOD) $display("Sending slti x9, x10, 20");
    //     mem_instr[16] = 32'h01452493;  // slti x9, x10, 20  // x9 = (x10 < 20) ? 1 : 0 = (10 < 20) ? 1 : 0 = 1
    //     #(CLK_PERIOD) $display("Sending slti x11, x12, 30");
    //     mem_instr[20] = 32'h01E62593;  // slti x11, x12, 30  // x11 = (x12 < 30) ? 1 : 0 = (12 < 30) ? 1 : 0 = 1
    //     #(CLK_PERIOD) $display("Sending slti x11, x12, 10");
    //     mem_instr[24] = 32'h00A62593;  // slti x11, x12, 10  // x11 = (x12 < 10) ? 1 : 0 = (12 < 10) ? 1 : 0 = 0

    //     // # sltiu
    //     #(CLK_PERIOD) $display("Sending sltiu x13, x14, 5");
    //     mem_instr[24] = 32'h00573693;  // sltiu x13, x14, 5  // x13 = (x14 < 5) ? 1 : 0 (unsigned) = (14 < 5) ? 0 = 0
    //     #(CLK_PERIOD) $display("Sending sltiu x15, x1, 15");
    //     mem_instr[28] = 32'h00F0B793;  // sltiu x15, x1, 15  // x15 = (x1 < 15) ? 1 : 0 (unsigned) = (1 < 15) ? 1 = 1
    //     #(CLK_PERIOD) $display("Sending sltiu x2, x3, 25");
    //     mem_instr[32] = 32'h0191B113;  // sltiu x2, x3, 25  // x2 = (x3 < 25) ? 1 : 0 (unsigned) = (3 < 25) ? 1 = 1

    //     // # slli
    //     #(CLK_PERIOD) $display("Sending slli x1, x2, 1");
    //     mem_instr[36] = 32'h00111093;  // slli x1, x2, 1  // x1 = x2 << 1 = 2 << 1 = 4
    //     #(CLK_PERIOD) $display("Sending slli x3, x4, 2");
    //     mem_instr[40] = 32'h00221193;  // slli x3, x4, 2  // x3 = x4 << 2 = 4 << 2 = 16
    //     #(CLK_PERIOD) $display("Sending slli x5, x6, 3");
    //     mem_instr[44] = 32'h00331293;  // slli x5, x6, 3  // x5 = x6 << 3 = 6 << 3 = 48

    //     // # srli
    //     #(CLK_PERIOD) $display("Sending srli x7, x8, 1");
    //     mem_instr[48] = 32'h00145393;  // srli x7, x8, 1  // x7 = x8 >> 1 = 8 >> 1 = 4
    //     #(CLK_PERIOD) $display("Sending srli x9, x10, 2");
    //     mem_instr[52] = 32'h00255493;  // srli x9, x10, 2  // x9 = x10 >> 2 = 10 >> 2 = 2
    //     #(CLK_PERIOD) $display("Sending srli x11, x12, 3");
    //     mem_instr[56] = 32'h00365593;  // srli x11, x12, 3  // x11 = x12 >> 3 = 12 >> 3 = 1

    //     // # srai
    //     #(CLK_PERIOD) $display("Sending srai x13, x14, 1");
    //     mem_instr[60] = 32'h40175693;  // srai x13, x14, 1  // x13 = x14 >> 1 (arithmetic) = 14 >> 1 = 7
    //     #(CLK_PERIOD) $display("Sending srai x15, x1, 2");
    //     mem_instr[64] = 32'h4020d793;  // srai x15, x1, 2  // x15 = x1 >> 2 (arithmetic) = 1 >> 2 = 0
    //     #(CLK_PERIOD) $display("Sending srai x2, x3, 3");
    //     mem_instr[68] = 32'h4031d113;  // srai x2, x3, 3  // x2 = x3 >> 3 (arithmetic) = 3 >> 3 = 0


    //     // # R-Type Instructions

    //     // # add
    //     #(CLK_PERIOD) $display("Sending add x1, x2, x3");
    //     mem_instr[72] = 32'h003100B3;  // add x1, x2, x3  // x1 = x2 + x3 = 2 + 3 = 5
    //     #(CLK_PERIOD) $display("Sending add x4, x5, x6");
    //     mem_instr[76] = 32'h00628233;  // add x4, x5, x6  // x4 = x5 + x6 = 5 + 6 = 11
    //     #(CLK_PERIOD) $display("Sending add x7, x8, x9");
    //     mem_instr[80] = 32'h009403B3;  // add x7, x8, x9  // x7 = x8 + x9 = 8 + 9 = 17

    //     // # sub
    //     #(CLK_PERIOD) $display("Sending sub x1, x2, x3");
    //     mem_instr[84] = 32'h403100B3;  // sub x1, x2, x3  // x1 = x2 - x3 = 2 - 3 = -1
    //     #(CLK_PERIOD) $display("Sending sub x4, x5, x6");
    //     mem_instr[88] = 32'h40628233;  // sub x4, x5, x6  // x4 = x5 - x6 = 4 - 6 = -1
    //     #(CLK_PERIOD) $display("Sending sub x7, x8, x9");
    //     mem_instr[92] = 32'h409403B3;  // sub x7, x8, x9  // x7 = x8 - x9 = 8 - 9 = -1

    //     // # sll
    //     #(CLK_PERIOD) $display("Sending sll x1, x2, x3");
    //     mem_instr[96] = 32'h003110B3;  // sll x1, x2, x3  // x1 = x2 << x3 = 2 << 3 = 16
    //     #(CLK_PERIOD) $display("Sending sll x4, x5, x6");
    //     mem_instr[100] = 32'h00629233;  // sll x4, x5, x6  // x4 = x5 << x6 = 5 << 6 = 320
    //     #(CLK_PERIOD) $display("Sending sll x7, x8, x9");
    //     mem_instr[104] = 32'h009413B3;  // sll x7, x8, x9  // x7 = x8 << x9 = 8 << 9 = 4096

    //    // # slt
    //     #(CLK_PERIOD) $display("Sending slt x1, x2, x3"); // *
    //     mem_instr[108] = 32'h003120B3;  // slt x1, x2, x3  // x1 = (x2 < x3) ? 1 : 0 = (2 < 3) ? 1 = 1
    //     #(CLK_PERIOD) $display("Sending slt x4, x5, x6");
    //     mem_instr[112] = 32'h0062A233;  // slt x4, x5, x6  // x4 = (x5 < x6) ? 1 : 0 = (4 < 6) ? 1 = 1
    //     #(CLK_PERIOD) $display("Sending slt x7, x8, x9");
    //     mem_instr[116] = 32'h009423B3;  // slt x7, x8, x9  // x7 = (x8 < x9) ? 1 : 0 = (8 < 9) ? 1 = 1

    //     # sltu
    //     #(CLK_PERIOD) $display("Sending sltu x1, x2, x3"); // *
    //     mem_instr[120] = 32'h003130B3;  // sltu x1, x2, x3  // x1 = (x2 < x3) ? 1 : 0 (unsigned) = (2 < 3) ? 1 = 1
    //     #(CLK_PERIOD) $display("Sending sltu x4, x5, x6");
    //     mem_instr[124] = 32'h0062B233;  // sltu x4, x5, x6  // x4 = (x5 < x6) ? 1 : 0 (unsigned) = (4 < 6) ? 1 = 1
    //     #(CLK_PERIOD) $display("Sending sltu x7, x8, x9");
    //     mem_instr[128] = 32'h009433B3;  // sltu x7, x8, x9  // x7 = (x8 < x9) ? 1 : 0 (unsigned) = (8 < 9) ? 1 = 1

    //     // # xor
    //     #(CLK_PERIOD) $display("Sending xor x1, x2, x3");
    //     mem_instr[132] = 32'h003140B3;  // xor x1, x2, x3  // x1 = x2 ^ x3 = 2 ^ 3 = 1
    //     #(CLK_PERIOD) $display("Sending xor x4, x5, x6");
    //     mem_instr[136] = 32'h0062C233;  // xor x4, x5, x6  // x4 = x5 ^ x6 = 4 ^ 6 = 3
    //     #(CLK_PERIOD) $display("Sending xor x7, x8, x9");
    //     mem_instr[140] = 32'h009443B3;  // xor x7, x8, x9  // x7 = x8 ^ x9 = 8 ^ 9 = 1

    //     // # srl
    //     #(CLK_PERIOD) $display("Sending srl x1, x2, x3");
    //     mem_instr[144] = 32'h003150B3;  // srl x1, x2, x3  // x1 = x2 >> x3 = 2 >> 3 = 0
    //     #(CLK_PERIOD) $display("Sending srl x4, x5, x6");
    //     mem_instr[148] = 32'h062D233;   // srl x4, x5, x6  // x4 = x5 >> x6 = 4 >> 6 = 0
    //     #(CLK_PERIOD) $display("Sending srl x7, x8, x9");
    //     mem_instr[152] = 32'h009453B3;  // srl x7, x8, x9  // x7 = x8 >> x9 = 8 >> 9 = 0

    //     // # sra
    //     #(CLK_PERIOD) $display("Sending sra x1, x2, x3");
    //     mem_instr[156] = 32'h403150B3;  // sra x1, x2, x3  // x1 = x2 >> x3 (arithmetic) = 2 >> 3 = 0
    //     #(CLK_PERIOD) $display("Sending sra x4, x5, x6");
    //     mem_instr[160] = 32'h4062D233;  // sra x4, x5, x6  // x4 = x5 >> x6 (arithmetic) = 4 >> 6 = 0
    //     #(CLK_PERIOD) $display("Sending sra x7, x8, x9");
    //     mem_instr[164] = 32'h409453B3;  // sra x7, x8, x9  // x7 = x8 >> x9 (arithmetic) = 8 >> 9 = 0

    //     // # or
    //     #(CLK_PERIOD) $display("Sending or x1, x2, x3");
    //     mem_instr[168] = 32'h003160B3;  // or x1, x2, x3  // x1 = x2 | x3 = 2 --> = 3
    //     #(CLK_PERIOD) $display("Sending or x4, x5, x6");
    //     mem_instr[172] = 32'h0062E233;  // or x4, x5, x6  // x5 = 5 | x6 = 6  --> = 7
    //     #(CLK_PERIOD) $display("Sending or x7, x8, x9");
    //     mem_instr[176] = 32'h009463B3;  // or x7, x8, x9  // x7 = x8 | x9 = 8 --> = 9

    //     // # and
    //     #(CLK_PERIOD) $display("Sending and x1, x2, x3");
    //     mem_instr[180] = 32'h003170B3;  // and x1, x2, x3  // x1 = x2 & x3 = 2 & 3 = 2
    //     #(CLK_PERIOD) $display("Sending and x4, x5, x6");
    //     mem_instr[184] = 32'h0062F233;  // and x4, x5, x6  // x4 = x5 & x6 = 4 & 6 = 4
    //     #(CLK_PERIOD) $display("Sending and x7, x8, x9");
    //     mem_instr[188] = 32'h009473B3;  // and x7, x8, x9  // x7 = x8 & x9 = 8 & 9 = 8

    //     // # S-Type Instructions

    //     // # sb
    //     #(CLK_PERIOD) $display("Sending sb x1, 0(x1)");
    //     mem_instr[192] = 32'h00108023;  // sb x1, 0(x1)  // Store byte from x1 to memory at address x1 + 0: mem[1] = 1
    //     #(CLK_PERIOD) $display("Sending sb x2, 1(x1)");
    //     mem_instr[196] = 32'h002080A3;  // sb x2, 1(x1)  // Store byte from x2 to memory at address x1 + 1: mem[2] = 2
    //     #(CLK_PERIOD) $display("Sending sb x3, 2(x1)");
    //     mem_instr[200] = 32'h00308123;  // sb x3, 2(x1)  // Store byte from x3 to memory at address x1 + 2: mem[3] = 3
    //     #(CLK_PERIOD) $display("Sending sb x3, -2(x1)");
    //     mem_instr[204] = 32'hfe308f23;  // sb x3, -2(x1)  // Store byte from x3 to memory at address x1 + 2: mem[-1] = 3
    //     // NOP instruction
    //     #(CLK_PERIOD);
    //     for (inst = 0; inst < 50; inst=inst+1) begin
    //         $display("Sending add x0, x0, x0");
    //         mem_instr[inst*4 + 208] = 32'h00000033;  // NOP add x0, x0, x0
    //     end

    //     // # sh
    //     #(CLK_PERIOD) $display("Sending sh x1, 0(x1)");
    //     mem_instr[208] = 32'h00109023;  // sh x1, 0(x1)  // Store halfword from x1 to memory at address x1 + 0: mem[1] = 1
    //     #(CLK_PERIOD) $display("Sending sh x2, 2(x1)");
    //     mem_instr[212] = 32'h00209123;  // sh x2, 2(x1)  // Store halfword from x2 to memory at address x1 + 2: mem[3] = 2
    //     #(CLK_PERIOD) $display("Sending sh x3, 4(x1)");
    //     mem_instr[216] = 32'h00309223;  // sh x3, 4(x1)  // Store halfword from x3 to memory at address x1 + 4: mem[5] = 3
    //     // NOP instruction
    //     #(CLK_PERIOD);
    //     for (inst = 0; inst < 50; inst=inst+1) begin
    //         $display("Sending add x0, x0, x0");
    //         mem_instr[inst*4 + 220] = 32'h00000033;  // NOP add x0, x0, x0
    //     end

    //     // # sw
    //     #(CLK_PERIOD) $display("Sending sw x1, 0(x1)");
    //     mem_instr[220] = 32'h0010A023;  // sw x1, 0(x1)  // Store word from x1 to memory at address x1 + 0: mem[1] = 1
    //     #(CLK_PERIOD) $display("Sending sw x2, 2(x1)");
    //     mem_instr[224] = 32'h0020A123;  // sw x2, 4(x1)  // Store word from x2 to memory at address x1 + 4: mem[3] = 2
    //     #(CLK_PERIOD) $display("Sending sw x3, 8(x1)");
    //     mem_instr[228] = 32'h0030A423;  // sw x3, 8(x1)  // Store word from x3 to memory at address x1 + 8: mem[9] = 3
    //     // NOP instruction
    //     #(CLK_PERIOD);
    //     for (inst = 3; inst < 50; inst=inst+1) begin
    //         $display("Sending add x0, x0, x0");
    //         mem_instr[inst*4 + 232] = 32'h00000033;  // NOP add x0, x0, x0
    //     end


    //     // # B-Type Instructions

    //     // # beq
    //     mem_instr[232] = 32'h00000033;  // NOP add x0, x0, x0
    //     // mem_instr[0] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
    //     #(CLK_PERIOD) $display("Sending beq x3, x4, -4");
    //     mem_instr[236] = 32'hFE418EE3;  // Branch if x3 == x4 to PC - 4: false
    //     #(CLK_PERIOD) $display("Sending beq x5, x6, 12");
    //     mem_instr[240] = 32'h00628663;  // beq x5, x6, 12  // Branch if x5 == x6 to PC + 12: false
    //     #(CLK_PERIOD) $display("Sending beq x2, x2, 35");
    //     mem_instr[244] = 32'h02210163;  // Branch if x2 == x2 to PC + 35  = 12 + 35(100011) -> 34(100010) imm_ext -> 33(10000) next_pc = 244+ 33 = 276 (100010100): true
    //     mem_instr[276] = 32'h00210133;  // add x2, x2, x2 // x2 = 4

    //     // # bne
    //     #(CLK_PERIOD) $display("Sending bne x2, x2, 40");
    //     mem_instr[280] = 32'h02211463;  // bne x1, x2, 40  // Branch if x1 != x2 to PC + 40: false
    //     #(CLK_PERIOD) $display("Sending bne x3, x4, -4");
    //     mem_instr[284] = 32'hFE419EE3;  // bne x3, x4, -4  // Branch if x3 != x4 to PC - 4: true
    //     #(CLK_PERIOD) $display("Sending bne x5, x6, 12");
    //     mem_instr[288] = 32'h00629663;  // bne x5, x6, 12  // Branch if x5 != x6 to PC + 12: true (but it won't execute completely if you execute the previous instruction before, it will execute partially then will receive aflush from hazard unit because this is a control hazard)
    //     mem_instr[320   ] = 32'h00210133;  // add x2, x2, x2 // x2 = 4

    //     // # blt 
    //     #(CLK_PERIOD) $display("Sending blt x1, x2, 40");
    //     mem_instr[252] = 32'h0220c463;  // blt x1, x2, 8  // Branch if x1 < x2 to PC + 8: true
    //     #(CLK_PERIOD) $display("Sending blt x3, x4, -4");
    //     mem_instr[256] = 32'hFE41CEE3;  // blt x3, x4, -4  // Branch if x3 < x4 to PC - 4: true
    //     #(CLK_PERIOD) $display("Sending blt x5, x6, 12");
    //     mem_instr[260] = 32'h0062C663;  // blt x5, x6, 12  // Branch if x5 < x6 to PC + 12: true
    //     mem_instr[292] = 32'h00210133;  // add x2, x2, x2 // x2 = 4

    //     // # bge
    //     mem_instr[264] = 32'h003181b3;  // add x3, x3, x3 // x3 = 6
    //     mem_instr[268] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
    //     mem_instr[272] = 32'h001080b3;  // add x1, x1, x1 // x1 = 2
    //     // #(CLK_PERIOD) $display("Sending bge x1, x2, 8");
    //     // mem_instr[0] = 32'h0020D463;  // bge x1, x2, 8  // Branch if x1 >= x2 to PC + 8: false
    //     #(CLK_PERIOD) $display("Sending bge x5, x4, -4");
    //     mem_instr[276] = 32'hFE42DEE3;  // bge x5, x4, -4  // Branch if x5 >= x4 to PC - 4: true
    //     #(CLK_PERIOD) $display("Sending bge add x5, x5, x5"); 
    //     mem_instr[280] = 32'h005282b3;  // add x5, x5, x5 // x5 = 10 // shouldn't execute completely due to previous branch
    //     #(CLK_PERIOD) $display("Sending bge x6, x6, 40");
    //     mem_instr[284] = 32'h02635463;  // bge x6, x6, 40  // Branch if x6 >= x6 to PC + 12: true

    //     // # bltu
    //     #(CLK_PERIOD) $display("Sending addi x1, x1, -2048");
    //     mem_instr[288] = 32'h80008093; // x1 = -2047 (11111111111111111111100000000001)
    //     #(CLK_PERIOD) $display("Sending bltu x1, x2, 8");
    //     mem_instr[292] = 32'h0020E463;  // bltu x1, x2, 8  // Branch if x1 < x2 (unsigned) to PC + 8 // -2047 -> 4294965249 < 2 = false
    //     #(CLK_PERIOD) $display("Sending bltu x3, x4, -4");
    //     mem_instr[296] = 32'hFE41EEE3;  // bltu x3, x4, -4  // Branch if x3 < x4 (unsigned) to PC - 4 = true
    //     #(CLK_PERIOD) $display("Sending bltu x5, x6, 12");
    //     mem_instr[300] = 32'h0062E663;  // bltu x5, x6, 12  // Branch if x5 < x6 (unsigned) to PC + 12

    //     # bgeu
    //     #(CLK_PERIOD) $display("Sending bgeu x1, x2, 16");
    //     mem_instr[304] = 32'h0020f863;  // bgeu x1, x2, 16  // Branch if x1 >= x2 (unsigned) to PC + 16: false
    //     #(CLK_PERIOD) $display("Sending bgeu x1, x6, 12");
    //     mem_instr[308] = 32'h0060f663;  // bgeu x1, x6, 12  // Branch if x1 >= x6 (unsigned) to PC + 12: false
    //     mem_instr[312] = 32'h80008093; // addi x1, x1, -2048 // x1 = -2047 (11111111111111111111100000000001)
    //     #(CLK_PERIOD) $display("Sending bgeu x4, x4, -4");
    //     mem_instr[316] = 32'hFE427EE3;  // bgeu x3, x4, -4  // Branch if x3 >= x4 (unsigned) to PC - 4: true
    //     mem_instr[320] = 32'h00210133;  // add x2, x2, x2 // x2 = 4 // testing if hazard is flushing this instruction
        

    //     // # U-Type Instructions

    //     // # lui
    //     #(CLK_PERIOD) $display("Sending lui x1, 0x12345");
    //     mem_instr[324] = 32'h123450B7;  // lui x1, 0x12345  // x1 = 0x12345000 (305418240₁₀)
    //     #(CLK_PERIOD) $display("Sending lui x2, 0x23456");
    //     mem_instr[328] = 32'h23456137;  // lui x2, 0x23456  // x2 = 0x23456000 (591749120₁₀)
    //     #(CLK_PERIOD) $display("Sending lui x3, 0x34567");
    //     mem_instr[332] = 32'h345671B7;  // lui x3, 0x34567  // x3 = 0x34567000 (878080000₁₀)

    //     // # auipc
    //     #(CLK_PERIOD) $display("Sending auipc x4, 0x45678"); // PC = 336 = 0x150
    //     mem_instr[336] = 32'h45678217;  // auipc x4, 0x45678  // x4 = PC + 0x45678000: x4 = 0x45678150
    //     #(CLK_PERIOD) $display("Sending auipc x5, 0x56789"); // PC = 336 = 0x154
    //     mem_instr[340] = 32'h56789297;  // auipc x5, 0x56789  // x5 = PC + 0x56789000: x5 = 0x56789154
    //     #(CLK_PERIOD) $display("Sending auipc x6, 0x67890"); // PC = 336 = 0x158
    //     mem_instr[344] = 32'h67890317;  // auipc x6, 0x67890  // x6 = PC + 0x67890000: x6 = 0x67890158

    //     // # J-Type Instructions
    //     // # jal
    //     #(CLK_PERIOD) $display("Sending jal x1, 32");
    //     mem_instr[348] = 32'h020000EF;  // jal x1, 32  // Jump to PC + 32, x1 = return address
    //     #(CLK_PERIOD) $display("Sending jal x2, -16");
    //     mem_instr[352] = 32'hFF1FF16F;  // jal x2, -16  // Jump to PC - 16, x2 = return address
    //     #(CLK_PERIOD) $display("Sending jal x3, 64");
    //     mem_instr[356] = 32'h040001EF;  // jal x3, 64  // Jump to PC + 64, x3 = return address

        // # exit
    end
    endtask //automatic
        
endmodule
