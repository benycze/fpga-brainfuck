# Structure of the Bluespec test

Each folder contains one test and these files:

* __Brainfuck program__ - the program name depends on the user. We don't want to force the user to have a lot of same files in all directories. The file type is *.b* (foo.b) and this file is translated in Makefile in parent directory (see the Makefile for more details.)

* __Cell memory__ - result cell memory, this file is defined to have a static name **cell_mem.hex**. The syntax of the file is simple: each line consists of one byte which can be processed in the Bluespec simulation environment. Line 0 equals to address 0, line 1 equals to address 1 and so on.

* __in.data__ - list of input values encoded in hex format.

* __out.data__ - list of expected output values encoded in hex format.

The test has to be also added to test environment by editing of this the Makefile in `bsv/src/tests/Makefile`. The file is well commented and you will have a lot of information about this enabling process.
