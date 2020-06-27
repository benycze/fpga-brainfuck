# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

# Clocks
create_clock -name CLK -period 83.333 [get_ports {CLK}]

derive_pll_clocks
derive_clock_uncertainty

# Reset doesn't need to be constrained because it is a button which is passed to the 
# reset synchronizers
set_false_path -from [get_ports {RESET_BTN_N}] -to *

# All LEDs are not interested about any timing
set_false_path -from * -to [get_ports {LED_*}]

# Constraint synchronizers - path to the first register is false, we don't want to analyze them
set_false_path -to [get_registers {reset_synchronizer:*|sr[1]}]
set_false_path -to [get_registers {*|bit_synchronizer:*|sr[1]}]

# Setup input and output constraints
set_output_delay -clock { CLK } -max 1.5 [get_ports {UART_TXD}]
set_output_delay -clock { CLK } -min -1 [get_ports {UART_TXD}]