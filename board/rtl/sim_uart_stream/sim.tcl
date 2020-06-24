# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

set $PROJ_BASE "../.."

# Define the component list
set COMP_LIST [list \
    $PROJ_BASE/rtl_lib/vhdl-extras/rtl/extras/synchronizing.vhdl \
    $PROJ_BASE/rtl/uart_stream_sync.vhd \
]

# Create work library
vlib work
foreach cmp $COMP_LIST {
    vcom -2008 $cmp
}

# Load testbench
vsim work.uart_tb

# Setup and start simulation
#add wave *
add wave sim:/uart_tb/utt/*
run 200 us
