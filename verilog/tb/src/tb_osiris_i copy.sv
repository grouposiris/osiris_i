`timescale 1ns / 1ps

module osiris_i_tb;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter INST_MEM_SIZE = 4;  // in KB
    parameter DATA_MEM_SIZE = 4;  // in KB

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

    // Monitor changes in the first 16 elements
    always @(dut.U_INST_MEM.mem[0] or dut.U_INST_MEM.mem[1] or dut.U_INST_MEM.mem[2] or dut.U_INST_MEM.mem[3] or dut.U_INST_MEM.mem[4] or dut.U_INST_MEM.mem[5] or dut.U_INST_MEM.mem[6] or dut.U_INST_MEM.mem[7] or dut.U_INST_MEM.mem[8] or dut.U_INST_MEM.mem[9] or dut.U_INST_MEM.mem[10] or dut.U_INST_MEM.mem[11] or dut.U_INST_MEM.mem[12] or dut.U_INST_MEM.mem[12] or dut.U_INST_MEM.mem[14] or dut.U_INST_MEM.mem[15]) begin
        for (j = 0; j < 16; j = j + 1) begin
            if (dut.U_INST_MEM.mem[j] !== mem_prev[j]) begin
                $display("At time %t: mem[%0d] changed from %h to %h", $time, j, tb_mem[j], dut.U_INST_MEM.mem[j]);
                // $display("At time %t: mem[%0d] changed to %h", $time, j, dut.U_INST_MEM.mem[j]);
                mem_prev[j] = dut.U_INST_MEM.mem[j];  // Update previous value to the new one
            end
        end
    end
    // ------------------------

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
        #50000 $display("finish prevent"); $finish;
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
    integer step; // tb variable just to simulation organization

    // Arrays to Store Instructions and Expected Results
    reg [31:0] instruction_mem[0:255];
    reg [31:0] instruction_addresses[0:255];
    integer num_instructions;

    reg [31:0] expected_data_array[0:255];
    reg [31:0] expected_addresses[0:255];
    integer expected_result_count;

    // File for Writing Outputs
    integer output_file;
    integer it;


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
            for (k = 0; k < DATA_MEM_WORDS; k++) begin
                always @(dut.U_DATA_MEM.mem[k]) begin
                    $display("Time %0t ps: Data Memory [%0d]= [%b] changed to %d<<<--- =%b =%h\n\n", $time, k, k, dut.U_DATA_MEM.mem[k],dut.U_DATA_MEM.mem[k],dut.U_DATA_MEM.mem[k]);
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


    // // Simulate fetching instructions
    //     // Memory reads are asynchronous
    //     always @(*) begin
    //         if (!rst_core) begin
    //             // if (dut.U_CORE.i_instr_ID!= 0) begin
    //                 dut.U_CORE.i_instr_ID = mem_instr[dut.core_pc_IF[INST_MEM_ADDR_BITS-1:0]];
    //                 // $display("->Time %0t ps: Instruction Fetch: PC = %d, Instruction = %h, Assembly: %s", $time, dut.core_pc_IF, dut.U_CORE.i_instr_ID, decode_instruction(dut.U_CORE.i_instr_ID));
    //                 $display("->Time %0t ps: Instruction Fetch: PC[%d], Instruction = %h, Assembly: %s --------------", $time, dut.core_pc_IF, dut.U_CORE.i_instr_ID, decode_instruction(dut.U_CORE.i_instr_ID));
    //             // end
    //             // decoded_inst = decode_instruction(dut.U_CORE.i_instr_ID);
    //         end else begin
    //             dut.U_CORE.i_instr_ID = {DATA_WIDTH{1'b1}};
    //             //$display("Time %0t ps: Instruction Fetch: PC[%h], Instruction = %h, Assembly: %s", $time, dut.core_pc_IF, dut.U_CORE.i_instr_ID, decode_instruction(dut.U_CORE.i_instr_ID));
    //             // decoded_inst = decode_instruction(dut.U_CORE.i_instr_ID);
    //         end
    //     end





    // Main Test Sequence
    initial begin
        test_passed = 1;
        rst_core = 1;
        step = 0;

        $display("Starting osiris_i Testbench...");
        #200;  // Wait for reset to deassert

        test_memory(i_select_mem, 32'h00000000, 32'hBEE00000);
        i_select_mem = 1;
        test_memory(i_select_mem, 32'hF0000007, 32'hBAA00000);

        // =========================================================================
        #(WAIT_BETWEEN_STEPS);
        $display("\n\n --------------------------------------------");
        $display(" Test 5: Run Program on Core and Verify Result in Data Memory ");
        $display(" --------------------------------------------");
        step = 0;
        i_select_mem = 0;  // Select Instruction Memory
        rst_mem_uart = 1;
        #(CLK_PERIOD);
        rst_mem_uart = 0;
        #(10* CLK_PERIOD);

        // Reading Instructions from File
        $display("Reading instructions from inst_hex.txt...");
        num_instructions = 0;
        read_instructions_from_file("../src/inst_hex.txt");

        #(WAIT_BETWEEN_STEPS) step = 1;
        // Loading Instructions into Instruction Memory
        $display("Loading instructions into Instruction Memory...");
        for (it = 0; it < num_instructions; it = it + 1) begin
            $display("\n Test 5: [%1d] Sending to addr: %h the data: %h = %s", it, instruction_addresses[it], instruction_mem[it], decode_instruction(instruction_mem[it]));
            step = step + 1;
            test_write_to_memory(instruction_addresses[it], instruction_mem[it]);
        end


        #(5 * WAIT_BETWEEN_STEPS);
        step = 1;

        $display("\n\n --------------------------------------------");
        if (i_select_mem == 0) begin
            $display(" Test 5: Reading Data from Instruction Memory via UART...");
        end else begin
            $display(" Test 5: Reading Data from Data Memory via UART...");
        end
        $display(" --------------------------------------------");
        for (it = 0; it < num_instructions; it = it + 1) begin
            test_read_from_memory(instruction_addresses[it], read_data);
            $display("\nTest 5: [%1d] Read from addr: %h the data: %h", it, instruction_addresses[it], read_data);
            compare_memory_data(instruction_addresses[it], read_data); // Compare with expected data
        end


        // OK todo: separate reset signal to memories
        // todo: core clock-gating when UART accesses memories
        // todo: add PDK memories
        
        // todo: check if addressing would be by bytes or not

        // todo: confimacao da UART em que estado estah 
        //      jgoar bits estado para fora ou bit
        // todo: x- confirmacao da memoria que foi escrito

        #(50000 * CLK_PERIOD);  // Wait for core to execute instructions

        // Release Core Reset and Start Execution
        #(WAIT_BETWEEN_STEPS);
        i_start_rx = 0;  // Disable UART reception
        #(50* CLK_PERIOD);
        step = 2;
        rst_core = 0; // Activate core
        #(50000 * CLK_PERIOD);  // Wait for core to execute instructions

        step = 3;
        i_start_rx = 1;  // Enable UART reception
        rst_core = 1; // disable core
        #(10* CLK_PERIOD);

        // Reading Expected Results from File
        $display("Reading expected results from store_expected.txt...");
        expected_result_count = 0;
        read_expected_results_from_file("../src/store_expected.txt");

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

        // Final Test Result
        if (test_passed) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\nError: Some tests FAILED.");
        end

        #10000 $finish;
    end

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
                        $display("At line %0d -> Raw line read: %s = %s", num_instructions, line, decode_instruction(line));
                        $sscanf(line, "%h", hex_value);

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
        input [ADDR_WIDTH-1:0] first_data_value = 32'hF0000093
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
            test_write_to_memory(test_address, expected_data);

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
            test_write_to_memory(test_address, expected_data);
            
            #(WAIT_BETWEEN_STEPS);
            step = step + 1;

            // ----------------
            test_address  = first_address;  // Starting address for recursive test
            expected_data = first_data_value;  // Example instruction (e.g., NOP in RISC-V)
            #50;

            // Send multiple instructions to Memory
            $display("\n Test 1: Writing Data to Memory recursively");
            for (it = 0; it < 10; it = it + 1) begin
                $display("\n Test 1: [%1d] Sending to addr: %h the data: %h", it, test_address + it, expected_data + it);
                step = step + 1;
                test_write_to_memory(test_address + it, expected_data + it);
                $display(" Test 1: [%1d] Completed write iteration", it);
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
            for (it = 0; it < 10; it = it + 1) begin
                test_read_from_memory(test_address + it, read_data);
                $display("\nTest 2: [%1d] Read from addr: %h the data: %h", it, test_address + it, read_data);
                compare_memory_data(test_address + it, read_data); // Compare with expected data
            end
        end
    endtask

    // Task to Test Writing Data to Memory via UART
    task test_write_to_memory(input [ADDR_WIDTH-1:0] address, input [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_WRITE command
            uart_send_byte(CMD_WRITE);
            $display("\nSent CMD_WRITE Command.");
            #(WAIT_BETWEEN_UART_SEND_CMD);

            // Send Address (LSB first)
            uart_send_word(address, ADDR_WIDTH);
            $display("Sent Address: 0x%08X", address);

            // Send Data (LSB first)
            uart_send_word(data, DATA_WIDTH);
            $display("Sent Data: 0x%08X", data);

            // addr = address[MEM_ADDR_BITS-1:0];
            // ignoring unused MSB bits
            if (i_select_mem) begin
                tb_mem[address[DATA_MEM_ADDR_BITS-1:0]] = data;
                $display("tb_mem: Writing on addr: %h, the data:%h",address,data);
                $display("tb_mem[%h]:%h",address[DATA_MEM_ADDR_BITS-1:0], tb_mem[address[DATA_MEM_ADDR_BITS-1:0]]);
            end else begin
                tb_mem[address[INST_MEM_ADDR_BITS-1:0]] = data;
                $display("tb_mem: Writing on addr: %h, the data:%h",address,data);
                $display("tb_mem[%h]:%h",address[INST_MEM_ADDR_BITS-1:0], tb_mem[address[INST_MEM_ADDR_BITS-1:0]]);
            end

            // Wait for UART bridge to return to IDLE state
            wait (dut.U_UART_WB_BRIDGE.state == STATE_IDLE);
            #CLK_PERIOD;
        end
    endtask

    // Task to Test Reading Data from Memory via UART
    task test_read_from_memory(input [ADDR_WIDTH-1:0] address, output reg [DATA_WIDTH-1:0] data);
        begin
            // Send CMD_READ command
            uart_send_byte(CMD_READ);
            $display("Sent CMD_READ Command.");
            #(WAIT_BETWEEN_UART_SEND_CMD);

            // Send Address (LSB first)
            uart_send_word2(address, ADDR_WIDTH);
            $display("Sent Address: 0x%08X", address);

            // Receive Data via UART
            uart_receive_word(data);
            $display("Received Data: 0x%08X", data);
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
                $display(
                    "ERROR: Memory Data Mismatch at address 0x%08X! Expected 0x%08X, Got 0x%08X",
                    address, expected_value, read_data);
                test_passed = 0;
            end else begin
                $display("OK Data at address 0x%08X verified: 0x%08X", address, read_data);
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
