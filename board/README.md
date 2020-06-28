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

The configuration of UART (baudrate,etc.) is described [here](https://github.com/benycze/fpga-brainfuck/tree/master/sw). 

