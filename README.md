# Brainfuck CPU for FPGA

This repository contains a source code and desing of the CPU processing the Brainfuck code in FPGA. The design is quite simple and it is targeted on beginning FPGA programmers.

* Development board [CYC1000](https://shop.trenz-electronic.de/en/Products/Trenz-Electronic/CYC1000-Intel-Cyclone-10/), [documentation](https://www.trenz-electronic.de/fileadmin/docs/Trenz_Electronic/Modules_and_Module_Carriers/2.5x6.15/TEI0003/REV02/Documents/CYC1000%20User%20Guide.pdf), [resources](https://shop.trenz-electronic.de/en/TEI0003-02-CYC1000-with-Cyclone-10-FPGA-8-MByte-SDRAM?path=Trenz_Electronic/Modules_and_Module_Carriers/2.5x6.15/TEI0003/Driver/Arrow_USB_Programmer)
* Languages - VHDL, Bluespec
* Brainfuck source code examples - http://www.hevanet.com/cristofd/brainfuck/

You can use the [Bluespec Compiler Docker](https://github.com/benycze/bsc-docker-container) for the translation of the Bluespec code if you don't want to install it inside your live system.

The project is using the following open-source libraries:

* <https://github.com/jakubcabal/uart-for-fpga> - project with the implementation of the UART module which allows communication between PC and FPGA core
* <https://github.com/jakubcabal/rmii-firewall-fpga> - FIFO components (ASFIFO, FIFO)
* <https://github.com/kevinpt/vhdl-extras/blob/master/rtl/extras/synchronizing.vhdl> - project with helping componets (mainly used the library for data synchronization across clock domains)

To clone the repository, run:

```bash
git clone --recursive https://github.com/benycze/fpga-brainfuck
```

## Structure of the project

The project contains following folders:

* _board_  - HDL desing and Quartus project
* _sw_ - Software for communication and synthesis and translation of Brainfuck program
* _bsv_ - source code of the Brainfuck processor in Bluespec Language

The address space is described [here](https://github.com/benycze/fpga-brainfuck/tree/master/sw).

## How to translate the code

Details of the FPGA part is [here](https://github.com/benycze/fpga-brainfuck/tree/master/board).

The code translation consits of two main steps:

1. **Translation of the BSV code** - code of the Brainfuck processor is written in the Bluespec Language. You can download and compile the [BSC](https://github.com/B-Lang-org/bsc) compiler or you can use my Docker image with all required tools. I think that the second way is better to recommend because you don't need play with dependencies in the case that you are using Windows or different distribution than Debian/Ubuntu. The docker image repository is [here](https://github.com/benycze/bsc-docker-container) (name the image localhost/bsc-compiler).
Enter the _bsv_ folder and run the `make` command. This produce the RTL code of the Brainfuck processor. You can also use the `start-container.sh` script situated
in the `bsv` folder. The folder also contains a Makefile which is capable to prepare a tarball for Quartus tool. Use the `make help` command for more details.
There is also a possibilty to use the `start-container.sh --translate-only` to run the translate & exit only - output will be stored in the `bsv/tarball` folder.

2. **Translation of the HDL code** - the HDL translation is using the Quartus toolchain
from Intel. The provided build system takes care of everything - translation of the Bluespec code and then synthesis of the HDL code to SOF file which can be then uploaded to the FPGA. You can find more details about available targets in the `board` folder. **I am new with Bluespec in the time of the writing. So, please be patient and excuse some of my constructs if you are skilled Bluespec programmer :-).**

## How to translate and upload the code

TODO
