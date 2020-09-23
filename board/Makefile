# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

# Configuration  ----------------------------------------------------------------
PROJECT_NAME=fpga-brainfuck
OUTPUT_FOLDER=output_files
BCPU_PROJECT_PATH=../bsv


# Quartus PGM configuration
DEVICE ?= 1
SOF ?= ./output_files/fpga-brainfuck.sof

# Targets -----------------------------------------------------------------------

# Scan the folder for the content
BCPU_DIRS = $(shell find $(BCPU_PROJECT_PATH) -type d)
BCPU_FILES = $(shell find $(BCPU_PROJECT_PATH) -type f -name '*')

# Targets which are not creating any files
.PHONY: compile compile_only project clean run

compile: project compile_only

compile_only:
	quartus_sh --flow compile $(PROJECT_NAME)

project: $(PROJECT_NAME).qpf

run: compile
	@echo "Programming the device with generated SOF file ..."
	quartus_pgm --mode=jtag --device=$(DEVICE) --operation="p;$(SOF)"
	@echo 
	@echo "***********************************************"
	@echo "Done ..."
	@echo "***********************************************"


bcpu-sources.tcl: $(BCPU_PROJECT_PATH) $(BCPU_DIRS) $(BCPU_FILES)
	@echo "Translating the Bluespec code of the BCPU"
	bash -c "cd $(BCPU_PROJECT_PATH); ./start-container.sh --translate"		
	find $(BCPU_PROJECT_PATH)/tarball/ -type f -exec echo set_global_assignment -name VERILOG_FILE `pwd`/{} \; >> $@


%.qpf: bcpu-sources.tcl fpga-brainfuck.tcl project-settings.tcl
	export QUARTUS_PROJECT_NAME=$(PROJECT_NAME); \
	export QUARTUS_OUTPUT_FOLDER=$(OUTPUT_FOLDER); \
	quartus_sh -t fpga-brainfuck.tcl

clean:
	rm -rf db *.qpf *.qsf *.qws incremental_db 
	rm -rf bcpu-sources.tcl $(OUTPUT_FOLDER) 

