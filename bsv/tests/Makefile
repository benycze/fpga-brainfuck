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

# Test rusult log & translation log
TEST_LOG=TEST_RESULT.log
LOG_FILE=BSV-TRANSLATION.log

include ../Common_Inc.mk

# -------------------------------------------------------------------------------
# Macros 
# -------------------------------------------------------------------------------

# Macro which starts the Bluespec simulation and checks the result. This
# is a small hack because the Bluespec binary is not returning the code pased
# to $finish function.
define run_and_check
	@echo "Starting the test ..."
	./$(strip $(1)) | tee $(TEST_LOG)
	if [ `grep -c 'RESULT=  *0' TEST_RESULT.log` -ne 1 ]; then \
 		exit 1; \
	fi 
endef

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
#
# IMPORTANT: EACH TB SHOULD USE THE report_and_stop FUNCTION FROM THE TbCommon PACKAGE BECAUSE
# THE MAKEFILE IS USING THE PRINTED STRING FOR DECISION ABOUT THE TEST RESULT (SEE THE 
# run_and_check MACRO FOR MORE DETAILS)

.PHONY: sim_tbAddr vsim_TbAddr
sim_TbAddr: clean_log TbAddr.bsv csim_TbAddr
vsim_TbAddr: clean_log TbAddr.bsv cvsim_TbAddr

.PHONY: sim_TbInst vsim_TbInst
sim_TbInst: TbInst.bsv csim_TbInst
vsim_TbInst: TbInst.bsv cvsim_TbInst

# Tests of the compiler programs inside the BCpu, each target translates the
# MIF file which belongs to the test. The translation target with b_* also 
# modifies the argument to point on translated  file. So, each target created
# as usual + the b_* target which poins to a file.

