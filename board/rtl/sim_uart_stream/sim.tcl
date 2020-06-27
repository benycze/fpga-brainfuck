# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

# Define the component list

set PROJ_BASE "../.."
set TBENCH testbench.vhd

set COMP_LIST [list \
    $PROJ_BASE/rtl_lib/vhdl-extras/rtl/extras/synchronizing.vhdl \
    $PROJ_BASE/rtl_lib/vhdl-extras/rtl/extras/sizing.vhdl \
    $PROJ_BASE/rtl_lib/vhdl-extras/rtl/extras/memory.vhdl \
    $PROJ_BASE/rtl_lib/vhdl-extras/rtl/extras/fifos.vhdl \
    $PROJ_BASE/rtl/uart_stream_sync_pkg.vhd \
    $PROJ_BASE/rtl/handshake_rdy.vhd \
    $PROJ_BASE/rtl/uart_stream_sync.vhd \
]

# Create work library and map extras into the work directory, translate TBENCH
vlib work
vmap extras work

foreach cmp $COMP_LIST {
    vcom -2008 $cmp
}

vcom -2008 $TBENCH

# Dump the makefile
exec vmake > Makefile

# Load testbench
vsim work.testbench

# Setup and start simulation
add wave sim:/testbench/uut/*
add wave -group RX_HANDSHAKE_RDY sim:/testbench/uut/rx_handshake_rdy_i/*
run 20 us
