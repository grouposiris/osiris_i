`timescale 1ns / 1ps

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
                        $display("Time %0t ps: Register[%0d] changed to %h", $time, i, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]);
                        $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | Register[%0d] changed to %h", cycle_counter, i, dut.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[i]);
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
                $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | [Program Counter] changed to %h", cycle_counter, core_pc_IF);
            end

        // Monitor changes in the Instruction Register
            always @(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID) begin
                $display("Time %0t ps: i_instr_ID changed to %h, Assembly: %s", $time, dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
                $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | [Instruction Register] changed to %h, Assembly: %s", cycle_counter, dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
            end

        // Main Test Sequence
            initial begin
                // Run some simple test instructions
                // @(negedge rst_core);
                //display_registers();  // Dump registers after reset

                // Seting up the testbench
                // Open the file to store the state of osiris core
                f_osiris_core_state_dump = $fopen("osiris_core_state.dump", "w");
                if (!f_osiris_core_state_dump) begin
                    $display("[Error] - Failed to open the file: osiris_core_state.dump");
                end

                $display("---------------------------------------");
                $display("Initializing memories with zeroes...");
                $display("---------------------------------------");
                for (int i = 0; i < DATA_WIDTH; i++) begin
                    mem_instr[i] = {DATA_WIDTH{1'b0}};
                    mem_data[i] = {DATA_WIDTH{1'b0}};
                end
                // mem_instr[0] = 32'h00000093;  // Example: addi x1, x0, 0 (loads 0 into x1)
                // mem_instr[4] = 32'h00100113;  // Example: addi x2, x0, 1 (loads 1 into x2)
                // mem_instr[8] = 32'h00202023;  // Example: sw x2 0(x0)    (store x2 into mem_data[4])
                // mem_instr[8] = 32'h002020a3;  // Example: sw x2 4(x0)    (store x2 into mem_data[4])
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
                
                // # I-Type Instructions

                // # xori
                #(CLK_PERIOD) $display("Sending xori x1, x2, 0x2");
                mem_instr[0] = 32'h00214093;  // xori x1, x2, 0x2
                #(CLK_PERIOD) $display("Sending xori x3, x4, 0x8");
                mem_instr[4] = 32'h00824193;  // xori x3, x4, 0x8
                #(CLK_PERIOD) $display("Sending xori x5, x6, 0xF");
                mem_instr[8] = 32'h00F34293;  // xori x5, x6, 0xF

                // # slti
                #(CLK_PERIOD) $display("Sending slti x7, x8, 10");
                mem_instr[12] = 32'h00A42393;  // slti x7, x8, 10
                #(CLK_PERIOD) $display("Sending slti x9, x10, 20");
                mem_instr[16] = 32'h01452493;  // slti x9, x10, 20
                #(CLK_PERIOD) $display("Sending slti x11, x12, 30");
                mem_instr[20] = 32'h01E62593;  // slti x11, x12, 30

                // # sltiu
                #(CLK_PERIOD) $display("Sending sltiu x13, x14, 5");
                mem_instr[24] = 32'h00573693;  // sltiu x13, x14, 5
                #(CLK_PERIOD) $display("Sending sltiu x15, x1, 15");
                mem_instr[28] = 32'h00F0B793;  // sltiu x15, x1, 15
                #(CLK_PERIOD) $display("Sending sltiu x2, x3, 25");
                mem_instr[32] = 32'h0191B113;  // sltiu x2, x3, 25

                // # slli
                #(CLK_PERIOD) $display("Sending slli x1, x2, 1");
                mem_instr[36] = 32'h00111093;  // slli x1, x2, 1
                #(CLK_PERIOD) $display("Sending slli x3, x4, 2");
                mem_instr[40] = 32'h00221193;  // slli x3, x4, 2
                #(CLK_PERIOD) $display("Sending slli x5, x6, 3");
                mem_instr[44] = 32'h00331293;  // slli x5, x6, 3

                // # srli
                #(CLK_PERIOD) $display("Sending srli x7, x8, 1");
                mem_instr[48] = 32'h0013D413;  // srli x7, x8, 1
                #(CLK_PERIOD) $display("Sending srli x9, x10, 2");
                mem_instr[52] = 32'h00255493;  // srli x9, x10, 2
                #(CLK_PERIOD) $display("Sending srli x11, x12, 3");
                mem_instr[56] = 32'h001B2D93;  // srli x11, x12, 3

                // # srai
                #(CLK_PERIOD) $display("Sending srai x13, x14, 1");
                mem_instr[60] = 32'h00175693;  // srai x13, x14, 1
                #(CLK_PERIOD) $display("Sending srai x15, x1, 2");
                mem_instr[64] = 32'h0027D093;  // srai x15, x1, 2
                #(CLK_PERIOD) $display("Sending srai x2, x3, 3");
                mem_instr[68] = 32'h0031D113;  // srai x2, x3, 3

                // # R-Type Instructions

                // # add
                #(CLK_PERIOD) $display("Sending add x1, x2, x3");
                mem_instr[72] = 32'h003100B3;  // add x1, x2, x3
                #(CLK_PERIOD) $display("Sending add x4, x5, x6");
                mem_instr[76] = 32'h00628233;  // add x4, x5, x6
                #(CLK_PERIOD) $display("Sending add x7, x8, x9");
                mem_instr[80] = 32'h009403B3;  // add x7, x8, x9

                // # sub
                #(CLK_PERIOD) $display("Sending sub x1, x2, x3");
                mem_instr[84] = 32'h403100B3;  // sub x1, x2, x3
                #(CLK_PERIOD) $display("Sending sub x4, x5, x6");
                mem_instr[88] = 32'h40628233;  // sub x4, x5, x6
                #(CLK_PERIOD) $display("Sending sub x7, x8, x9");
                mem_instr[92] = 32'h409403B3;  // sub x7, x8, x9

                // # sll
                #(CLK_PERIOD) $display("Sending sll x1, x2, x3");
                mem_instr[96] = 32'h003110B3;  // sll x1, x2, x3
                #(CLK_PERIOD) $display("Sending sll x4, x5, x6");
                mem_instr[100] = 32'h00629233;  // sll x4, x5, x6
                #(CLK_PERIOD) $display("Sending sll x7, x8, x9");
                mem_instr[104] = 32'h009413B3;  // sll x7, x8, x9

                // # slt
                #(CLK_PERIOD) $display("Sending slt x1, x2, x3");
                mem_instr[108] = 32'h003120B3;  // slt x1, x2, x3
                #(CLK_PERIOD) $display("Sending slt x4, x5, x6");
                mem_instr[112] = 32'h0062A233;  // slt x4, x5, x6
                #(CLK_PERIOD) $display("Sending slt x7, x8, x9");
                mem_instr[116] = 32'h009423B3;  // slt x7, x8, x9

                // # sltu
                #(CLK_PERIOD) $display("Sending sltu x1, x2, x3");
                mem_instr[120] = 32'h003130B3;  // sltu x1, x2, x3
                #(CLK_PERIOD) $display("Sending sltu x4, x5, x6");
                mem_instr[124] = 32'h0062B233;  // sltu x4, x5, x6
                #(CLK_PERIOD) $display("Sending sltu x7, x8, x9");
                mem_instr[128] = 32'h009433B3;  // sltu x7, x8, x9

                // # xor
                #(CLK_PERIOD) $display("Sending xor x1, x2, x3");
                mem_instr[132] = 32'h003140B3;  // xor x1, x2, x3
                #(CLK_PERIOD) $display("Sending xor x4, x5, x6");
                mem_instr[136] = 32'h0062C233;  // xor x4, x5, x6
                #(CLK_PERIOD) $display("Sending xor x7, x8, x9");
                mem_instr[140] = 32'h009443B3;  // xor x7, x8, x9

                // # srl
                #(CLK_PERIOD) $display("Sending srl x1, x2, x3");
                mem_instr[144] = 32'h003150B3;  // srl x1, x2, x3
                #(CLK_PERIOD) $display("Sending srl x4, x5, x6");
                mem_instr[148] = 32'h062D233;   // srl x4, x5, x6
                #(CLK_PERIOD) $display("Sending srl x7, x8, x9");
                mem_instr[152] = 32'h009453B3;  // srl x7, x8, x9

                // # sra
                #(CLK_PERIOD) $display("Sending sra x1, x2, x3");
                mem_instr[156] = 32'h403150B3;  // sra x1, x2, x3
                #(CLK_PERIOD) $display("Sending sra x4, x5, x6");
                mem_instr[160] = 32'h4062D233;  // sra x4, x5, x6
                #(CLK_PERIOD) $display("Sending sra x7, x8, x9");
                mem_instr[164] = 32'h409453B3;  // sra x7, x8, x9

                // # or
                #(CLK_PERIOD) $display("Sending or x1, x2, x3");
                mem_instr[168] = 32'h003160B3;  // or x1, x2, x3
                #(CLK_PERIOD) $display("Sending or x4, x5, x6");
                mem_instr[172] = 32'h0062E233;  // or x4, x5, x6
                #(CLK_PERIOD) $display("Sending or x7, x8, x9");
                mem_instr[176] = 32'h009463B3;  // or x7, x8, x9

                // # and
                #(CLK_PERIOD) $display("Sending and x1, x2, x3");
                mem_instr[180] = 32'h003170B3;  // and x1, x2, x3
                #(CLK_PERIOD) $display("Sending and x4, x5, x6");
                mem_instr[184] = 32'h0062F233;  // and x4, x5, x6
                #(CLK_PERIOD) $display("Sending and x7, x8, x9");
                mem_instr[188] = 32'h009473B3;  // and x7, x8, x9


                // # S-Type Instructions
                // # sb
                #(CLK_PERIOD) $display("Sending sb x1, 0(x1)");
                mem_instr[192] = 32'h00109023;  // sb x1, 0(x1)
                #(CLK_PERIOD) $display("Sending sb x2, 1(x1)");
                mem_instr[196] = 32'h002090A3;  // sb x2, 1(x1)
                #(CLK_PERIOD) $display("Sending sb x3, 2(x1)");
                mem_instr[200] = 32'h00309123;  // sb x3, 2(x1)

                // # sh
                #(CLK_PERIOD) $display("Sending sh x1, 0(x1)");
                mem_instr[204] = 32'h00109023;  // sh x1, 0(x1)
                #(CLK_PERIOD) $display("Sending sh x2, 2(x1)");
                mem_instr[208] = 32'h00209123;  // sh x2, 2(x1)
                #(CLK_PERIOD) $display("Sending sh x3, 4(x1)");
                mem_instr[212] = 32'h00309223;  // sh x3, 4(x1)

                // # sw
                #(CLK_PERIOD) $display("Sending sw x1, 0(x1)");
                mem_instr[216] = 32'h0010A023;  // sw x1, 0(x1)
                #(CLK_PERIOD) $display("Sending sw x2, 4(x1)");
                mem_instr[220] = 32'h0020A223;  // sw x2, 4(x1)
                #(CLK_PERIOD) $display("Sending sw x3, 8(x1)");
                mem_instr[224] = 32'h0030A423;  // sw x3, 8(x1)


                // # B-Type Instructions
                // # beq
                #(CLK_PERIOD) $display("Sending beq x1, x2, 8");
                mem_instr[228] = 32'h00208463;  // beq x1, x2, 8
                #(CLK_PERIOD) $display("Sending beq x3, x4, -4");
                mem_instr[232] = 32'hFE418EE3;  // beq x3, x4, -4
                #(CLK_PERIOD) $display("Sending beq x5, x6, 12");
                mem_instr[236] = 32'h00628663;  // beq x5, x6, 12

                // # bne
                #(CLK_PERIOD) $display("Sending bne x1, x2, 8");
                mem_instr[240] = 32'h00209463;  // bne x1, x2, 8
                #(CLK_PERIOD) $display("Sending bne x3, x4, -4");
                mem_instr[244] = 32'hFE419EE3;  // bne x3, x4, -4
                #(CLK_PERIOD) $display("Sending bne x5, x6, 12");
                mem_instr[248] = 32'h00629663;  // bne x5, x6, 12

                // # blt
                #(CLK_PERIOD) $display("Sending blt x1, x2, 8");
                mem_instr[252] = 32'h0020C463;  // blt x1, x2, 8
                #(CLK_PERIOD) $display("Sending blt x3, x4, -4");
                mem_instr[256] = 32'hFE41CEE3;  // blt x3, x4, -4
                #(CLK_PERIOD) $display("Sending blt x5, x6, 12");
                mem_instr[260] = 32'h0062C663;  // blt x5, x6, 12

                // # bge
                #(CLK_PERIOD) $display("Sending bge x1, x2, 8");
                mem_instr[264] = 32'h0020D463;  // bge x1, x2, 8
                #(CLK_PERIOD) $display("Sending bge x3, x4, -4");
                mem_instr[268] = 32'hFE41DEE3;  // bge x3, x4, -4
                #(CLK_PERIOD) $display("Sending bge x5, x6, 12");
                mem_instr[272] = 32'h0062D663;  // bge x5, x6, 12

                // # bltu
                #(CLK_PERIOD) $display("Sending bltu x1, x2, 8");
                mem_instr[276] = 32'h0020E463;  // bltu x1, x2, 8
                #(CLK_PERIOD) $display("Sending bltu x3, x4, -4");
                mem_instr[280] = 32'hFE41EEE3;  // bltu x3, x4, -4
                #(CLK_PERIOD) $display("Sending bltu x5, x6, 12");
                mem_instr[284] = 32'h0062E663;  // bltu x5, x6, 12

                // # bgeu
                #(CLK_PERIOD) $display("Sending bgeu x1, x2, 8");
                mem_instr[288] = 32'h0020F463;  // bgeu x1, x2, 8
                #(CLK_PERIOD) $display("Sending bgeu x3, x4, -4");
                mem_instr[292] = 32'hFE41FEE3;  // bgeu x3, x4, -4
                #(CLK_PERIOD) $display("Sending bgeu x5, x6, 12");
                mem_instr[296] = 32'h0062F663;  // bgeu x5, x6, 12


                // # U-Type Instructions
                // # lui
                #(CLK_PERIOD) $display("Sending lui x1, 0x12345");
                mem_instr[300] = 32'h123450B7;  // lui x1, 0x12345
                #(CLK_PERIOD) $display("Sending lui x2, 0x23456");
                mem_instr[304] = 32'h23456137;  // lui x2, 0x23456
                #(CLK_PERIOD) $display("Sending lui x3, 0x34567");
                mem_instr[308] = 32'h345671B7;  // lui x3, 0x34567

                // # auipc
                #(CLK_PERIOD) $display("Sending auipc x4, 0x45678");
                mem_instr[312] = 32'h45678217;  // auipc x4, 0x45678
                #(CLK_PERIOD) $display("Sending auipc x5, 0x56789");
                mem_instr[316] = 32'h56789297;  // auipc x5, 0x56789
                #(CLK_PERIOD) $display("Sending auipc x6, 0x67890");
                mem_instr[320] = 32'h67890317;  // auipc x6, 0x67890


                // # J-Type Instructions
                // # jal
                #(CLK_PERIOD) $display("Sending jal x1, 32");
                mem_instr[324] = 32'h020000EF;  // jal x1, 32
                #(CLK_PERIOD) $display("Sending jal x2, -16");
                mem_instr[328] = 32'hFF1FF16F;  // jal x2, -16
                #(CLK_PERIOD) $display("Sending jal x3, 64");
                mem_instr[332] = 32'h040001EF;  // jal x3, 64

                // # exit


                // 202223:
                // immd_U	rs2	    rs1	    funct3	imm_L	opcode
                // 0000000	00010	00000	010	    00100	0100011

                #(20*CLK_PERIOD);

                rst_core = 0;
                $display("---------------------------------------");
                $display("Release reset.");
                $display("---------------------------------------");

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
                    $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | [Data Memory] - Write - Addr = %h, Data = %h", cycle_counter, core_data_addr_M, mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]]);
                    //$display("Time %0t ps: [Data Memory] Write: Addr = %h, Data = %h",$time, core_data_addr_M, core_write_data_M);
                end
            end

        // Reads from the memory are asynchronous // looking at mem.v it seems synchronous // the read operation just uses an 'assign', so it is asynchronous
            // Looking at mem.v, always that a change occurs in the 'wb_adr_i', the value of 'wb_dat_o' also changes. Neither one of those values are registered
            always @(*) begin
                if (!core_mem_write_M && !rst_core) begin
                    core_read_data_M <= mem_data[core_data_addr_M[DATA_MEM_ADDR_BITS-1:0]];
                    if (core_data_addr_M != 32'hxxxxxxxx && core_read_data_M != 32'hFFFFFFFF) begin
                        $display("Time %0t ps: [Data Memory] - Read - Addr = %h, Data = %h", $time, core_data_addr_M, core_read_data_M);
                        $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | [Data Memory] - Read - Addr = %h, Data = %h", cycle_counter, core_data_addr_M, core_read_data_M);
                    end
                end else begin
                    core_read_data_M <= {DATA_WIDTH{1'b1}};
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
            
            // Validate registers for RV32E (only x0 to x15 are valid)
            if (rd > 5'd15 || rs1 > 5'd15 || rs2 > 5'd15) begin
                decode_instruction = "INVALID_REGISTER";
                $finish;
            end

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
                        3'b001: begin
                            // Validate shift amount (must be <= 15)
                            if (instr[24:20] > 5'd15) begin
                                decode_instruction = "INVALID_SHIFT_AMOUNT";
                                $finish;
                            end
                            decode_instruction = $sformatf("SLLI x%0d, x%0d, %0d", rd, rs1, instr[24:20]);
                        end
                        3'b101: begin
                            // Validate shift amount (must be <= 15)
                            if (instr[24:20] > 5'd15) begin
                                decode_instruction = "INVALID_SHIFT_AMOUNT";
                                $finish;
                            end
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

        // ------------------------------

        // task encode_instruction_string(input string instr_str, output reg [31:0] encoded_instr);
        //     reg [6:0] opcode;
        //     reg [2:0] funct3;
        //     reg [6:0] funct7;
        //     reg [4:0] rd, rs1, rs2;
        //     reg [31:0] imm;
        //     string mnemonic;
        //     string operands_str;
        //     string operands [0:2];
        //     integer num_operands;
        //     integer idx;

        //     // Helper variables for parsing
        //     string temp_str;
        //     integer pos;

        // begin
        //     // Initialize encoded instruction
        //     encoded_instr = 32'b0;

        //     // Separate mnemonic and operands
        //     pos = instr_str.find(" ");
        //     if (pos == -1) begin
        //         $display("Error: Invalid instruction format.");
        //         return;
        //     end
        //     mnemonic = instr_str.substr(0, pos-1);
        //     operands_str = instr_str.substr(pos+1);

        //     // Split operands
        //     num_operands = 0;
        //     while (operands_str != "") begin
        //         pos = operands_str.find(",");
        //         if (pos == -1) begin
        //             operands[num_operands] = operands_str.strip();
        //             operands_str = "";
        //         end else begin
        //             operands[num_operands] = operands_str.substr(0, pos-1).strip();
        //             operands_str = operands_str.substr(pos+1).strip();
        //         end
        //         num_operands = num_operands + 1;
        //     end

        //     // Parse instruction based on mnemonic
        //     if (mnemonic == "add") begin
        //         // R-Type instruction: add rd, rs1, rs2
        //         if (num_operands != 3) begin
        //             $display("Error: Incorrect number of operands for add.");
        //             return;
        //         end
        //         opcode = 7'b0110011;
        //         funct3 = 3'b000;
        //         funct7 = 7'b0000000;
        //         rd   = parse_register(operands[0]);
        //         rs1  = parse_register(operands[1]);
        //         rs2  = parse_register(operands[2]);
        //         // Construct the instruction
        //         encoded_instr = {funct7, rs2, rs1, funct3, rd, opcode};
        //     end else if (mnemonic == "sw") begin
        //         // S-Type instruction: sw rs2, imm(rs1)
        //         if (num_operands != 2) begin
        //             $display("Error: Incorrect number of operands for sw.");
        //             return;
        //         end
        //         opcode = 7'b0100011;
        //         funct3 = 3'b010;
        //         // Parse rs2
        //         rs2 = parse_register(operands[0]);
        //         // Parse imm(rs1)
        //         parse_imm_register(operands[1], imm, rs1);
        //         // Construct the instruction
        //         encoded_instr = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
        //     end else if (mnemonic == "addi") begin
        //         // I-Type instruction: addi rd, rs1, imm
        //         if (num_operands != 3) begin
        //             $display("Error: Incorrect number of operands for addi.");
        //             return;
        //         end
        //         opcode = 7'b0010011;
        //         funct3 = 3'b000;
        //         funct7 = 7'b0000000;  // Not used in I-Type
        //         rd   = parse_register(operands[0]);
        //         rs1  = parse_register(operands[1]);
        //         imm  = parse_immediate(operands[2]);
        //         // Construct the instruction
        //         encoded_instr = {imm[11:0], rs1, funct3, rd, opcode};
        //     end else begin
        //         $display("Error: Unsupported instruction '%s'.", mnemonic);
        //         return;
        //     end
        // end
        // endtask

        // // Helper function to parse registers
        // function [4:0] parse_register(input string reg_str);
        //     integer reg_num;
        // begin
        //     reg_str = reg_str.strip();
        //     if (reg_str.len() < 2 || reg_str.substr(0,0) != "x") begin
        //         $display("Error: Invalid register '%s'.", reg_str);
        //         parse_register = 5'd0;
        //         return;
        //     end
        //     reg_num = $atoi(reg_str.substr(1));
        //     if (reg_num < 0 || reg_num > 15) begin
        //         $display("Error: Register index out of range for RV32E: x%0d.", reg_num);
        //         parse_register = 5'd0;
        //         return;
        //     end
        //     parse_register = reg_num[4:0];
        // end
        // endfunction

        // // Helper task to parse immediate and register in format imm(rs)
        // task parse_imm_register(input string str, output reg [11:0] imm, output reg [4:0] rs);
        //     string imm_str;
        //     string rs_str;
        //     integer idx1, idx2;
        //     integer imm_val;
        // begin
        //     idx1 = str.find("(");
        //     idx2 = str.find(")");
        //     if (idx1 == -1 || idx2 == -1 || idx2 <= idx1) begin
        //         $display("Error: Invalid format for immediate and register '%s'.", str);
        //         imm = 12'd0;
        //         rs = 5'd0;
        //         return;
        //     end
        //     imm_str = str.substr(0, idx1).strip();
        //     rs_str = str.substr(idx1+1, idx2-idx1-1).strip();
        //     imm_val = $atoi(imm_str);
        //     if (imm_val < -2048 || imm_val > 2047) begin
        //         $display("Error: Immediate value out of range: %0d.", imm_val);
        //         imm = 12'd0;
        //         rs = 5'd0;
        //         return;
        //     end
        //     imm = imm_val[11:0];
        //     rs = parse_register(rs_str);
        // end
        // endtask

        // // Helper function to parse immediate values
        // function [11:0] parse_immediate(input string imm_str);
        //     integer imm_val;
        // begin
        //     imm_str = imm_str.strip();
        //     imm_val = $atoi(imm_str);
        //     if (imm_val < -2048 || imm_val > 2047) begin
        //         $display("Error: Immediate value out of range: %0d.", imm_val);
        //         parse_immediate = 12'd0;
        //         return;
        //     end
        //     parse_immediate = imm_val[11:0];
        // end
        // endfunction


        
endmodule