.PHONY: sim_TbPtrInc vsim_TbPtrInc b_TbPtrInc
sim_TbPtrInc:  b_TbPtrInc TbPrgRun.bsv csim_TbPrgRun
vsim_TbPtrInc:  b_TbPtrInc TbPrgRun.bsv cvsim_TbPrgRun
b_TbPtrInc: data/ptr_inc/ptr_inc.hex
	$(eval BSC_ARGS += -D HEX_FILE=\"$(notdir $<)\" -D PRG_FOLDER=\"$(dir $<)\")

.PHONY: sim_TbMorePtrInc vsim_TbMorePtrInc b_TbMorePtrInc
sim_TbMorePtrInc:  b_TbMorePtrInc TbPrgRun.bsv csim_TbPrgRun
vsim_TbMorePtrInc: b_TbMorePtrInc TbPrgRun.bsv cvsim_TbPrgRun
b_TbMorePtrInc: data/more_ptr_inc/more_ptr_inc.hex
	$(eval BSC_ARGS += -D HEX_FILE=\"$(notdir $<)\" -D PRG_FOLDER=\"$(dir $<)\")

.PHONY: sim_TbPtrDec vsim_TbPtrDec b_TbPtrDec
sim_TbPtrDec: b_TbPtrDec TbPrgRun.bsv csim_TbPrgRun 
vsim_TbPtrDec: b_TbPtrDec TbPrgRun.bsv cvsim_TbPrgRun
b_TbPtrDec: data/ptr_dec/ptr_dec.hex
	$(eval BSC_ARGS += -D HEX_FILE=\"$(notdir $<)\" -D PRG_FOLDER=\"$(dir $<)\")

.PHONY: sim_TbPtrInc2 vsim_TbPtrInc2 b_TbPtrInc2
sim_TbPtrInc2:  b_TbPtrInc2 TbPrgRun.bsv csim_TbPrgRun
vsim_TbPtrInc2:  b_TbPtrInc2 TbPrgRun.bsv cvsim_TbPrgRun
b_TbPtrInc2: data/ptr_inc2/ptr_inc2.hex
	$(eval BSC_ARGS += -D HEX_FILE=\"$(notdir $<)\" -D PRG_FOLDER=\"$(dir $<)\")

# General bluespec targets ---------------------------------------------

# Brainfuck compiler and general target for the program translation
BCC=python3 -B /sw/compiler/compiler.py

# The following target generates a HEX file from the current source code
# using the current compiler which is mounted to the /sw folder inside the container
#
# All you have to do is to add the dependency to the file like this:
# 
# abc: data/ptr_inc/ptr_inc.hex
#
# The test also sets the BSC flag for the BSC compiler
%.hex: %.b
	@echo "Translating the $@ file ..."
	$(BCC) --memory --output $* $<

csim_%: %.bsv
	@echo "Translating the sources (BSC)..."
	$(MAKE) -C .. compile
	@echo "INFO: linking bsc-compiled objects into Bluesim executable"
	bsc -u -elab -sim $(BSC_ARGS) $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $<  > $(LOG_FILE) 2>&1 
	bsc -sim -parallel-sim-link 4 $(BSC_ARGS) -e mk$* -o ./$@.exe $(BSC_C_FLAGS) > $(LOG_FILE) 2>&1 
	@echo "Running the simulation (Bluespec) ..."
	$(call run_and_check, $@.exe )

cvsim_%: %.bsv
	@echo "Translating the sources (BSC) ..."
	$(MAKE) -C .. vcompile
	@echo "Compiling the verilog model and simulator ..."
	bsc -u -elab -verilog $ $(BSC_ARGS) $(VERILOG_BSC_ARGS)  $(BSC_COMPILATION_FLAGS) -p $(BSC_PATH)  $< > $(LOG_FILE) 2>&1 
	bsc -verilog $(BSC_ARGS) -remove-dollar -vsearch $(VERILOG_PATH) -e mk$* -o ./$@.exe > $(LOG_FILE) 2>&1 
	@echo "Running the simulation (Verilog) ..."
	$(call run_and_check, $@.exe )

# Run all available tests -------------------------------------------

.PHONY: test_all vtest_prg test_prg vtest_all clean clean_test clean_gen clean_log help 

# Test targets - there are test which has the stand-alone testbenches and some
# tests which are sharing the same testbench file (e.g. program tests). 
# 
# The program tests need to be added to corresponding TEST_PRGS or VTEST_PRGS
# variables.

# Test target variables
VTEST_TARGETS=vsim_TbAddr vsim_TbInst vtest_prg
VTEST_PRGS=vsim_TbPtrInc vsim_TbMorePtrInc vsim_TbPtrDec vsim_TbPtrInc2

vtest_all: $(VTEST_TARGETS)
vtest_prg:
	$(foreach TEST,$(VTEST_PRGS), \
		@echo "Starting test $(TEST) ... "; \
		$(MAKE) clean_test;\
		$(MAKE) $(TEST))


# Test variables
TEST_TARGETS=sim_TbAddr sim_TbInst test_prg 
TEST_PRGS=sim_TbPtrInc sim_TbMorePtrInc sim_TbPtrDec sim_TbPtrInc2

test_all: $(TEST_TARGETS)
test_prg:
	$(foreach TEST,$(TEST_PRGS), \
		@echo "Starting test $(TEST) ... "; \
		$(MAKE) clean_test;\
		$(MAKE) $(TEST);)

# Clean targets
clean_test:
	@echo "Cleaning simulator files ..."
	rm -f *.so *.exe
	@echo "Cleaning all generated files (just to be sure)"
	$(MAKE) -C .. clean_compiled

clean_gen:
	@echo "Cleaning generated files ..."
	@for f in $(shell find data/* -maxdepth 1 -type d); do \
	echo " * cleaning the $${f} folder"; \
	rm -f data/$${f}/$${f}.mif data/$${f}/$${f}; \
	done

clean_log:
	rm -f $(TEST_LOG)

clean: clean_test clean_gen clean_log

# Help target
help:
	@echo "Makefile targets:"
	@echo "* clean - cleans everything"
	@echo "* clean_test - cleans all test files"
	@echo "* clean_gen - cleans all generated files"
	@echo "* test_all - runs the test of all Bluespec simulation testbenches"
	@echo "		targets --> $(TEST_TARGETS)"
	@echo "* test_prg - runs all Brainfuck tests in Bluespec simulation environment"	
	@echo "		targets --> $(TEST_PRGS)"
	@echo "* vtest_all - runs the test of all Verilog simulation testbenches"
	@echo "		targets --> $(VTEST_TARGETS)"
	@echo "* vtest_prg - runs all Brainfuck tests in Verilog simulation environment"
	@echo "		targets --> $(VTEST_PRGS)"
