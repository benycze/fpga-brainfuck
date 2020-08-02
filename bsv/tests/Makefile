# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

# Overwrite variables defined insde the common file 
# We need to reach temporal files and BSV sources from this directory
BUILD_BSIM_FOLDER = ../build
BUILD_VERILOG_FOLDER = ../build_verilog
BCPU_SRC = ../src

include ../Common_Inc.mk

# -------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------

default: test_all vtest_all

# How to create a test:
# 1] Create a test (BSV file) - the name of the top module should have a pattern mkFILENAME. 
#    For example, if the file is named TbFoo --> top module name has to be mkTbFoo
# 2] Create two targets (sim_NAME and vsim_NAME) and add them to the .PHONY section
#    The name is taken from the Test name. Therefore, for the previous example we get 
#    vsim_TbFoo and sim_TbFoo
# 3] Add the new tests to the test_all and vtest_all targets
# 
# That is all folks! The rest of the translation is handled by the general csim_% and cvsim_% 
# targets.

.PHONY: sim_tbAddr vsim_TbAddr
sim_TbAddr: TbAddr.bsv csim_TbAddr
vsim_TbAddr: TbAddr.bsv cvsim_TbAddr

.PHONY: sim_TbInst vsim_TbInst
sim_TbInst: TbInst.bsv csim_TbInst
vsim_TbInst: TbInst.bsv cvsim_TbInst

# General bluespec targets ---------------------------------------------

# Brainfuck compiler and general target for the program translation
BCC=python3 -B /sw/compiler/compiler.py

# The following target generates a MIF file from the current source code
# using the current compiler which is mounted to the /sw folder inside the container
#
# All you have to do is to add the dependency to the file like this:
# 
# abc: data/ptr_inc/ptr_inc.mif
#
%.mif: %.b
	@echo "Translating the $@ file ..."
	$(BCC) --memory --output $* $<

csim_%: %.bsv
	@echo "Translating the sources ..."
	$(MAKE) -C .. compile
	@echo "INFO: linking bsc-compiled objects into Bluesim executable"
	bsc -u -elab -sim $(BSC_ARGS) $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $<
	bsc -sim -parallel-sim-link 4 $(BSC_ARGS) -e mk$* -o ./$@.exe $(BSC_C_FLAGS) 
	@echo "Running the simulation (Bluespec) ..."
	./$@.exe

cvsim_%: %.bsv
	@echo "Translating the sources ..."
	$(MAKE) -C .. vcompile
	@echo "Compiling the verilog model and simulator ..."
	bsc -u -elab -verilog  $(BSC_ARGS) $(VERILOG_BSC_ARGS)  $(BSC_COMPILATION_FLAGS) -p $(BSC_PATH)  $<
	bsc -verilog $(BSC_ARGS) -remove-dollar -vsearch $(VERILOG_PATH) -e mk$* -o ./$@.exe
	@echo "Running the simulation (Verilog) ..."
	./$@.exe

# Run all available tests -------------------------------------------

.PHONY: vtest_all
vtest_all: vsim_TbAddr vsim_TbInst

.PHONY: test_all
test_all: sim_TbAddr sim_TbInst

.PHONY: clean
clean:
	@echo "Cleaning generated files ..."
	@for f in $(shell ls data); do \
	echo " * cleaning the $${f} folder"; \
	rm -f data/$${f}/$${f}.mif data/$${f}/$${f}; \
	done

	@echo "Cleaning directory ..."
	rm -f *.so *.exe
