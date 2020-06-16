
# Clocks
create_clock -name CLK -period 83.333 [get_ports {CLK}]

derive_pll_clocks
derive_clock_uncertainty

# Reset doesn't need to be constrained because it is a button which is passed to the 
# reset synchronizers
set_false_path -from [get_ports {RESET_BTN_N}] -to *

# Setup input and output constraints
set_output_delay -clock { CLK } -max 1.5 [get_ports {UART_TXD}]
set_output_delay -clock { CLK } -min -1 [get_ports {UART_TXD}]