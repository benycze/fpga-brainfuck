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

# Targets -----------------------------------------------------------------------

.PHONY: compile
compile: project
	quartus_sh --flow compile $(PROJECT_NAME)

.PHONY: project
project: $(PROJECT_NAME).qpf

%.qpf: 
%.qpf: fpga-brainfuck.tcl project-settings.tcl
	export QUARTUS_PROJECT_NAME=$(PROJECT_NAME); \
	export QUARTUS_OUTPUT_FOLDER=$(OUTPUT_FOLDER); \
	quartus_sh -t fpga-brainfuck.tcl

.PHONY: clean
clean:
	rm -rf db *.qpf *.qsf $(OUTPUT_FOLDER) *.qws incremental_db

