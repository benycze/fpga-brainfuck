# Brainfuck CPU for FPGA

[![Build Status](https://benycze.semaphoreci.com/badges/fpga-brainfuck/branches/master.svg?style=shields)](https://benycze.semaphoreci.com/projects/fpga-brainfuck)

This repository contains a source code and desing of the CPU processing the Brainfuck code in FPGA. The design is quite simple and it is targeted on beginning FPGA programmers. The project was created during the [European FPGA Developer Contests 2020](https://www.arrow.com/en/research-and-events/events/fpga-developer-contest-2020).

* Development board [CYC1000](https://shop.trenz-electronic.de/en/Products/Trenz-Electronic/CYC1000-Intel-Cyclone-10/), [documentation](https://www.trenz-electronic.de/fileadmin/docs/Trenz_Electronic/Modules_and_Module_Carriers/2.5x6.15/TEI0003/REV02/Documents/CYC1000%20User%20Guide.pdf), [resources](https://shop.trenz-electronic.de/en/TEI0003-02-CYC1000-with-Cyclone-10-FPGA-8-MByte-SDRAM?path=Trenz_Electronic/Modules_and_Module_Carriers/2.5x6.15/TEI0003/Driver/Arrow_USB_Programmer)
* Languages - VHDL, Bluespec SystemVerilog
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
* _bsv_ - source code of the Brainfuck processor in Bluespec SystemVerilog Language
* _doc_ - design and BCPU architecture

The address space is described [here](sw).

## FPGA project

Details of the FPGA part is [here](board).

The code translation consits of two main steps:

1. **Translation of the BSV code** - code of the Brainfuck processor is written in the Bluespec Language. You can download and compile the [BSC](https://github.com/B-Lang-org/bsc) compiler or you can use my Docker image with all required tools. I think that the second way is better to recommend because you don't need play with dependencies in the case that you are using Windows or different distribution than Debian/Ubuntu. The docker image repository is [here](https://github.com/benycze/bsc-docker-container) (name the image localhost/bsc-compiler).
Enter the _bsv_ folder and run the `make` command. This produce the RTL code of the Brainfuck processor. You can also use the `start-container.sh` script situated
in the `bsv` folder. The folder also contains a Makefile which is capable to prepare a tarball for Quartus tool. Use the `make help` command for more details.
There is also a possibilty to use the `start-container.sh --translate-only` to run the translate & exit only - output will be stored in the `bsv/tarball` folder.

2. **Translation of the HDL code** - the HDL translation is using the Quartus toolchain
from Intel. The provided build system takes care of everything - translation of the Bluespec code and then synthesis of the HDL code to SOF file which can be then uploaded to the FPGA. You can find more details about available targets in the `board` folder. **I am new with Bluespec in the time of the writing. So, please be patient and excuse some of my constructs if you are skilled Bluespec programmer :-).**

## How to translate and upload the code

This task consists of two subtasks:

1. Translation of the FPGA design (details are mentioned above but I will repeat it here ;) )
2. Translation of the Brainfuck code

So, lets start with it :-)

### Design translation

Synthesis script works automatically and therefore you can easily translate the BSV code and upload a bitstream into the FPGA.
To achieve this, you need to do following steps:

```bash
cd board
make # To translate the code
```

The code should be translated now and you can upload it to you development kit using the standard Quartus way (double click on the
*Program Device (Open Programmer)*, select your device and upload the translated *sof* file (`board/output_files/fpga-brainfuck.sof`)).

Alternatively, you can use the `make run` command to translate the code and configure it into the FPGA in the single step.
The device indes is *1* by default and you can control it via a parameter passed to the make command.
For intance, if you want to use a device number *2* you can run the following command:

```bash
make run DEVICE=2
```

You can use the `quartus_pgm -l` command to get the index of your JTAG device. The output of the tool is like this
(you can also see that the index of my JTAG device is *1*):

```
user@machine $ quartus_pgm -l

Info: *******************************************************************
Info: Running Quartus Prime Programmer
    Info: Version 19.1.0 Build 670 09/22/2019 SJ Lite Edition
    Info: Copyright (C) 2019  Intel Corporation. All rights reserved.
    Info: Your use of Intel Corporation's design tools, logic functions 
    Info: and other software and tools, and any partner logic 
    Info: functions, and any output files from any of the foregoing 
    Info: (including device programming or simulation files), and any 
    Info: associated documentation or information are expressly subject 
    Info: to the terms and conditions of the Intel Program License 
    Info: Subscription Agreement, the Intel Quartus Prime License Agreement,
    Info: the Intel FPGA IP License Agreement, or other applicable license
    Info: agreement, including, without limitation, that your use is for
    Info: the sole purpose of programming logic devices manufactured by
    Info: Intel and sold by Intel or its authorized distributors.  Please
    Info: refer to the applicable agreement for further details, at
    Info: https://fpgasoftware.intel.com/eula.
    Info: Processing started: Sun Sep 20 16:27:16 2020
Info: Command: quartus_pgm -l
1) Arrow-USB-Blaster [AR2FWBPS]
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
    Info: Peak virtual memory: 429 megabytes
    Info: Processing ended: Sun Sep 20 16:27:16 2020
    Info: Elapsed time: 00:00:00
```

### Brainfuck code translation

The code translation consists of following steps:

1. Run the compiler inside the `sw/compiler` folder. It will generate you a binary file (based on BCPU ISA) which can be uploaded to into the FPGA IP core. The default name of translated binary is `a`. The example of generated outcome is (it is also a good idea to generate a hex dump of the memory):

```bash
./compiler.py --out ptr_inc2 ../../bsv/tests/data/ptr_inc2/ptr_inc2.b
Translation done!
```

2. Use the `upload-program.py` tool inside the `sw` folder. You can also run the memory
initialization (cell and instruction) to be absolutely sure that memory is initialized to some values.
The initialization process takes some time because we are using the serial port and I need to change the
communication protocol to be more effective :-).

```bash
./upload-program.py --erase compiler/ptr_inc2
```

3. Now, you need to enable the code processing using the `bbus.py` tool inside the `sw` folder by writing into a
control register. The register offset is `0x8000` and we need to write value `1` (at index 0).

```bash
./bbus.py 0x8000 0x1
```

And thats it, your code is running! :-) Note that processing is stopped when the `Program termination` is detected.
The detailed explanation of ISA, address space and code translation is [here](sw).
