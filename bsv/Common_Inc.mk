# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------

# Configuration of the compiler search paths ()
BCPU_SRC ?= src
BUILD_BSIM_FOLDER ?= build
BUILD_VERILOG_FOLDER ?= build_verilog

# Setup search path
BSC_PATH = $(BCPU_SRC):+

# Configuration fo temporal directories
BSC_ARGS  += -bdir $(BUILD_BSIM_FOLDER)  -simdir $(BUILD_BSIM_FOLDER) \
			 -vdir $(BUILD_VERILOG_FOLDER) -vsearch $(BUILD_VERILOG_FOLDER) -info-dir $(BUILD_BSIM_FOLDER) \
			 -show-compiles -show-elab-progress -show-schedule -show-stats 

VERILOG_PATH = /lib/Verilog

# Flags for the CPP compiler
BSC_C_FLAGS += -Xl -v -Xc -O3 -Xc++ -O3

# Configuration of the compiler flags 
BSC_COMPILATION_FLAGS += -show-range-conflict

# Logging functionality
LOG_FILE=BSV-TRANSLATION.log

LOG ?= 0
LOG_CMD =
ifeq ($(LOG), 1)
	LOG_CMD = > $(LOG_FILE) 2>&1
endif