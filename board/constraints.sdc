
# Clocks
create_clock -name CLK -period 83.333 [get_ports {CLK}]

derive_pll_clocks
derive_clock_uncertainty

# Reset doesn't need to be constrained because it is a button
set_false_path -from [get_ports {RESET}] -to *

#set_false_path -from * -to [get_ports {LEDS*}]