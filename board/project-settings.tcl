# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

# Source code #################################################################
set_global_assignment -name VHDL_FILE "rtl_lib/vhdl-extras/rtl/extras/synchronizing.vhdl"
set_global_assignment -name VHDL_FILE "rtl_lib/uart-for-fpga/rtl/comp/uart_tx.vhd"
set_global_assignment -name VHDL_FILE "rtl_lib/uart-for-fpga/rtl/comp/uart_rx.vhd"
set_global_assignment -name VHDL_FILE "rtl_lib/uart-for-fpga/rtl/comp/uart_parity.vhd"
set_global_assignment -name VHDL_FILE "rtl_lib/uart-for-fpga/rtl/comp/uart_debouncer.vhd"
set_global_assignment -name VHDL_FILE "rtl_lib/uart-for-fpga/rtl/comp/uart_clk_div.vhd"
set_global_assignment -name VHDL_FILE "rtl_lib/uart-for-fpga/rtl/uart.vhd"
set_global_assignment -name VHDL_FILE rtl/blink.vhd
set_global_assignment -name VHDL_FILE rtl_lib/asfifo.vhd
set_global_assignment -name VHDL_FILE "rtl/fpga-brainfuck.vhd"
set_global_assignment -name VHDL_FILE rtl/uart_stream_sync_pkg.vhd
set_global_assignment -name VHDL_FILE rtl/uart_stream_sync.vhd
set_global_assignment -name QIP_FILE ip/pll/pll.qip
set_global_assignment -name SDC_FILE constraints.sdc

# Pins  #####################################################################
set_location_assignment PIN_M2 -to CLK
set_location_assignment PIN_N6 -to RESET_BTN_N
set_location_assignment PIN_T7 -to UART_TXD
set_location_assignment PIN_R7 -to UART_RXD
set_location_assignment PIN_M6 -to LED_0
set_location_assignment PIN_T4 -to LED_1
set_location_assignment PIN_T3 -to LED_2
set_location_assignment PIN_R3 -to LED_3
set_location_assignment PIN_T2 -to LED_4
set_location_assignment PIN_R4 -to LED_5
set_location_assignment PIN_N5 -to LED_6
set_location_assignment PIN_N3 -to LED_7


