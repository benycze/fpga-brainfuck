# Board design

The following folder contains the RTL description of the board desing.

* _ip_ - generated IP cores used in the design
* _rtl_lib_ - 3rd party RTL codes. The list of all library files is shown [here](https://github.com/benycze/fpga-brainfuck)
* _rtl_ - this folder contains my HDL files
* All constraints (which are not embedded in HDL file as ALTERA_ATTRIBUTE) are situated in `constraints.sdc` file. 

The design was created in Quartus 19.1.0. For the [CYC1000](https://shop.trenz-electronic.de/en/Products/Trenz-Electronic/CYC1000-Intel-Cyclone-10/) which is a good starting board for newcomers.

## Simulations

Simulations of internal components are situated in the `rtl` folder. 
Each simulation folder contains the TCL script which translates the design and 
start the simulation in Modelsim.
You can run the simulation from the command line using the following command:

```bash
vsim -do sim.tcl
```

## Input/Outputs

The configuration of UART (baudrate,etc.) is described [here](https://github.com/benycze/fpga-brainfuck/tree/master/sw). Address space is described [here](https://github.com/benycze/fpga-brainfuck/tree/master/sw#address-space) 

| Input/Output      | Purpose           |  PIN  |
|-------------------|-------------------|-------|
| USER_BTN          | Reset of the desgign | PIN_N6 |
| LED0              | Reset done | PIN_M6 |
| LED1              | UART RX activity | PIN_T4 |
| LED2              | UART TX activity | PIN_T3 |
| UART_TXD          | UART TXD channel | PIN_T7 |
| UART_RXD          | UART_RXD channel | PIN_R7 |
| CLK               | Reference 20 MHz | PIN_M2 |

Clock in the design:

* CLK_REF - refernce clock signal, 12 MHz
* CLK_C0 - clocks from the PLL, 100 MHz

Each clock domain has a stand-alone reset signal which is hold for several clock cycles.
