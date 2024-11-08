`timescale 1ns / 1ps

module osiris_i_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter INST_MEM_SIZE = 2;  // in KB
    parameter DATA_MEM_SIZE = 2;  // in KB

    localparam INST_MEM_WORDS = (INST_MEM_SIZE * 1024 * 8) / 32; // Inst. Memory has fixed 32 bits (RV32E ISA)
    localparam DATA_MEM_WORDS = (DATA_MEM_SIZE * 1024 * 8 ) / DATA_WIDTH;
    localparam INST_MEM_ADDR_BITS = $clog2(INST_MEM_WORDS);
    localparam DATA_MEM_ADDR_BITS = $clog2(DATA_MEM_WORDS);

    // parameter BAUD_RATE = 9600;
    // parameter CLOCK_FREQ = 50e6;  // 50 MHz clock
    parameter BAUD_RATE = 1e9;
    parameter CLOCK_FREQ = 10e9;  // 50 MHz clock
    parameter CLK_PERIOD = 1e9 / CLOCK_FREQ;  // Clock period in nanoseconds

    // UART Command Values
    localparam CMD_READ = 8'h77;  // Command to read from memory and send data via UART
    localparam CMD_WRITE = 8'hAA;  // Command to write data received via UART to memory

    // Calculate Bit Period Based on Baud Rate
    localparam real BIT_PERIOD = 1e9 / BAUD_RATE;  // Bit period in nanoseconds
    localparam WAIT_BETWEEN_UART_SEND_BYTE = (10 * BIT_PERIOD);
    localparam WAIT_BETWEEN_UART_SEND_CMD = 50;
    localparam WAIT_BETWEEN_STEPS = 200;

    // UART Wishbone Bridge State Encoding (from uart_wbs_bridge)
    localparam STATE_IDLE = 3'd0;
    localparam STATE_READ_ADDR = 3'd2;
    localparam STATE_READ_DATA = 3'd3;
    localparam STATE_WB_WRITE = 3'd4;
    localparam STATE_WB_READ = 3'd5;
    localparam STATE_SEND_DATA = 3'd6;

    // --------------------
    localparam INST_MEM_DEPTH = (INST_MEM_SIZE * 1024 * 8) / 32;
    reg [DATA_WIDTH-1:0] tb_mem[0:INST_MEM_DEPTH - 1];
    
    // localparam DATA_MEM_DEPTH = (DATA_MEM_SIZE * 1024 * 8) / DATA_WIDTH;
    // reg [DATA_WIDTH-1:0] tb_data_mem[0:DATA_MEM_DEPTH - 1];

    // Array to store flags indicating if the value has changed
    reg [DATA_WIDTH-1:0] mem_prev[0:15];  // Array to store previous values
    integer i;
    integer j;

    initial begin
        // Initialize previous values to zero or a known initial value
        for (j = 0; j < 16; j = j + 1) begin
            mem_prev[j] = dut.U_INST_MEM.mem[j];
        end
    end

    // Testbench signals declaration
        // Clock and Reset
        reg  clk;
        reg  rst_core;
        reg  rst_mem_uart;

        // Global signals
        reg  [15:0] cycle_counter = 0;
        integer f_osiris_core_state_dump;

    // UART Signals
    reg  i_uart_rx;
    wire o_uart_tx;

    // Control Signals
    reg  i_start_rx;
    reg  i_select_mem;  // Control signal to select memory: 0 - Instruction Mem, 1 - Data Mem

    // Instantiate the osiris_i module (Device Under Test)
    osiris_i #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .INST_MEM_SIZE(INST_MEM_SIZE),
        .DATA_MEM_SIZE(DATA_MEM_SIZE),
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_FREQ(CLOCK_FREQ),
        .CMD_READ(CMD_READ),
        .CMD_WRITE(CMD_WRITE)
    ) dut (
        .clk         (clk),
        .rst_core    (rst_core),
        .rst_mem_uart(rst_mem_uart),
        .i_uart_rx   (i_uart_rx),
        .o_uart_tx   (o_uart_tx),
        .i_select_mem(i_select_mem),
        .i_start_rx  (i_start_rx)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;  // Toggle clock every half period
    end

    // Reset Sequence
    initial begin
        rst_core = 1;
        rst_mem_uart = 1;
        i_start_rx = 0;
        i_select_mem = 0;
        i_uart_rx = 1;  // UART line idle (high)
        #100;
        // rst_core = 0;
        rst_mem_uart = 0;
        i_start_rx   = 1;  // Enable UART reception
        #200000 $display("finish prevent"); $finish;
    end

    // VCD Dump for Waveform Viewing
    initial begin
        $dumpfile("osiris_i.vcd");
        $dumpvars(0, osiris_i_tb);
    end

    // Test Variables
    //integer i;
    reg test_passed;
    reg [DATA_WIDTH-1:0] read_data;
    reg [DATA_WIDTH-1:0] expected_data;
    reg [ADDR_WIDTH-1:0] test_address;
    reg [DATA_WIDTH-1:0] aux_inst, aux_data; //auxiliary mem reg
    integer step; // tb variable just to simulation organization

    // Arrays to Store Instructions and Expected Results
    reg [DATA_WIDTH-1:0] instruction_mem[0:255];
    reg [DATA_WIDTH-1:0] instruction_addresses[0:255];
    integer num_instructions;

    reg [DATA_WIDTH-1:0] expected_data_array[0:255];
    reg [DATA_WIDTH-1:0] expected_addresses[0:255];
    integer expected_result_count;

    // File for Writing Outputs
    integer output_file;
    integer it;
    integer print = 0;


    // Monitor register changes
        genvar k;
        generate
            for (k = 0; k < 16; k = k + 1) begin : monitor_registers
                always @(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k]) begin
                    $display("      -----> Time %0t ps: Register[x%0d] changed to %d<-  = %b = %h\n\n", $time, k, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k],dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k],dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k]);
                    $fdisplay(f_osiris_core_state_dump, "Clock Cycle: %d | Register[x%0d] changed to %d<-  = %b  = %h\n\n", cycle_counter, k, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k],dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k],dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.U_REGISTER_FILE.registers[k]);
                end
            end
        endgenerate

    // Monitor data memory
        generate
            for (k = 0; k < (DATA_MEM_WORDS); k = k +1) begin
                // always @(dut.U_DATA_MEM.mem[k] or dut.U_DATA_MEM.mem[k+1] or dut.U_DATA_MEM.mem[k+2] or dut.U_DATA_MEM.mem[k+3]) begin
                always @(dut.U_DATA_MEM.mem[k]) begin
                    // aux_data = {dut.U_DATA_MEM.mem[k+3], dut.U_DATA_MEM.mem[k+2], dut.U_DATA_MEM.mem[k+1], dut.U_DATA_MEM.mem[k]};
                    aux_data = {dut.U_DATA_MEM.mem[k]};
                    $display("k:%d aux_data: %d", k, aux_data);
                    $display("      Time %0t ps: Data Memory [%0d]= [%b] changed to %d<<<--- =%b =%h\n\n", $time, k, k, aux_data, aux_data,aux_data);
                end
            end
        endgenerate

    // Monitor inst memory
        generate
            for (k = 0; k < INST_MEM_WORDS; k = k +1) begin
                // always @(dut.U_INST_MEM.mem[k*4] or dut.U_INST_MEM.mem[(k*4)+1] or dut.U_INST_MEM.mem[(k*4)+2] or dut.U_INST_MEM.mem[(k*4)+3]) begin
                always @(dut.U_INST_MEM.mem[k]) begin
                    // aux_inst = {dut.U_INST_MEM.mem[(k*4)+3], dut.U_INST_MEM.mem[(k*4)+2], dut.U_INST_MEM.mem[(k*4)+1], dut.U_INST_MEM.mem[k*4]};
                    aux_inst = {dut.U_INST_MEM.mem[k]};
                    // $display("aux_inst: %h", aux_inst);
                    // Convert aux_inst to a hexadecimal string format
                    $display("          ->Time %0t ps: Instruction Memory [%0d]= [%b] changed to %h<<<--- = %s\n\n", $time, k, k, aux_inst, decode_instruction(aux_inst));
                    
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
        always @(dut.core_pc_IF) begin
            if (!rst_core) begin
                $display("  Time %0t ps: [Program Counter] dut.core_pc_IF changed to %0d", $time, dut.core_pc_IF);
                $fdisplay(f_osiris_core_state_dump, "   Clock Cycle: %d | [Program Counter] changed to %h", cycle_counter, dut.core_pc_IF);
            end
        end

    // Monitor changes in the Instruction Register
        always @(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID) begin
            if (!rst_core) begin
                $display("  Time %0t ps: [Instruction Register]  i_instr_ID changed to %h, Assembly: %s", $time, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
                $fdisplay(f_osiris_core_state_dump, "   Clock Cycle: %d | [Instruction Register] changed to %h, Assembly: %s", cycle_counter, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
            end
        end

    // Simulate fetching instructions
        // Memory reads are asynchronous
        always @(*) begin
            if (!rst_core) begin
                // if (dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID!= 0) begin
                    // dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID = dut.U_INST_MEM.mem[dut.core_pc_IF[INST_MEM_ADDR_BITS-1:0]];
                    // $display("->Time %0t ps: Instruction Fetch: PC = %d, Instruction = %h, Assembly: %s", $time, dut.core_pc_IF, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
                    $display("->Time %0t ps: Instruction Fetch: PC[%d], Instruction = %h, Assembly: %s --------------", $time, dut.core_pc_IF, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
                // end
                // decoded_inst = decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID);
            end 
            // end else begin
            //     // dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID = {DATA_WIDTH{1'b1}};
            //     //$display("Time %0t ps: Instruction Fetch: PC[%h], Instruction = %h, Assembly: %s", $time, dut.core_pc_IF, dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID, decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID));
            //     // decoded_inst = decode_instruction(dut.U_CORE.U_DATAPATH.U_STAGE_DECODE.i_instr_ID);
            // end
        end


    // // Initializing the Instruction Memory with 0x00000033
    //     initial begin
    //     end




    // Main Test Sequence
    initial begin
        integer i;

        test_passed = 1;
        rst_core = 1;
        step = 0;

        $display("Starting osiris_i Testbench...");
        #200;  // Wait for reset to deassert

        // test_memory(i_select_mem, 32'h00000000, 32'hBEE00000, 10, 0); // testing inst mem
        // test_memory(1, 32'hF0000007, 32'hBAA00000, 10, 1); // (i_select_mem, first_addr, first_value) testing data mem
        test_memory(1, 32'hF0000000, 32'h00000000, 30, 1); // (i_select_mem, first_addr, first_value) testing data mem

        #100;
        step = 0;
        // reset_memory(select_mem, first_address, reset_value)
        // reset_memory(0,32'h00000000,32'hF0000033, 0);// (inst_mem, 0, 33 = NOP inst)
        // reset_memory(1,32'h00000000,32'hAAAAAAAA, 0);// (data_mem, 0, random value)
        
        $display("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");

        for (i = 0; i < INST_MEM_WORDS; i = i + 1) begin
            dut.U_INST_MEM.mem[i]   = 32'h00000033; // Least significant byte
            // dut.U_INST_MEM.mem[(i*4)]   = 32'h00000033 + (i )*4; // Least significant byte
        end

        for (i = 0; i < DATA_MEM_WORDS; i = i + 1) begin
            dut.U_DATA_MEM.mem[i]   = 32'h00000000 + i ;
            // dut.U_DATA_MEM.mem[i]   = 32'hABCDEF56; 
            // dut.U_DATA_MEM.mem[i]   = 32'hDEADBEEF; 
        end



        rst_mem_uart = 1;
        #(CLK_PERIOD);
        rst_mem_uart = 0;
        #(10* CLK_PERIOD);
        step = 1;
        write_on_inst_mem_with_UART_and_compare(0);
        // #1 test_memory(1, 32'h00000000, 32'hDEADBEEF, 10, 0); // (i_select_mem, first_addr, first_value) testing Data memory
        // #1 test_memory(1, 32'h00000000, 32'h00000000, 30, 0); // (i_select_mem, first_addr, first_value) testing Data memory
        
        i_select_mem = 0;
        // update_instructions_on_instr_mem();
        $display("############################################################################");
        #(WAIT_BETWEEN_STEPS);
        $display("\n\n --------------------------------------------");
        $display(" Test 5: Run Program on Core and Verify Result in Data Memory ");
        $display(" --------------------------------------------");
        step = 2;


        // OK todo: separate reset signal to memories
        // todo: core clock-gating when UART accesses memories
        // todo: add PDK memories
        
        // todo: check if addressing would be by bytes or not

        // todo: confimacao da UART em que estado estah 
        //      jgoar bits estado para fora ou bit
        // todo: x- confirmacao da memoria que foi escrito


        // Release Core Reset and Start Execution
        #(WAIT_BETWEEN_STEPS);
        i_start_rx = 0;  // Disable UART reception
        #(50* CLK_PERIOD);
        step = 3;
        rst_core = 0; // Activate core
        #(100 * CLK_PERIOD);  // Wait for core to execute instructions

        step = 4;
        i_start_rx = 1;  // Enable UART reception
        rst_core = 1; // disable core
        #(10* CLK_PERIOD);

        // Reading Expected Results from File
        expected_result_count = 0;
        // $display("Reading expected results from store_expected.txt...");
        // read_expected_results_from_file("../src/store_expected.txt");
        // $display("Reading expected results from all_expected_results.txt...");
        // read_expected_results_from_file("../src/all_expected_results.txt");

        // Open File to Write Outputs
        output_file = $fopen("../src/risc_outputs.txt", "w");
        if (output_file == 0) begin
            $display("Error: Cannot open risc_outputs.txt for writing");
            $finish;
        end

        $display("\n\n-------------------------------------------------------------");
        // Verify Results and Write Outputs to File
        // $display(" Test 5: Verifying results and writing outputs to risc_outputs.txt...");
        // i_select_mem = 1;  // Select Data Memory
        // for (it = 0; it < expected_result_count; it = it + 1) begin
        //     test_read_from_memory(expected_addresses[it], read_data);
        //     // Write output to file
        //     // $fwrite(output_file, "@%08X %08X\n", expected_addresses[it], read_data);

        //     if (read_data !== expected_data_array[it]) begin
        //         $display("ERROR: Data mismatch at address 0x%08X! Expected 0x%08X, Got 0x%08X \n",
        //                  expected_addresses[it], expected_data_array[it], read_data);
        //         test_passed = 0;
        //     end else begin
        //         $display("OK: Data at address 0x%08X verified: 0x%08X \n", expected_addresses[it],
        //                  read_data);
        //     end
        // end

        // Close the output file
        $fclose(output_file);
        // #100000 

        // Final Test Result
        if (test_passed) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\nError: Some tests FAILED.");
        end

        $finish;
    end

    task write_on_inst_mem_with_UART_and_compare(input logic debug);   
    begin
        // Reading Instructions from File
        $display("Reading instructions from .txt...");
        num_instructions = 0;
        // read_instructions_from_file("../src/inst_hex.txt");
        // read_instructions_from_file("../src/all_instructions.txt");
        // read_instructions_from_file("../src/inst_i-type.txt");
        // read_instructions_from_file("../src/inst_r-type.txt");
        // read_instructions_from_file("../src/inst_s-type.txt");
        // read_instructions_from_file("../src/inst_b-type.txt");

        update_instructions_on_instr_mem();

        #(WAIT_BETWEEN_STEPS) step = 1;
        i_select_mem = 0;  // Select Instruction Memory
        $display("\n\n----------------- Test 3: Loading instructions into Instruction Memory... ----------------------------");
        $display("i_select_mem: %b",i_select_mem) ;
        // Loading Instructions into Instruction Memory
        for (it = 0; it < num_instructions; it = it + 1) begin
            $display("\n Test 3: [%1d] Sending to addr: %h the data: %h = %s", it, instruction_addresses[it]*4, instruction_mem[it], decode_instruction(instruction_mem[it]));
            step = step + 1;
            // test_write_to_memory(instruction_addresses[it], instruction_mem[it]);
            test_write_to_memory(instruction_addresses[it]*4, instruction_mem[it], debug);
        end
        $display("num_instructions: %d",num_instructions) ;



        #(5 * WAIT_BETWEEN_STEPS);
        step = 1;

        $display("\n\n --------------------------------------------");
        if (i_select_mem == 0) begin
            $display(" Test 4: Reading Data from Instruction Memory via UART...");
        end else begin
            $display(" Test 4: Reading Data from Data Memory via UART...");
        end
        $display(" --------------------------------------------");
        for (it = 0; it < num_instructions; it = it + 1) begin
            // test_read_from_memory(instruction_addresses[it], read_data);
            test_read_from_memory(instruction_addresses[it]*4, read_data, 1);
            // $display("\nTest 4: [%1d] Read from addr: %h the data: %h", it, instruction_addresses[it]*4, read_data);
            // compare_memory_data(instruction_addresses[it], read_data); // Compare with expected data
            compare_memory_data(instruction_addresses[it]*4, read_data, 1); // Compare with expected data
        end
    end
    endtask 

    task update_instructions_on_instr_mem;
        integer x;
        begin

            // # I-Type Instructions

            // lb (Load byte)
            // x=0;
            // #(CLK_PERIOD) $display("Sending lb x1, 0(x2)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} = 32'h00010083;  // lb x1, 0(x2)  // Load byte from address x2 + 0 into x1 (value depends on memory content): reg[1] = 0
            // x=4;
            // #(CLK_PERIOD) $display("Sending lb x3, -4(x4)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =  32'hffc20183;  // lb x3, -4(x4)  // Load byte from address x4 - 4 into x3 (value depends on memory content): reg[3] = 0

            // // lh (Load halfword)
            // x=24;
            // #(CLK_PERIOD) $display("Sending lh x5, 2(x6)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =  32'h00231283;  // lh x5, 2(x6)  // Load halfword from address x6 + 2 into x5 (value depends on memory content): reg[5] = 8
            // x= 28;
            // #(CLK_PERIOD) $display("Sending lh x7, -8(x8)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =  32'hff841383;  // lh x7, -8(x8)  // Load halfword from address x8 - 8 into x7 (value depends on memory content): reg[7] = 0
            // num_instructions = 28/4;
            // lw (Load word)
            // x=32;
            // #(CLK_PERIOD) $display("Sending lw x9, 4(x10)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =   32'h00452483;  // lw x9, 4(x10)  // Load word from address x10 + 4 into x9 (value depends on memory content): reg[9] = 14
            // x=36;
            // #(CLK_PERIOD) $display("Sending lw x11, -12(x12)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =   32'hff462583;  // lw x11, -12(x12)  // Load word from address x12 - 12 into x11 (value depends on memory content): reg[11] = 0

            // // lbu (Load byte unsigned)
            // #(CLK_PERIOD) $display("Sending lbu x13, 0(x14)");
            // dut.U_INST_MEM.mem[40] = 32'h00074683;  // lbu x13, 0(x14)  // Load byte from address x14 + 0 into x13 (unsigned, value depends on memory content): reg[13] = 14
            // #(CLK_PERIOD) $display("Sending lbu x15, -4(x1)"); // unsigned -4 (12 bits) = FFFFFFFE₁₆. 
            // dut.U_INST_MEM.mem[44] = 32'hffc0c783;  // lbu x15, -4(x1)  // Load byte from address x1 - 4 into x15 (unsigned, value depends on memory content): reg[15] = data_from_addr(FFFFFFFE₁₆ + 1) = data_from_addr(FFFFFFFD₁₆)

            // // lhu (Load halfword unsigned)
            // #(CLK_PERIOD) $display("Sending lhu x2, 2(x3)");
            // dut.U_INST_MEM.mem[48] = 32'h0021d103;  // lhu x2, 2(x3)  // Load halfword from address x3 + 2 into x2 (unsigned, value depends on memory content): reg[2] = 5
            // #(CLK_PERIOD) $display("Sending lhu x4, -8(x5)");
            // dut.U_INST_MEM.mem[52] = 32'hff82d203;  // lhu x4, -8(x5)  // Load halfword from address x5 - 8 into x4 (unsigned, value depends on memory content): reg[4] = data_from_address(-3)


            // jalr (Jump and link register)
            // #(CLK_PERIOD) $display("Sending jalr x1, 32(x8)");
            // dut.U_INST_MEM.mem[56] = 32'h020400e7;  // jalr x1, 32(x8)  // Jump to address x8 + 32 = 40, x1 = return address = PC + 4 = 60 (decimal)
            // dut.U_INST_MEM.mem[60] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
            // #(CLK_PERIOD) $display("Sending jalr x3, -4(x4)");
            // dut.U_INST_MEM.mem[100] = 32'hffc201e7;  // jalr x3, -4(x4)  // Jump to address x4 - 4 = 0, x3 = return address = 0 (decimal)
            // #(CLK_PERIOD) $display("Sending jalr x5, 8(x6)");
            // dut.U_INST_MEM.mem[104] = 32'h008302e7;  // jalr x5, 8(x6)  // Jump to address x6 + 8, x5 = return address = 5 (decimal)


            // andi (AND immediate)
            #(CLK_PERIOD) $display("Sending andi x1, x2, 0xF");
            dut.U_INST_MEM.mem[0] = 32'h00f17093;  // andi x1, x2, 0xF  // x1 = x2 & 0xF = 2
            #(CLK_PERIOD) $display("Sending andi x3, x4, 0xA");
            dut.U_INST_MEM.mem[364] = 32'h00a27193;  // andi x3, x4, 0xA  // x3 = x4 & 0xA = 0
            #(CLK_PERIOD) $display("Sending andi x5, x6, 0xFF");
            dut.U_INST_MEM.mem[368] = 32'h0ff37293;  // andi x5, x6, 0xFF  // x5 = x6 & 0xFF = 6

            // // ori (OR immediate)
            // #(CLK_PERIOD) $display("Sending ori x1, x2, 0x1");
            // dut.U_INST_MEM.mem[372] = 32'h00116093;  // ori x1, x2, 0x1  // x1 = x2 | 0x1 = 3
            // #(CLK_PERIOD) $display("Sending ori x3, x4, 0xA");
            // dut.U_INST_MEM.mem[376] = 32'h00a26193;  // ori x3, x4, 0xA  // x3 = x4 | 0xA = 14
            // #(CLK_PERIOD) $display("Sending ori x5, x6, 0xFF");
            // dut.U_INST_MEM.mem[380] = 32'h0x0ff36293;  // ori x5, x6, 0xFF  // x5 = x6 | 0xFF = 255


            // // # xori
            // #(CLK_PERIOD) $display("Sending xori x1, x2, 0x2");
            // dut.U_INST_MEM.mem[0] = 32'h00214093;  // xori x1, x2, 0x2  // x1 = x2 ^ 0x2 = 2 ^ 2 = 0
            // #(CLK_PERIOD) $display("Sending xori x3, x4, 0x8");
            // dut.U_INST_MEM.mem[4] = 32'h00824193;  // xori x3, x4, 0x8  // x3 = x4 ^ 0x8 = 4 ^ 8 = 12
            // #(CLK_PERIOD) $display("Sending xori x5, x6, 0xF");
            // dut.U_INST_MEM.mem[8] = 32'h00F34293;  // xori x5, x6, 0xF  // x5 = x6 ^ 0xF = 6 ^ 15 = 9

            // // # slti
            // #(CLK_PERIOD) $display("Sending slti x7, x8, 10");
            // dut.U_INST_MEM.mem[12] = 32'h00A42393;  // slti x7, x8, 10  // x7 = (x8 < 10) ? 1 : 0 = (8 < 10) ? 1 : 0 = 1
            // #(CLK_PERIOD) $display("Sending slti x9, x10, 20");
            // dut.U_INST_MEM.mem[16] = 32'h01452493;  // slti x9, x10, 20  // x9 = (x10 < 20) ? 1 : 0 = (10 < 20) ? 1 : 0 = 1
            // #(CLK_PERIOD) $display("Sending slti x11, x12, 30");
            // dut.U_INST_MEM.mem[20] = 32'h01E62593;  // slti x11, x12, 30  // x11 = (x12 < 30) ? 1 : 0 = (12 < 30) ? 1 : 0 = 1
            // #(CLK_PERIOD) $display("Sending slti x11, x12, 10");
            // dut.U_INST_MEM.mem[24] = 32'h00A62593;  // slti x11, x12, 10  // x11 = (x12 < 10) ? 1 : 0 = (12 < 10) ? 1 : 0 = 0

            // // # sltiu
            // #(CLK_PERIOD) $display("Sending sltiu x13, x14, 5");
            // dut.U_INST_MEM.mem[24] = 32'h00573693;  // sltiu x13, x14, 5  // x13 = (x14 < 5) ? 1 : 0 (unsigned) = (14 < 5) ? 0 = 0
            // #(CLK_PERIOD) $display("Sending sltiu x15, x1, 15");
            // dut.U_INST_MEM.mem[28] = 32'h00F0B793;  // sltiu x15, x1, 15  // x15 = (x1 < 15) ? 1 : 0 (unsigned) = (1 < 15) ? 1 = 1
            // #(CLK_PERIOD) $display("Sending sltiu x2, x3, 25");
            // dut.U_INST_MEM.mem[32] = 32'h0191B113;  // sltiu x2, x3, 25  // x2 = (x3 < 25) ? 1 : 0 (unsigned) = (3 < 25) ? 1 = 1

            // // # slli
            // #(CLK_PERIOD) $display("Sending slli x1, x2, 1");
            // dut.U_INST_MEM.mem[36] = 32'h00111093;  // slli x1, x2, 1  // x1 = x2 << 1 = 2 << 1 = 4
            // #(CLK_PERIOD) $display("Sending slli x3, x4, 2");
            // dut.U_INST_MEM.mem[40] = 32'h00221193;  // slli x3, x4, 2  // x3 = x4 << 2 = 4 << 2 = 16
            // #(CLK_PERIOD) $display("Sending slli x5, x6, 3");
            // dut.U_INST_MEM.mem[44] = 32'h00331293;  // slli x5, x6, 3  // x5 = x6 << 3 = 6 << 3 = 48

            // // # srli
            // #(CLK_PERIOD) $display("Sending srli x7, x8, 1");
            // dut.U_INST_MEM.mem[48] = 32'h00145393;  // srli x7, x8, 1  // x7 = x8 >> 1 = 8 >> 1 = 4
            // #(CLK_PERIOD) $display("Sending srli x9, x10, 2");
            // dut.U_INST_MEM.mem[52] = 32'h00255493;  // srli x9, x10, 2  // x9 = x10 >> 2 = 10 >> 2 = 2
            // #(CLK_PERIOD) $display("Sending srli x11, x12, 3");
            // dut.U_INST_MEM.mem[56] = 32'h00365593;  // srli x11, x12, 3  // x11 = x12 >> 3 = 12 >> 3 = 1

            // // # srai
            // #(CLK_PERIOD) $display("Sending srai x13, x14, 1");
            // dut.U_INST_MEM.mem[60] = 32'h40175693;  // srai x13, x14, 1  // x13 = x14 >> 1 (arithmetic) = 14 >> 1 = 7
            // #(CLK_PERIOD) $display("Sending srai x15, x1, 2");
            // dut.U_INST_MEM.mem[64] = 32'h4020d793;  // srai x15, x1, 2  // x15 = x1 >> 2 (arithmetic) = 1 >> 2 = 0
            // #(CLK_PERIOD) $display("Sending srai x2, x3, 3");
            // dut.U_INST_MEM.mem[68] = 32'h4031d113;  // srai x2, x3, 3  // x2 = x3 >> 3 (arithmetic) = 3 >> 3 = 0


            // # R-Type Instructions

            // # add
            // #(CLK_PERIOD) $display("Sending add x1, x2, x3");
            // dut.U_INST_MEM.mem[72] = 32'h003100B3;  // add x1, x2, x3  // x1 = x2 + x3 = 2 + 3 = 5
            // #(CLK_PERIOD) $display("Sending add x4, x5, x6");
            // dut.U_INST_MEM.mem[76] = 32'h00628233;  // add x4, x5, x6  // x4 = x5 + x6 = 5 + 6 = 11
            // #(CLK_PERIOD) $display("Sending add x7, x8, x9");
            // dut.U_INST_MEM.mem[80] = 32'h009403B3;  // add x7, x8, x9  // x7 = x8 + x9 = 8 + 9 = 17

            // # sub
            // #(CLK_PERIOD) $display("Sending sub x1, x2, x3");
            // dut.U_INST_MEM.mem[84] = 32'h403100B3;  // sub x1, x2, x3  // x1 = x2 - x3 = 2 - 3 = -1
            // #(CLK_PERIOD) $display("Sending sub x4, x5, x6");
            // dut.U_INST_MEM.mem[88] = 32'h40628233;  // sub x4, x5, x6  // x4 = x5 - x6 = 4 - 6 = -1
            // #(CLK_PERIOD) $display("Sending sub x7, x8, x9");
            // dut.U_INST_MEM.mem[92] = 32'h409403B3;  // sub x7, x8, x9  // x7 = x8 - x9 = 8 - 9 = -1

            // // # sll
            // #(CLK_PERIOD) $display("Sending sll x1, x2, x3");
            // dut.U_INST_MEM.mem[96] = 32'h003110B3;  // sll x1, x2, x3  // x1 = x2 << x3 = 2 << 3 = 16
            // #(CLK_PERIOD) $display("Sending sll x4, x5, x6");
            // dut.U_INST_MEM.mem[100] = 32'h00629233;  // sll x4, x5, x6  // x4 = x5 << x6 = 5 << 6 = 320
            // #(CLK_PERIOD) $display("Sending sll x7, x8, x9");
            // dut.U_INST_MEM.mem[104] = 32'h009413B3;  // sll x7, x8, x9  // x7 = x8 << x9 = 8 << 9 = 4096
            //    // # slt
            // // #(CLK_PERIOD) $display("Sending slt x1, x2, x3"); // * since x1 is already 1 the tb won't detect any change
            // // dut.U_INST_MEM.mem[108] = 32'h003120B3;  // slt x1, x2, x3  // x1 = (x2 < x3) ? 1 : 0 = (2 < 3) ? 1 = 1
            // #(CLK_PERIOD) $display("Sending slt x4, x5, x6");
            // dut.U_INST_MEM.mem[112] = 32'h0062A233;  // slt x4, x5, x6  // x4 = (x5 < x6) ? 1 : 0 = (4 < 6) ? 1 = 1
            // #(CLK_PERIOD) $display("Sending slt x7, x8, x9");
            // dut.U_INST_MEM.mem[116] = 32'h009423B3;  // slt x7, x8, x9  // x7 = (x8 < x9) ? 1 : 0 = (8 < 9) ? 1 = 1

            // # sltu
            // #(CLK_PERIOD) $display("Sending sltu x1, x2, x3"); // * since x1 is already 1 the tb won't detect any change
            // dut.U_INST_MEM.mem[120] = 32'h003130B3;  // sltu x1, x2, x3  // x1 = (x2 < x3) ? 1 : 0 (unsigned) = (2 < 3) ? 1 = 1
            // #(CLK_PERIOD) $display("Sending sltu x4, x5, x6");
            // dut.U_INST_MEM.mem[124] = 32'h0062B233;  // sltu x4, x5, x6  // x4 = (x5 < x6) ? 1 : 0 (unsigned) = (4 < 6) ? 1 = 1
            // #(CLK_PERIOD) $display("Sending sltu x7, x8, x9");
            // dut.U_INST_MEM.mem[128] = 32'h009433B3;  // sltu x7, x8, x9  // x7 = (x8 < x9) ? 1 : 0 (unsigned) = (8 < 9) ? 1 = 1

            // // # xor
            // // #(CLK_PERIOD) $display("Sending xor x1, x2, x3"); // * since x1 is already 1 the tb won't detect any change
            // // dut.U_INST_MEM.mem[132] = 32'h003140B3;  // xor x1, x2, x3  // x1 = x2 ^ x3 = 2 ^ 3 = 1
            // #(CLK_PERIOD) $display("Sending xor x4, x5, x6");
            // dut.U_INST_MEM.mem[136] = 32'h0062C233;  // xor x4, x5, x6  // x4 = x5 ^ x6 = 4 ^ 6 = 3
            // #(CLK_PERIOD) $display("Sending xor x7, x8, x9");
            // dut.U_INST_MEM.mem[140] = 32'h009443B3;  // xor x7, x8, x9  // x7 = x8 ^ x9 = 8 ^ 9 = 1

            // // # srl
            // #(CLK_PERIOD) $display("Sending srl x1, x2, x3");
            // dut.U_INST_MEM.mem[144] = 32'h003150B3;  // srl x1, x2, x3  // x1 = x2 >> x3 = 2 >> 3 = 0
            // #(CLK_PERIOD) $display("Sending srl x4, x5, x6");
            // dut.U_INST_MEM.mem[148] = 32'h062D233;   // srl x4, x5, x6  // x4 = x5 >> x6 = 4 >> 6 = 0
            // #(CLK_PERIOD) $display("Sending srl x7, x8, x9");
            // dut.U_INST_MEM.mem[152] = 32'h009453B3;  // srl x7, x8, x9  // x7 = x8 >> x9 = 8 >> 9 = 0

            // // # sra
            // #(CLK_PERIOD) $display("Sending sra x1, x2, x3");
            // dut.U_INST_MEM.mem[156] = 32'h403150B3;  // sra x1, x2, x3  // x1 = x2 >> x3 (arithmetic) = 2 >> 3 = 0
            // #(CLK_PERIOD) $display("Sending sra x4, x5, x6");
            // dut.U_INST_MEM.mem[160] = 32'h4062D233;  // sra x4, x5, x6  // x4 = x5 >> x6 (arithmetic) = 4 >> 6 = 0
            // #(CLK_PERIOD) $display("Sending sra x7, x8, x9");
            // dut.U_INST_MEM.mem[164] = 32'h409453B3;  // sra x7, x8, x9  // x7 = x8 >> x9 (arithmetic) = 8 >> 9 = 0

            // // # or
            // #(CLK_PERIOD) $display("Sending or x1, x2, x3");
            // dut.U_INST_MEM.mem[168] = 32'h003160B3;  // or x1, x2, x3  // x1 = (x2 | x3) = 2 --> = 3
            // #(CLK_PERIOD) $display("Sending or x4, x5, x6");
            // dut.U_INST_MEM.mem[172] = 32'h0062E233;  // or x4, x5, x6  // x4 = (5 | x6) = 6  --> = 7
            // #(CLK_PERIOD) $display("Sending or x7, x8, x9");
            // dut.U_INST_MEM.mem[176] = 32'h009463B3;  // or x7, x8, x9  // x7 = (x8 | x9) = 8 --> = 9

            // // # and
            // #(CLK_PERIOD) $display("Sending and x1, x2, x3");
            // dut.U_INST_MEM.mem[180] = 32'h003170B3;  // and x1, x2, x3  // x1 = x2 & x3 = 2 & 3 = 2
            // // #(CLK_PERIOD) $display("Sending and x4, x5, x6"); // * since x4 is already 4 the tb won't detect any change
            // // dut.U_INST_MEM.mem[184] = 32'h0062F233;  // and x4, x5, x6  // x4 = x5 & x6 = 4 & 6 = 4
            // #(CLK_PERIOD) $display("Sending and x7, x8, x9");
            // dut.U_INST_MEM.mem[188] = 32'h009473B3;  // and x7, x8, x9  // x7 = x8 & x9 = 8 & 9 = 8

            // # S-Type Instructions

            // // # sb
            // x = 192;
            // #(CLK_PERIOD) $display("Sending sb x1, 1(x1)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} = 32'h001080a3;  // sb x1, 1(x1)  // Store byte from x1 to memory at address x1 + 1: mem[2] = 1

            // x = 204;
            // #(CLK_PERIOD) $display("Sending sb x3, 3(x1)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =32'h003081a3;  // sb x3, 3(x1)  // Store byte from x3 to memory at address x1 + 3: mem[4] = 3
            // x = 208;
            // #(CLK_PERIOD) $display("Sending sb x3, -2(x1)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} =32'hfe308f23;  // sb x3, -2(x1)  // Store byte from x3 to memory at address x1 + 2: mem[-1] = 3

            // x = 212;
            // #(CLK_PERIOD) $display("Sending sb x1, 1(x1)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} = 32'h001080a3;  // sb x1, 1(x1)  // Store byte from x1 to memory at address x1 + 1: mem[2] = 1
            // x = 216;
            // #(CLK_PERIOD) $display("Sending sb x2, 2(x1)");
            // {dut.U_INST_MEM.mem[x+3],dut.U_INST_MEM.mem[x+2],dut.U_INST_MEM.mem[x+1],dut.U_INST_MEM.mem[x]} = 32'h00208123;  // sb x2, 2(x1)  // Store byte from x2 to memory at address x1 + 2: mem[3] = 2
            // // NOP instruction
            // // #(CLK_PERIOD);
            // // for (inst = 0; inst < 50; inst=inst+1) begin
            // //     $display("Sending add x0, x0, x0");
            // //     dut.U_INST_MEM.mem[x*4 + 208] = 32'h00000033;  // NOP add x0, x0, x0
            // // end

            // // # sh
            // // x = 220;
            // // write_instruction_mem(4,32'h0010a023); // sw x1, 0(x1)  // Store word from x1 to memory at address x1 + 0: mem[1] = 1
            // // write_instruction_mem(4,32'h0010a023); // sw x1, 0(x1)  // Store word from x1 to memory at address x1 + 0: mem[1] = 1
            // // mem[0] = abcdef56
            // write_instruction_mem(8,32'h00109023); // sh x1, 0(x1)  // mem[0] = ab(0001)56
            // write_instruction_mem(12,32'h0000a283); // lw x5, 0(x1)  // reg[5] = ab000156
            // // write_instruction_mem(16,32'h00422283); // lw x5, 4(x4)  //
            // write_instruction_mem(20,32'h005090a3); // sh x5, 1(x1) // mem[0] = (0156)0156
            // // write_instruction_mem(8,32'h00109023); // sh x2, 2(x1)  // Store halfword from x2 to memory at address x1 + 2: mem[3] = 2
            // // write_instruction_mem(8,32'h00109023); // sh x3, 4(x1)  // Store halfword from x3 to memory at address x1 + 4: mem[5] = 3
            // // // // NOP instruction
            // // // #(CLK_PERIOD);
            // // // for (inst = 0; inst < 50; inst=inst+1) begin
            // // //     $display("Sending add x0, x0, x0");
            // // //     dut.U_INST_MEM.mem[inst*4 + 220] = 32'h00000033;  // NOP add x0, x0, x0
            // // end

            // # sw
            // write_instruction_mem(24,32'h0010A023); // sw x1, 0(x1)  // mem[0] = (000001)56 //! bug here, the result is being 00000156 but the 2 MSBs should be stored at the next word rigth (an exception should be called)
            
            // // write_instruction_mem(236,32'h0020A123);// sw x2, 4(x1)  // Store word from x2 to memory at address x1 + 4: mem[3] = 2

            // // write_instruction_mem(12,32'h0030A423); // sw x3, 8(x1)  // Store word from x3 to memory at address x1 + 8: mem[9] = 3
            // write_instruction_mem(24,32'h00322223); // sw x3, 4(x4) // mem[8] = 3
            // // write_instruction_mem(28,32'h00422283); // lw x5, 4(x4)  // reg[5] = 3


            // write_instruction_mem(16,32'h0010a083); // lw x1, 1(x1)  
            // write_instruction_mem(24,32'h0080a103); // lw x2, 8(x1) 
            // write_instruction_mem(32,32'h00802183); // lw x4, 8(x0) 
            // write_instruction_mem(8, 32'h00002183); // lw x3, 0(x0)  // reg[3] = 0
            // write_instruction_mem(12,32'h00022203); // lw x4, 0(x4)  // reg[4] = 1
            // write_instruction_mem(80,32'h00422283); // lw x5, 4(x4)  // reg[5] = abcdef56
            // write_instruction_mem(84,32'h00542223); // sw x5, 4(x8) // mem[12] = abcdef56

            // write_instruction_mem(8, 32'h00001183); // lh x3, 0(x0)  // reg[3] = 0
            // write_instruction_mem(12,32'h00021203); // lh x4, 0(x4)  // reg[4] = 1
            // write_instruction_mem(16,32'h00421283); // lh x5, 4(x4)  // reg[5] = 2

            // write_instruction_mem(8, 32'h00000183); // lb x3, 0(x0)  // reg[3] = 0
            // write_instruction_mem(12,32'h00020203); // lb x4, 0(x4)  // reg[4] = 1
            // write_instruction_mem(16,32'h00420283); // lb x5, 4(x4)  // reg[5] = 2

            // write_instruction_mem(8, 32'h00000183); // lb x3, 0(x0)  
            // write_instruction_mem(12, 32'h00100183); // lb x3, 1(x0) 
            // write_instruction_mem(16, 32'h00200183); // lb x3, 2(x0)  

            // write_instruction_mem(20, 32'h00004183); // lbu x3, 0(x0)  
            // write_instruction_mem(24, 32'h00104183); // lbu x3, 1(x0) 
            // write_instruction_mem(28, 32'h00204183); // lbu x3, 2(x0)  


            // // NOP instruction
            // #(CLK_PERIOD);
            // for (inst = 3; inst < 50; inst=inst+1) begin
            //     $display("Sending add x0, x0, x0");
            //     dut.U_INST_MEM.mem[inst*4 + 232] = 32'h00000033;  // NOP add x0, x0, x0
            // end


            // # B-Type Instructions

            // // # beq
            // dut.U_INST_MEM.mem[232] = 32'h00000033;  // NOP add x0, x0, x0
            // // dut.U_INST_MEM.mem[0] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
            // #(CLK_PERIOD) $display("Sending beq x3, x4, -4");
            // dut.U_INST_MEM.mem[236] = 32'hFE418EE3;  // Branch if x3 == x4 to PC - 4: false
            // #(CLK_PERIOD) $display("Sending beq x5, x6, 12");
            // dut.U_INST_MEM.mem[240] = 32'h00628663;  // beq x5, x6, 12  // Branch if x5 == x6 to PC + 12: false
            // #(CLK_PERIOD) $display("Sending beq x2, x2, 35");
            // dut.U_INST_MEM.mem[244] = 32'h02210163;  // Branch if x2 == x2 to PC + 35  = 12 + 35(100011) -> 34(100010) imm_ext -> 33(10000) next_pc = 244+ 33 = 276 (100010100): true
            // dut.U_INST_MEM.mem[276] = 32'h00210133;  // add x2, x2, x2 // x2 = 4

            // # bne
            // // #(CLK_PERIOD) $display("Sending bne x2, x2, 40");
            // // dut.U_INST_MEM.mem[280] = 32'h02211463;  // bne x1, x2, 40  // Branch if x1 != x2 to PC + 40: false
            // // #(CLK_PERIOD) $display("Sending bne x3, x4, -4");
            // // dut.U_INST_MEM.mem[284] = 32'hFE419EE3;  // bne x3, x4, -4  // Branch if x3 != x4 to PC - 4: true
            // #(CLK_PERIOD) $display("Sending bne x5, x6, 12");
            // dut.U_INST_MEM.mem[288] = 32'h00629663;  // bne x5, x6, 12  // Branch if x5 != x6 to PC + 12: true (but it won't execute completely if you execute the previous instruction before, it will execute partially then will receive aflush from hazard unit because this is a control hazard)
            // dut.U_INST_MEM.mem[292] = 32'h00210133;  // add x2, x2, x2 // x2 = 4

            // // # blt 
            // #(CLK_PERIOD) $display("Sending blt x1, x2, 40");
            // dut.U_INST_MEM.mem[252] = 32'h0220c463;  // blt x1, x2, 8  // Branch if x1 < x2 to PC + 8: true
            // dut.U_INST_MEM.mem[256] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
            // dut.U_INST_MEM.mem[292] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
            // #(CLK_PERIOD) $display("Sending blt x3, x4, -4");
            // dut.U_INST_MEM.mem[296] = 32'hFE41CEE3;  // blt x3, x4, -4  // Branch if x3 < x4 to PC - 4: true
            // #(CLK_PERIOD) $display("Sending blt x5, x6, 12");
            // dut.U_INST_MEM.mem[260] = 32'h0062C663;  // blt x5, x6, 12  // Branch if x5 < x6 to PC + 12: true

            // // # bge
            // #(CLK_PERIOD) $display("Sending bge x1, x2, 8");
            // dut.U_INST_MEM.mem[264] = 32'h0020D463;  // bge x1, x2, 8  // Branch if x1 >= x2 to PC + 8: false
            // // #(CLK_PERIOD) $display("Sending bge x5, x4, -4");
            // // dut.U_INST_MEM.mem[268] = 32'hFE42DEE3;  // bge x5, x4, -4  // Branch if x5 >= x4 to PC - 4: true
            // // dut.U_INST_MEM.mem[272] = 32'h00210133;  // add x2, x2, x2 // x2 = 4
            // // #(CLK_PERIOD) $display("Sending bge add x5, x5, x5"); 
            // // dut.U_INST_MEM.mem[280] = 32'h005282b3;  // add x5, x5, x5 // x5 = 10 // shouldn't execute completely due to previous branch
            // #(CLK_PERIOD) $display("Sending bge x6, x6, 40");
            // dut.U_INST_MEM.mem[276] = 32'h02635463;  // bge x6, x6, 40  // Branch if x6 >= x6 to PC + 12: true
            // dut.U_INST_MEM.mem[280] = 32'h001080b3;  // add x1, x1, x1 // x1 = 2

            // // # bltu
            // #(CLK_PERIOD) $display("Sending addi x1, x1, -2048");
            // dut.U_INST_MEM.mem[288] = 32'h80008093; // x1 = -2047 (11111111111111111111100000000001) = FFFFF801₁₆
            // #(CLK_PERIOD) $display("Sending bltu x1, x2, 8");
            // dut.U_INST_MEM.mem[292] = 32'h0020E463;  // bltu x1, x2, 8  // Branch if x1 < x2 (unsigned) to PC + 8 // -2047 -> 4294965249 < 2 = false
            // #(CLK_PERIOD) $display("Sending bltu x3, x4, -4");
            // dut.U_INST_MEM.mem[296] = 32'hFE41EEE3;  // bltu x3, x4, -4  // Branch if x3 < x4 (unsigned) to PC - 4 = true
            // #(CLK_PERIOD) $display("Sending bltu x5, x6, 12");
            // dut.U_INST_MEM.mem[300] = 32'h0062E663;  // bltu x5, x6, 12  // Branch if x5 < x6 (unsigned) to PC + 12

            // // # bgeu
            // #(CLK_PERIOD) $display("Sending bgeu x1, x2, 16");
            // dut.U_INST_MEM.mem[304] = 32'h0020f863;  // bgeu x1, x2, 16  // Branch if x1 >= x2 (unsigned) to PC + 16: false
            // #(CLK_PERIOD) $display("Sending bgeu x1, x6, 12");
            // dut.U_INST_MEM.mem[308] = 32'h0060f663;  // bgeu x1, x6, 12  // Branch if x1 >= x6 (unsigned) to PC + 12: false
            // dut.U_INST_MEM.mem[312] = 32'h80008093; // addi x1, x1, -2048 // x1 = -2047 (11111111111111111111100000000001)
            // #(CLK_PERIOD) $display("Sending bgeu x4, x4, -4");
            // dut.U_INST_MEM.mem[316] = 32'hFE427EE3;  // bgeu x3, x4, -4  // Branch if x3 >= x4 (unsigned) to PC - 4: true
            // dut.U_INST_MEM.mem[320] = 32'h00210133;  // add x2, x2, x2 // x2 = 4 // testing if hazard is flushing this instruction
            

            // # U-Type Instructions

            // // # lui
            // #(CLK_PERIOD) $display("Sending lui x1, 0x12345");
            // dut.U_INST_MEM.mem[324] = 32'h123450B7;  // lui x1, 0x12345  // x1 = 0x12345000 (305418240₁₀)
            // #(CLK_PERIOD) $display("Sending lui x2, 0x23456");
            // dut.U_INST_MEM.mem[328] = 32'h23456137;  // lui x2, 0x23456  // x2 = 0x23456000 (591749120₁₀)
            // #(CLK_PERIOD) $display("Sending lui x3, 0x34567");
            // dut.U_INST_MEM.mem[332] = 32'h345671B7;  // lui x3, 0x34567  // x3 = 0x34567000 (878080000₁₀)

            // // # auipc
            // #(CLK_PERIOD) $display("Sending auipc x4, 0x45678"); // PC = 336 = 0x150
            // dut.U_INST_MEM.mem[336] = 32'h45678217;  // auipc x4, 0x45678  // x4 = PC + 0x45678000: x4 = 0x45678150
            // #(CLK_PERIOD) $display("Sending auipc x5, 0x56789"); // PC = 336 = 0x154
            // dut.U_INST_MEM.mem[340] = 32'h56789297;  // auipc x5, 0x56789  // x5 = PC + 0x56789000: x5 = 0x56789154
            // #(CLK_PERIOD) $display("Sending auipc x6, 0x67890"); // PC = 336 = 0x158
            // dut.U_INST_MEM.mem[344] = 32'h67890317;  // auipc x6, 0x67890  // x6 = PC + 0x67890000: x6 = 0x67890158

            // // # J-Type Instructions
            // // # jal
            // #(CLK_PERIOD) $display("Sending jal x1, 32");
            // dut.U_INST_MEM.mem[348] = 32'h020000EF;  // jal x1, 32  // Jump to PC + 32, x1 = return address (PC + 4) = 352
            // #(CLK_PERIOD) $display("Sending jal x2, -16");
            // dut.U_INST_MEM.mem[352] = 32'hFF1FF16F;  // jal x2, -16  // Jump to PC - 16, x2 = return address (PC + 4) = 356
            // #(CLK_PERIOD) $display("Sending jal x3, 64");
            // dut.U_INST_MEM.mem[356] = 32'h040001EF;  // jal x3, 64  // Jump to PC + 64, x3 = return address (PC + 4) = 360

            // # exit
        end
    endtask //automatic

    task write_instruction_mem(input [INST_MEM_ADDR_BITS-1:0] word_addr, input [DATA_WIDTH-1:0]hex_value);
        begin
            // word_addr = word_addr*4;
            #(CLK_PERIOD) $display("Sending %s", decode_instruction(hex_value));
            // {dut.U_INST_MEM.mem[word_addr+3],dut.U_INST_MEM.mem[word_addr+2],dut.U_INST_MEM.mem[word_addr+1],dut.U_INST_MEM.mem[word_addr]}= hex_value; 
            dut.U_INST_MEM.mem[word_addr] = hex_value; 

        end
    endtask

    // Task to read instructions from a file specified by 'filename'
    task read_instructions_from_file(input string filename);
        integer instr_file;   // File descriptor for instruction file
        integer code;         // Variable to store the return code of $fgets
        reg [DATA_WIDTH-1:0] instr;  // Variables for instruction address and data
        // reg [ADDR_WIDTH-1:0] addr;  // Variables for instruction address and data
        parameter int MAX_LINE_LENGTH = 8; // Adjust as needed
        reg [8*MAX_LINE_LENGTH-1:0] line; // Line buffer as a reg array

        bit exit_loop; // Flag to control loop exit
        reg [DATA_WIDTH-1:0] hex_value;
        begin
            exit_loop = 0;
            $display("\n\n----------------- read_instructions_from_file ----------------------------");
            $display("Starting read_instructions_from_file for file: %s", filename);

            // Attempt to open the file in read mode
            instr_file = $fopen(filename, "r");
            $display("File opened, file descriptor: %0h", instr_file);
            
            // Check if file opened successfully
            if (instr_file == 0) begin
                $display("Error: Cannot open %s", filename);  // Display error if file cannot be opened
                $finish;  // Terminate simulation
            end

            num_instructions = 0;
            // Initialize counter and display start of file read loop
            $display("Beginning file read loop...");
            while (!$feof(instr_file)) begin
                if (!exit_loop) begin
                    
                    // Clear the line buffer
                    line = {8*MAX_LINE_LENGTH{1'b0}};

                    // Read a line from the file
                    code = $fgets(line, instr_file);

                    if (code == 0) begin
                        $display("Warning: fgets failed at line %0d", num_instructions + 1);
                        exit_loop = 1;
                    end

                    if (line == "\n") begin
                        $display("");
                    end else begin
                        $sscanf(line, "%h", hex_value);
                        $display("At line %0d -> Raw line read: %s = %s", num_instructions, line, decode_instruction(hex_value));

                        // Store address and instruction in arrays
                        instruction_addresses[num_instructions] = num_instructions;
                        // instruction_mem[num_instructions] = instr;
                        instruction_mem[num_instructions] = hex_value;
                        $display("Stored instruction at index %0d", num_instructions);

                        // Increment instruction count
                        num_instructions = num_instructions + 1;
                        
                        // For debugging, limit the number of instructions (optional)
                        if (num_instructions >= 117) begin
                            $display("Reached maximum instruction limit of %0d.", 117);
                            exit_loop = 1;
                        end
                    end
                end
            end

            // Close the instruction file after reading
            $fclose(instr_file);
            $display("File closed successfully.");

            // Display the number of instructions loaded
            $display("Loaded %0d instructions from %s.", num_instructions, filename);
        end
    endtask


    // Task to read expected results from a file specified by 'filename'
    // This task loads expected result data from the file into memory arrays
    task read_expected_results_from_file(input string filename);
        integer expected_file;      // File descriptor for expected results file
        integer code;               // Return code of $fgets
        // reg [ADDR_WIDTH-1:0] addr;      // Variables for expected data address and value
        reg [DATA_WIDTH-1:0] data;      // Variables for expected data address and value
        parameter int MAX_LINE_LENGTH = 8; // Adjust as needed
        reg [8*MAX_LINE_LENGTH-1:0] line; // Line buffer as a reg array

        bit exit_loop;          // Flag to control loop exit
        reg [DATA_WIDTH-1:0] hex_value;
        begin
            exit_loop = 0;
            $display("\n\n----------------- read_expected_results_from_file ----------------------------");
            $display("Starting read_expected_results_from_file for file: %s", filename);

            // Attempt to open the file in read mode
            expected_file = $fopen(filename, "r");

            if (expected_file == 0) begin
                $display("Error: Cannot open %s", filename);  // Display error if file cannot be opened
                $finish;  // Terminate simulation
            end
            $display("File opened successfully.");

            expected_result_count = 0;

            // Begin reading lines
            $display("Beginning file read loop...");
            while (!$feof(expected_file) && !exit_loop) begin

                // Clear the line buffer
                line = {8*MAX_LINE_LENGTH{1'b0}};

                // Read a line from the file
                code = $fgets(line, expected_file);
                // // Parse the line for address and data
                // // code = $sscanf(line, "@%h %h", addr, data);
                // code = $sscanf(line, "@%h", data);

                // if (code == 0) begin
                //     $display("Warning: fgets failed at line %0d", expected_result_count + 1);
                //     exit_loop = 1;
                // end

                // Ignore empty lines or newline-only entries
                if (line == "\n") begin
                    $display(""); // Skip to the next line
                end else begin
                    $display("At line %0d -> Raw line read: %s", expected_result_count, line);
                    $sscanf(line, "%h", hex_value);

                    // Store address and data in arrays
                    // expected_addresses[expected_result_count] = addr;
                    expected_addresses[expected_result_count] = expected_result_count;
                    expected_data_array[expected_result_count] = hex_value;
                    // $display("Stored expected result at index %0d: addr = %h, data = %h", expected_result_count, addr, data);
                    $display("Stored expected result at index %0d: data = %h", expected_result_count, hex_value);

                    // Increment expected results count
                    expected_result_count = expected_result_count + 1;

                    // Optional limit for debugging
                    if (expected_result_count >= 48) begin
                        $display("Reached maximum expected result limit of %0d.", 48);
                        exit_loop = 1;
                    end
                end
            end
            

            // Close the expected results file after reading
            $fclose(expected_file);
            $display("File closed successfully.");

            // Display the number of expected results loaded
            $display("Loaded %0d expected results from %s.", expected_result_count, filename);
        end
    endtask

    // Task to Test Memory Read and Write via UART
    task test_memory(
        input logic select_mem,  // Input parameter to select the memory
        input [ADDR_WIDTH-1:0] first_address = 32'hA0000002,
        input [ADDR_WIDTH-1:0] first_data_value = 32'hF0000093,
        input [10:0] iterations,
        input logic debug
    );
        integer it;
        reg [ADDR_WIDTH-1:0] test_address;
        reg [DATA_WIDTH-1:0] expected_data;
        reg [DATA_WIDTH-1:0] read_data;

        begin
            // Set the memory selection signal
            i_select_mem = select_mem;  // 0 for Instruction Memory, 1 for Data Memory

            step = step + 1;
            $display("\n\n====================================================");
            // --------------------------------------------
            // Test 1: Write Data to Memory via UART and Verify
            // --------------------------------------------

            test_address  = 32'hF000008C;  // Starting address for the test
            expected_data = 32'hDEADBEEF;  // Test data

            // Write Data to Memory via UART and Wishbone
            test_write_to_memory(test_address, expected_data, debug);

            #(WAIT_BETWEEN_STEPS);
            step = step + 1;

            $display("\n\n --------------------------------------------");
            if (select_mem == 0) begin
                $display("\n Test 1: Writing Data to Instruction Memory via UART...");
            end else begin
                $display("\n Test 1: Writing Data to Data Memory via UART...");
            end
            $display(" --------------------------------------------");

            test_address  = 32'hF0000088;  // Another test address
            expected_data = 32'hD00DB00F;  // Another test data

            // Write Data to Memory via UART and Wishbone
            $display("\n Test 1: Writing Data to Memory...");
            test_write_to_memory(test_address, expected_data, debug);
            
            #(WAIT_BETWEEN_STEPS);
            step = step + 1;

            // ----------------
            test_address  = first_address;  // Starting address for recursive test
            expected_data = first_data_value;  // Example instruction (e.g., NOP in RISC-V)
            #50;

            // Send multiple instructions to Memory
            $display("\n Test 1: Writing Data to Memory recursively");
            for (it = 0; it < iterations; it = it + 1) begin
                if (debug) begin
                    $display("\n Test 1: [%1d] Sending to addr: %h the data: %h", it, test_address + (it*4), expected_data + it);
                    $display("\n  data: %h", expected_data + it);
                end
                    
                step = step + 1;
                // test_write_to_memory(test_address + it, expected_data + it);
                test_write_to_memory(test_address + it, expected_data + it, debug);
                if (debug) begin
                    $display(" Test 1: [%1d] Completed write iteration", it);
                end
                    
            end

            #(5 * WAIT_BETWEEN_STEPS);
            step = step + 1;

            $display("\n\n --------------------------------------------");
            if (select_mem == 0) begin
                $display(" Test 2: Reading Data from Instruction Memory via UART...");
            end else begin
                $display(" Test 2: Reading Data from Data Memory via UART...");
            end
            $display(" --------------------------------------------");
            for (it = 0; it < iterations; it = it + 1) begin
                // test_read_from_memory(test_address + it, read_data);
                test_read_from_memory(test_address + it, read_data, debug);
                if (debug) begin
                    $display("\nTest 2: [%1d] Read from addr: %h the data: %h", it, test_address + it, read_data);
                end
                    
                // compare_memory_data(test_address + it, read_data); // Compare with expected data
                compare_memory_data(test_address + it, read_data, debug); // Compare with expected data
            end
            // if (test_passed == 0) begin
            //     $finish;
            // end
        end
    endtask

    // Task to Test Memory Read and Write via UART
    task reset_memory(
        input logic select_mem,  // Input parameter to select the memory
        input [ADDR_WIDTH-1:0] first_address = 32'h00000000,
        input [ADDR_WIDTH-1:0] reset_value = 32'hF0000033,
        input logic debug
    );
        integer it;
        reg [ADDR_WIDTH-1:0] test_address;
        reg [DATA_WIDTH-1:0] expected_data;
        reg [DATA_WIDTH-1:0] read_data;
        integer iterations;

        begin
            // Set the memory selection signal
            i_select_mem = select_mem;  // 0 for Instruction Memory, 1 for Data Memory

            step = step + 1;
            $display("\n\n====================================================");
            $display("\n\n --------------------------------------------");
            if (select_mem == 0) begin
                $display("\n Reset task: Reseting Instruction Memory via UART...");
                iterations = INST_MEM_WORDS;
            end else begin
                $display("\n Reset task: Reseting Data Memory via UART...");
                iterations = DATA_MEM_WORDS;
            end
            $display(" --------------------------------------------");

            test_address  = 32'hF0000088;  // Another test address
            expected_data = 32'hD00DB00F;  // Another test data

            // Write Data to Memory via UART and Wishbone
            $display("\n Reset task: Writing Data to Memory...");
            test_write_to_memory(test_address, expected_data, debug);
            
            #(WAIT_BETWEEN_STEPS);
            step = step + 1;

            // ----------------
            test_address  = first_address;  // Starting address for recursive test
            expected_data = reset_value;  // Example instruction (e.g., NOP in RISC-V)
            #50;

            
            // Send multiple instructions to Memory
            $display("\n Reset task: Writing Data to Memory recursively");
            $display("\n Reset task: Sending to all addresses the data: %h", it, test_address, expected_data);
            for (it = first_address; it < iterations; it = it + 1) begin
                step = step + 1;
                // test_write_to_memory(test_address + it, expected_data + it);
                test_write_to_memory(test_address + (it *4), expected_data, debug);
                // $display(" Reset task: [%1d] Completed write iteration", it);
            end

            #(5 * WAIT_BETWEEN_STEPS);
            step = step + 1;

            $display("\n\n --------------------------------------------");
            if (select_mem == 0) begin
                $display(" Reset task: Reading Data from Instruction Memory via UART...");
            end else begin
                $display(" Reset task: Reading Data from Data Memory via UART...");
            end
            $display(" --------------------------------------------");
            for (it = first_address; it < iterations; it = it + 1) begin
                // test_read_from_memory(test_address + it, read_data);
                test_read_from_memory(test_address + (it*4), read_data, 0);
                // $display("\nReset task: [%1d] Read from addr: %h the data: %h", it, test_address + it, read_data);
                // compare_memory_data(test_address + it, read_data); // Compare with expected data
                compare_memory_data(test_address + (it*4), read_data, 0); // Compare with expected data
            end
            // if (test_passed == 0) begin
            //     $finish;
            // end
        end
    endtask


    // Task to Test Writing Data to Memory via UART
    task test_write_to_memory(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data, input logic debug = 1);
        begin
            // Send CMD_WRITE command
            uart_send_byte(CMD_WRITE);
            if (debug) begin $display("\nSent CMD_WRITE Command."); end
            #(WAIT_BETWEEN_UART_SEND_CMD);

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            
            if (debug) begin $display("Sent Address: 0x%08X", address); end

            // Send Data (LSB first)
            uart_send_word(data, DATA_WIDTH);
            if (debug) begin $display("Sent Data: 0x%08X", data); end
            

            // addr = address[MEM_ADDR_BITS-1:0];
            // ignoring unused MSB bits
            if (i_select_mem) begin
                tb_mem[address[DATA_MEM_ADDR_BITS-1:0]] = data;
                if (debug) begin
                    $display("tb_mem: Writing on addr: %h, the data:%h",address,data);
                    $display("tb_mem[%h]:%h",address[DATA_MEM_ADDR_BITS-1:0], tb_mem[address[DATA_MEM_ADDR_BITS-1:0]]);
                end
                    
            end else begin
                tb_mem[address[INST_MEM_ADDR_BITS-1:0]] = data;
                if (debug) begin
                    $display("tb_mem: Writing on addr: %h, the data:%h",address,data);
                    $display("tb_mem[%h]:%h",address[INST_MEM_ADDR_BITS-1:0], tb_mem[address[INST_MEM_ADDR_BITS-1:0]]);
                end
                    
            end

            // Wait for UART bridge to return to IDLE state
            wait (dut.U_UART_WB_BRIDGE.state == STATE_IDLE);
            #CLK_PERIOD;
        end
    endtask

    // Task to Test Reading Data from Memory via UART
    task test_read_from_memory(input [ADDR_WIDTH-1:0] address, output reg [DATA_WIDTH-1:0] data, input logic debug = 1);
        begin
            // Send CMD_READ command
            uart_send_byte(CMD_READ);
            if (debug) begin $display("Sent CMD_READ Command."); end
            #(WAIT_BETWEEN_UART_SEND_CMD);

            // Send Address (LSB first)
            uart_send_word2(address, ADDR_WIDTH);
            if (debug) begin $display("Sent Address: 0x%08X", address); end
            
            // Receive Data via UART
            uart_receive_word(data);
            if (debug) begin $display("Received Data: 0x%08X", data); end
            
        end
    endtask

    // Task to Send a Word via UART to DUT
    task uart_send_word(input [DATA_WIDTH-1:0] data, input integer width);
        integer byte_count;
        reg [7:0] byte_data;
        begin
            for (byte_count = 0; byte_count < (width / 8); byte_count = byte_count + 1) begin
                byte_data = data[8*byte_count+:8];  // Extract byte (LSB first)
                uart_send_byte(byte_data);
            end
        end
    endtask

    task uart_send_word2(input [DATA_WIDTH-1:0] data, input integer width);
        integer byte_count;
        reg [7:0] byte_data;
        begin
            for (byte_count = 0; byte_count < (width / 8); byte_count = byte_count + 1) begin
                byte_data = data[8*byte_count+:8];  // Extract byte (LSB first)
                uart_send_byte2(byte_data);
            end
        end
    endtask

    // Task to Send a Byte via UART to DUT
    task uart_send_byte(input [7:0] data);
        integer bit_idx;
        begin
            // Start Bit
            i_uart_rx = 0;
            #(BIT_PERIOD);

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                i_uart_rx = data[bit_idx];
                #(BIT_PERIOD);
            end

            // Stop Bit
            i_uart_rx = 1;
            #(BIT_PERIOD);

            // Wait a bit before next byte
            #(WAIT_BETWEEN_UART_SEND_BYTE);
        end
    endtask

        // Task to Send a Byte via UART to DUT
    task uart_send_byte2(input [7:0] data);
        integer bit_idx;
        begin
            // Start Bit
            i_uart_rx = 0;
            #(BIT_PERIOD);

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                i_uart_rx = data[bit_idx];
                #(BIT_PERIOD);
            end

            // Stop Bit
            i_uart_rx = 1;
            #(BIT_PERIOD);

            // Wait a bit before next byte
            // #(WAIT_BETWEEN_UART_SEND_BYTE);
        end
    endtask

    // Task to Receive a Word (multiple bytes) via UART from DUT
    task uart_receive_word(output reg [DATA_WIDTH-1:0] data);
        integer byte_count;
        reg [7:0] received_byte;
        begin
            data = 0;
            for (byte_count = 0; byte_count < (DATA_WIDTH / 8); byte_count = byte_count + 1) begin
                uart_capture_byte(received_byte);  // Call the task with output argument
                data = data | (received_byte << (8 * byte_count));
            end
        end
    endtask

    // Task to Capture a Byte Sent from DUT via UART
    task uart_capture_byte;
        output reg [7:0] data;  // Output for captured byte
        integer bit_idx;  // Loop index for capturing each bit
        begin
            // Wait for Start Bit
            wait (o_uart_tx == 0);
            #(BIT_PERIOD / 2);  // Sample in the middle of the start bit

            // Data Bits (LSB first)
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                #(BIT_PERIOD);
                data[bit_idx] = o_uart_tx;
            end

            // Stop Bit
            #(BIT_PERIOD);
        end
    endtask

    // Task to Compare Memory Data with Expected Values
    task compare_memory_data;
        input [ADDR_WIDTH-1:0] address;         // Address to read from memory
        input [DATA_WIDTH-1:0] read_data;       // Variable to hold read data
        input debug;
        reg [DATA_WIDTH-1:0] expected_value;    // Expected data to compare with (tb memory)
   
        begin
            // Read data from memory at the specified address
            expected_value = 0;
            #1;
            expected_value = tb_mem[address];

            // ignoring unused MSB bits
            if (i_select_mem) begin
                expected_value = tb_mem[address[DATA_MEM_ADDR_BITS-1:0]];
            end else begin
                expected_value = tb_mem[address[INST_MEM_ADDR_BITS-1:0]];
            end

            if (read_data !== expected_value) begin
                if (debug) begin
                    $display("ERROR: Memory Data Mismatch at address 0x%08X! Expected 0x%08X, Got 0x%08X", address, expected_value, read_data);
                end
                    
                test_passed = 0;
            end else begin
                if (debug) begin
                    $display("OK Data at address 0x%08X verified: 0x%08X", address, read_data);
                end
            end
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

endmodule
