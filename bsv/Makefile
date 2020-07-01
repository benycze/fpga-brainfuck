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
TOPFILE = "Tb.bsv"
TOPMODULE = mkTb
# Configuration of the compiler search paths
BCPU_SRC="src"

BSC_PATH = $(BCPU_SRC):+

# Configuration fo temporal directories
TMP_DIRS  = -bdir build  -simdir build  -info-dir build -show-compiles -show-elab-progress -show-schedule -show-stats

# Name of the output executable file
SIM_EXE_FILE = "bcpu_tb.exe"

# Flags for the CPP compile r
BSC_C_FLAGS += -Xl -v -Xc -O3 -Xc++ -O3

# -------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------

all: compile simulator

build:
	mkdir -p $@

.PHONY: compile
compile: build
	@echo "Compiling the BSV design ..."
	bsc -u -elab -sim  $(TMP_DIRS)  $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $(TOPFILE)


.PHONY: simulator
@echo "INFO: linking bsc-compiled objects into Bluesim executable"
	bsc -sim -parallel-sim-link 4 $(TMP_DIRS) -e $(TOPMODULE) -o ./$(SIM_EXE_FILE) $(BSC_C_FLAGS) 
	#$(REPO)/src_Testbench/Top/C_Imported_Functions.c

#.PHONY: test
#test: compile
