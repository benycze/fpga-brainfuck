# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
#--------------------------------------------------------------------------------

# Inspired by the: https://github.com/bluespec/Piccolo/blob/master/builds/Resources/Include_bluesim.mk
# and https://github.com/bluespec/Piccolo/blob/master/builds/Resources/Include_Common.mk

include Common_Inc.mk

# Setup the new top level (for compilation)
TOPFILE = src/bcpu.bsv
TOPMODULE = mkBCpu

# -------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------

all: compile

build:
	mkdir -p $@

build_verilog:
	mkdir -p $@

.PHONY: compile
compile: $(BUILD_BSIM_FOLDER)
	@echo "Compiling the BSV design ..."
	bsc -u -elab -sim $(BSC_ARGS)  $(BSC_COMPILATION_FLAGS)  -p $(BSC_PATH)  $(TOPFILE)

.PHONY: vcompile
vcompile: $(BUILD_BSIM_FOLDER) $(BUILD_VERILOG_FOLDER)
	@echo "Compiling the Verilog design ..."
	bsc -u -elab -verilog  $(BSC_ARGS) $(VERILOG_BSC_ARGS)  $(BSC_COMPILATION_FLAGS) -p $(BSC_PATH)  $(TOPFILE)

.PHONY: test
test: 
	@echo "Running the simulation (Bluespec) ..."
	$(MAKE) -C tests test_all

.PHONY: vtest
vtest: 
	@echo "Running the simulation (Bluespec) ..."
	$(MAKE) -C tests vtest_all

.PHONY: clean
clean:
	rm -rf build
	rm -rf build_verilog
	rm -rf tarball
	$(MAKE) -C tests clean

.PHONY: tarball
# Blaclisted files are divided by , (comma)
tarball: DSTDIR=$@ 
tarball: LIBDIR=$@/lib
tarball: BLACKLISTED_LIB_FILES=Bluespec.xcf main.v
tarball: vcompile 
	@echo "Removing and building the tarball again ..."
	rm -rf $(DSTDIR)
	mkdir -p $(LIBDIR)
	@echo "Copy all verilog files ..."
	cp build_verilog/*.v $(DSTDIR)
	@echo "Copy the verilog library from the Bluespec ..."
	cp /lib/Verilog/* $(LIBDIR)
	cp -f /lib/Verilog.Quartus/* $(LIBDIR)
	@echo "Cleaning blaclisted files"
	for file in $(BLACKLISTED_LIB_FILES); do \
		rm -f $(LIBDIR)/$$file; \
	done

.PHONY: help
help:
	@echo "This Makefile has following targets:"
	@echo "* compile 	compiles the Bluespec simulation model"
	@echo "* vcompile 	compiles the Verilog code"
	@echo "* test		runs all tests using Bluespec simulator"
	@echo "* vtest		runs all tests using Verilog simulation model"
	@echo "* clean		clean everything" 
	@echo "* tarball    create a package for translation"
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

