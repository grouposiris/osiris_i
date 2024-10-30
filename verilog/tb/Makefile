# Define DUTs and Testbenches
DUTS := uart_wbs_bridge osiris_i
TESTBENCHES := tb_uart_wbs_bridge.v tb_osiris_i.sv
VCD_FILES := uart_wbs_bridge.vcd osiris_i.vcd

# Default DUT selection
# DUT ?= uart_wbs_bridge
DUT ?= core
# DUT=uart_wbs_bridge
# DUT=core

# Paths
SIM_DIR = .
VCD_DIR = .

# Executables
SIM_EXE = sim_$(DUT)_simulation
VCD_FILE = $(VCD_DIR)/$(DUT).vcd

# Help
help:
	@echo "####################################################"
	@echo " Available DUTs: $(DUTS)"
	@echo "                  gen_filelist : generate filelist.txt based on Verilog files"
	@echo "   make compile DUT=<dut_name> : Compile simulation for specified DUT."
	@echo "   make run_sim DUT=<dut_name> : Compile and run simulation for specified DUT."
	@echo " make view_wave DUT=<dut_name> : Open GTKWave for specified DUT after running simulation."
	@echo "                    make clean : Clean files."
	@echo "####################################################"

# Filelist generation
gen_filelist:
	@./generate_filelist.sh $(DUT)

# Compile the simulation
compile: gen_filelist
	@echo "####################################################"
	@echo "Compiling simulation for $(DUT)..."
	iverilog -g2012 -o $(SIM_EXE) -f filelist.txt
	@echo "Compilation finished for $(DUT)."
	@echo "####################################################"

# Run the simulation after successful compilation
run_sim: compile
	@echo "####################################################"
	@echo "Running simulation for $(DUT)..."
	@vvp $(SIM_EXE)
	@echo "Simulation finished for $(DUT)."
	@echo "####################################################"

# Open GTKWave if simulation is successful and the VCD file exists
view_wave:
	@echo "####################################################"
	@if [ -f $(VCD_FILE) ]; then \
		echo "Opening GTKWave for $(DUT)..."; \
		gtkwave $(VCD_FILE); \
	else \
		echo "VCD file not found. Make sure simulation ran successfully."; \
	fi
	@echo "####################################################"

# Clean simulation files
clean:
	@echo "####################################################"
	@rm -f $(SIM_EXE) $(VCD_FILES) filelist.txt
	@rm -f sim_* *.vcd filelist.txt
	@echo "Cleaned all simulation files."
	tree -D ./
	@echo "####################################################"

# Default rule to show help
.DEFAULT_GOAL := help
