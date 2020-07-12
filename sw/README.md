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

## Address space

Braninfuck CPU is using the 20-bit address space. Reading from _Instruction_ and _Cell_
memory is allowed if the CPU is not enabled. Reading from the register address space
is allowed anytime.

|   Address space       |    Coment                         |
|-----------------------|-----------------------------------|
| 0x0 - 0x3FFFF         | Cell memory address space         |
| 0x40000 - 0x7FFFF     | Instruction memory address space  |
| 0x80000 - 0xBFFFF     | Register address space            |

Register address space has following layout:

| Address               |   Comment                         |
|-----------------------|-----------------------------------|
| 0x80000               | CPU enabled                       |

## Compilation of the Brainfuck code

TODO