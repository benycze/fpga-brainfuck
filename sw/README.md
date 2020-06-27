# SW

The control software and compiler is written in Python3 (to reach the maximal flexibility). The communication with FPGA design is done via the serial line and therefore I am also providing a module which allows to read and write 8 bit chunks of data.

## Communication protocol

You need to install the [PySerial](https://pyserial.readthedocs.io/en/latest/shortintro.html) library into your system. The most suitable way is to use `pip3` and install it inside your home folder:

```bash
pip3 --user PySerial
```

The Python library for communication with engine via the UART end-point is 
located in the **io** folder.

The configuration of the UART is following:

* **Baudrate** - 115200
* **Parity Bit** - none

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

## Address space

TODO

## Compilation of the Brainfuck code

TODO