# Define DUTs and Testbenches
DUTS := uart_wbs_bridge osiris_i core

# Map DUTs to their testbenches
DUT_TO_TB.core =tb_core.sv
DUT_TO_TB.uart_wbs_bridge =tb_uart_wbs_bridge.v
DUT_TO_TB.osiris_i =tb_osiris_i.sv

# Paths
SCRIPTS_DIR =../scripts
TESTBENCH_DIR =../src
SIM_DIR =.
VCD_DIR =.
WAVEFORM_DIR =../waveform
# Add a source directory for your Verilog files
RTL_DIR =../../rtl

# Select the testbench based on the DUT
TESTBENCH =$(TESTBENCH_DIR)/$(DUT_TO_TB.$(DUT))
# Define the top module based on the testbench file name
TOP_MODULE = $(basename $(notdir $(TESTBENCH)))

VCD_FILE =$(VCD_DIR)/$(DUT).vcd

# Default DUT selection
DUT ?=core

# Executables and Compiler Choice
SIM_EXE  =sim_$(DUT)_simulation
# COMPILER ?=verilator# Default to Verilator
COMPILER ?=iverilog# Default to Verilator

# Help
help:
	@echo "####################################################"
	@echo " Available DUTs: $(DUTS)"
	@echo " Available Compilers: verilator (default), iverilog"
	@echo "   make gen_filelist DUT=<dut_name> COMPILER=<compiler_name> : Generate filelist.txt based on Verilog files."
	@echo "   make compile DUT=<dut_name> COMPILER=<compiler_name>     : Compile simulation for specified DUT with chosen compiler."
	@echo "   make run_sim DUT=<dut_name> COMPILER=<compiler_name>     : Compile and run simulation for specified DUT with chosen compiler."
	@echo "   make view_wave DUT=<dut_name>                            : Open GTKWave for specified DUT after running simulation."
	@echo "   make clean                                               : Clean files."
	@echo "####################################################"

# Filelist generation
gen_filelist:
	@$(SCRIPTS_DIR)/generate_filelist.sh $(DUT) $(COMPILER)

# Compile the simulation
compile: gen_filelist
	@echo "####################################################"
	@echo "Compiling simulation for $(DUT) using $(COMPILER)..."
	@if [ "$(COMPILER)" = "iverilog" ]; then \
		iverilog -g2012 -o $(TESTBENCH_DIR)/$(SIM_EXE) -f filelist.txt; \
	elif [ "$(COMPILER)" = "verilator" ]; then \
		#verilator --cc -f filelist.txt --exe $(TESTBENCH) --trace --build --top-module $(TOP_MODULE) -Wno-UNOPTFLAT --timing; \
		verilator --cc -f filelist.txt --exe $(TESTBENCH) --main --trace --build --top-module $(TOP_MODULE) -Wno-UNOPTFLAT --timing; \
	else \
		echo "Unsupported compiler: $(COMPILER). Use 'iverilog' or 'verilator'."; \
		exit 1; \
	fi
	exec mv $(TESTBENCH_DIR)/$(SIM_EXE) ../work
	@echo "Compilation finished for $(DUT) using $(COMPILER)."
	@echo "####################################################"

# Run the simulation after successful compilation
run_sim: compile
	@echo "####################################################"
	@echo "Running simulation for $(DUT) using $(COMPILER)..."
	@if [ "$(COMPILER)" = "iverilog" ]; then \
		vvp $(SIM_EXE); \
	elif [ "$(COMPILER)" = "verilator" ]; then \
		./obj_dir/V$(DUT); \
	else \
		echo "Unsupported compiler: $(COMPILER). Use 'iverilog' or 'verilator'."; \
		exit 1; \
	fi
	@echo "Simulation finished for $(DUT) using $(COMPILER)."
	@echo "####################################################"

# Open GTKWave if simulation is successful and the VCD file exists
view_wave:
	@echo "####################################################"
	@if [ -f $(VCD_FILE) ]; then \
		echo "Opening GTKWave for $(DUT)..."; \
		gtkwave $(VCD_FILE) $(WAVEFORM_DIR)/$(DUT)_waveform.gtkw; \
	else \
		echo "VCD file not found. Make sure simulation ran successfully."; \
	fi
	@echo "####################################################"

# Clean simulation files
clean:
	@echo "####################################################"
	@rm -f $(SIM_EXE) $(DUT).vcd filelist.txt
	@rm -rf obj_dir/  # Clean Verilator's generated files
	@echo "Cleaned all simulation files."
	@echo "####################################################"

# Default rule to show help
.DEFAULT_GOAL := help
