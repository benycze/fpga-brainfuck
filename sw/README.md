# SW

The control software and compiler is written in Python3 (to reach the maximal flexibility). The communication with FPGA design is done via the serial line and therefore I am also providing a module which allows to read and write 8 bit chunks of data.

## Communication protocol

You need to install the [PySerial](https://pyserial.readthedocs.io/en/latest/shortintro.html) library into your system. The most suitable way is to use `pip3` and install it inside your home folder:

```bash
pip3 --user PySerial
```

If you don't want to run the script as _root_, add yourself to the group which has access to serial line. On my system, Debian 10, the block device `/dev/ttyUSB0` has following
righths:

```bash
crw-rw---- 1 root dialout 188,  0 Jun 27 19:15 /dev/ttyUSB0
```

Therefore, I have to add my accout to the group `dialout` (after that, you have to login and logout to be part of the new group or you can run the `su` tool if don't want to logout from your session):

```bash
sudo usermod -a -G dialout $USER
sudo su -l $USER -
```

The Python library for communication with engine via the UART end-point is located in the **io** folder.

The configuration of the UART is following:

* **Baudrate** - 115200
* **Parity Bit** - none
* **HW control** - none, should be disabled

## Table of commands

Each command is the 8-bit value.

| Name          | Value  |
|---------------|--------|
| CMD_WRITE     |  0x00  |
| CMD_READ      |  0x01  |
| CMD_ACK       |  0X02  |

The address space inside the component is possible to address via
the 24-bit address space. In total, you are able
to address 128 MB of address space.

### Reading

The process of data reading is following:

1. Send the _CMD_READ_ command
2. Send fist (index 7 downto 0) 8-bits of address where you want to read a data
3. Send second (index 15 downto 8) 8-bits of address where you want to read a data
4. Send third (index 23 downto 16) 8-bits of address where you want to read a data
5. Read the 8-bit value from the serial line

### Writing

The process of data writing is following:

1. Send the _CMD_WRITE_ command
2. Send fist (index 7 downto 0) 8-bits of address where you want to write a data
3. Send second (index 15 downto 8) 8-bits of address where you want to write a data
4. Send third (index 23 downto 16) 8-bits of address where you want to write a data
5. Send the 8-bit data to write
6. Wait until the _CMD_ACK_ is received

## bbus tool

The bbus tool is a lightweight tool written in Python3 and it allows you writting and reading from the FPGA via the UART. It is using the implementation of the Brainfuck_io library provided in the **io** folder.

Example of reading from the address 0xab:

```bash
./bbus.py 0xab
```

Example of writing to address 0xbb, data 0x1c:

```bash
./bbus.py 0xbb 0x1c
```

The tool also allows you to write multiple bytes. In this mode, the passed address is used as the target address for the first byte (7 downto 0). So for example, if you want to write 0x010203 to address 0x2:

1. Byte 0x03 to address 0x2
2. Byte 0x02 to address 0x3
3. Byte 0x01 to address 0x1

```bash
./bbus.py 0x2 0x010203
```

The tool is also capable to test the while address space with writing of random data to incrising
destination address (the passed number is the address bit-width):

```bash
./bbus.py --test=8
```

You can also handle the tested address space using the `--min-test-addr` and `--max-test-addr` arguments:

```bash
./bbus.py --test=8 --min-test-addr=0x5 --max-test-addr=0x100
```

## Address space

Braninfuck CPU is using the 16-bit address space. Reading from _Instruction_ and _Cell_
memory is allowed if the CPU is not enabled. Reading from the register address space
is allowed anytime. The design is pipelined and it takes ~3 clock cycles to read/write
the BCPU.

|   Address space       |    Coment                         |
|-----------------------|-----------------------------------|
| 0x0 - 0x3FFF          | Cell memory address space         |
| 0x4000 - 0x7FFF       | Instruction memory address space  |
| 0x8000 - 0xBFFF       | Register address space            |

Register address space has following layout:

| Address               |   Comment                                     |
|-----------------------|-----------------------------------------------|
| 0x8000                | CPU enabled                                   |
| 0x8001                | Lower half of the PC                          |
| 0x8002                | Upper half of the PC                          |
| 0x8003                | Flag register                                 |
| 0x8004                | Read/Write input/outou to/from the BCPU       |

Input/output to BCPU is stored into internal FIFO fronts. The input FIFO front is read by the BCPU
core when the required instruction is asserted. Output from the BCPU is stored in the output FIFO and the output
flag is set if any data are available.

Flag register structure:

| Bit index            |   Comment                                      |
|----------------------|------------------------------------------------|
| 0                    | Output data available                          |
| 1                    | Input data FIFO is full                        |
| 2                    | Output data FIFO is full                       |
| 3                    | Invalid operation code has been detected       |
| 4                    | Program is terminated                          |
| 5                    | BCpu is waiting for input                      |
| 6 - 7                | Reserved - set to 0                            |

## Compilation of the Brainfuck code

Processor is using a 16-bit instructions (to encode longer jumps) and memory access is done in byte order (due to the UART). I know that instructions are little bit longer but this is done becase of some future reserve (if we will be adding some instructions) and for encoding of jump instructions. Each instruction consits of:

* 8 bits for instruction encoding & data (currently use for instructions only) - instruction is encoded in 4 MSB bits
* 8 bits for instruction data (currently for jumps)

Instructions are encoded like following (No = you can use any data, BCPU is ignoring them):

| Source code symbol| Opcode    |  Data                 |   Meaning                                                 |
|:-----------------:|:---------:|-----------------------|-----------------------------------------------------------|
| ; (extended)      |   0x0     | No                    | No operation                                              |
| >                 |   0x1     | No                    | Increment ptr                                             |
| <                 |   0x2     | No                    | Decrement ptr                                             |
| +                 |   0x3     | No                    | Increment cell ptr                                        |
| -                 |   0x4     | No                    | Decrement cell ptr                                        |
| .                 |   0x5     | No                    | Send cell to output                                       |
| ,                 |   0x6     | No                    | Store input to cell                                       |
| [                 |   0x7     | Yes - jmp value (B)   | Cell == 0 -> jump to ]                                    |
| ]                 |   0x8     | Yes - jmp value (B)   | Cell != 0 -> jump to [                                    |
| x (extended)      |   0x9     | No                    | Program termination (BCPU stops the operation)            |
| & (extended)      |   0x10    | No                    | Preload data to cell register                             |

The jump value is in bytes which are added/subtracted from the current PC (program counter) in the BCPU - jump is relative from the position in the source code. Each program
starts from the address 0. The original [Brainfuck language](https://cs.wikipedia.org/wiki/Brainfuck) was extended with the _;_ symbol for *No operation*, _x_ for the program termination, _&_ preload
and line comment starting with // (like in C). Compiler source code is located in the `compiler` folder.

We are not interested about the real value of the PC during the program termination. The BCPU program is terminated in the last pipeline stage and therefore you have to decrement the
PC value by 2 during the debugging.

The translated program can be uploaded to the BCPU using the `upload-program.py` tool - use the `--help` to obtain more information.

## How to compile and upload the code

The translation can be done like following:

```bash
cd compiler
./compiler --help # To obtain more detailed info
./compiler.py --memory file.b
```

The compiler generates a binary form of the code which can be then uploaded to the BCPU. You can also get a memory map
in the [mif](https://www.intel.com/content/www/us/en/programmable/quartushelp/13.0/mergedProjects/reference/glossary/def_mif.htm) format which can be used in Quartus for the memory inilization (and also in Bluespec simulation). We can start the program uploading - you can also erase the memmory but this operation is slow for now (it is not required but it is fine to do it before debugging):

```bash
./upload-program.py --help # To obtain more detailed info
./upload-program.py --erase compiler/a.out
```

The program is now uploaded into the instruction memory and you can fire the processing.
