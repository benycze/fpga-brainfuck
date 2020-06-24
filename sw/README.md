# SW

The control software and compiler is written in Python3 (to reach the maximal flexibility). The communication with FPGA design is done via the serial line and therefore I am also providing a module which allows to read and write 8 bit chunks of data.

## Communication protocol

You need to install the [PySerial](https://pyserial.readthedocs.io/en/latest/shortintro.html) library into your system. The most suitable way is to use `pip3` and install it inside your home folder:

```bash
pip3 --user PySerial
```

### Reading

TODO

### Writing

TODO

## Compilation of the Brainfuck code

TODO