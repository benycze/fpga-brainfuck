create_clock -name CLK -period 83.333 [get_ports {CLK}]

derive_pll_clocks
derive_clock_uncertainty

#set_false_path -from * -to [get_ports {LEDS*}]
#set_false_path -from [get_ports {BTN}] -to 