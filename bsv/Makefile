# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

# Inspired by the: https://github.com/bluespec/Piccolo/blob/master/builds/Resources/Include_bluesim.mk
# and https://github.com/bluespec/Piccolo/blob/master/builds/Resources/Include_Common.mk

# -------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------

# Configuration of the compiler flags 
BSC_COMPILATION_FLAGS += -show-range-conflict
# Configuratio of the top-level file
TOPFILE = Tb.bsv
TOPMODULE = mkTb
# Configuration of the compiler search paths
BCPU_SRC=src

BSC_PATH = $(BCPU_SRC):+

# Configuration fo temporal directories
BSC_ARGS  += -bdir build  -simdir build -vdir build_verilog -vsearch build_verilog -info-dir build \
			-show-compiles -show-elab-progress -show-schedule -show-stats 

# Name of the output executable file
SIM_EXE_FILE ?= bcpu_tb.exe

# Flags for the CPP compiler
BSC_C_FLAGS += -Xl -v -Xc -O3 -Xc++ -O3

# -------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------

all: compile sim

build:
	mkdir -p $@

build_verilog:
	mkdir -p $@

.PHONY: compile
compile: build
	@echo "Compiling the BSV design ..."
	bsc -u -elab -sim $(BSC_ARGS)  $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $(TOPFILE)

vcompile: build build_verilog
	@echo "Compiling the Verilog design ..."
	bsc -u -elab -verilog  $(BSC_ARGS)  $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $(TOPFILE)

.PHONY: simulator
sim: compile
	@echo "INFO: linking bsc-compiled objects into Bluesim executable"
	bsc -sim -parallel-sim-link 4 $(BSC_ARGS) -e $(TOPMODULE) -o ./$(SIM_EXE_FILE) $(BSC_C_FLAGS) 

.PHONY: test
test: sim
	@echo "Running the simulation (Bluespec) ..."
	./$(SIM_EXE_FILE)

.PHONY: vsim
vsim: vcompile
	bsc -verilog $(BSC_ARGS) -e $(TOPMODULE) -o ./$(SIM_EXE_FILE)

.PHONY: vtest
vtest: vsim
	@echo "Running the simulation (Verilog) ..."
	./$(SIM_EXE_FILE)

.PHONY: test_all
test_all: test vtest


.PHONY: clean
clean:
	rm -rf build
	rm -rf build_verilog
	rm -rf *.so $(SIM_EXE_FILE)


.PHONY: help
help:
	@echo "This Makefile has following targets:"
	@echo "* compile 	compiles the Bluespec simulation model"
	@echo "* vcompile 	compiles the Verilog code"
	@echo "* sim 		generates the Bluespec simulation model (faster)"
	@echo "* vsim 		generates the Verilog simulation model (slower)"
	@echo "* test		runs the Bluespec simulator"
	@echo "* vtest		runs the Verilog simulation model"
	@echo "* test_all	runs both test (Bluespec and Verilog)"
	@echo "* clean		clean everything" 
	@echo ""
	@echo "The user can specify some additional parameters:"
	@echo ""
	@echo "* SIM_EXE_FILE 	name of the output file. The passed value overwrites the default one."
	@echo "		(default: $(SIM_EXE_FILE))"
	@echo ""
	@echo "* BSC_ARGS 	passed arguments are appended to following already defined arguments:"
	@echo "		$(BSC_ARGS)" 
	@echo ""
	@echo ""

