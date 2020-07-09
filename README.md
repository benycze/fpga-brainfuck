# Braninfuck CPU for FPGA

This repository contains a source code and desing of the CPU processing the Brainfuck code in FPGA. 

* Development board [CYC1000](https://shop.trenz-electronic.de/en/Products/Trenz-Electronic/CYC1000-Intel-Cyclone-10/)
* Languages - VHDL, Bluespec

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

2. **Translation of the HDL code** - TODO

## How to translate and upload the code

TODO
