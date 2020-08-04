# Structure of the Bluespec test

Each folder contains one test and these files:

* __Brainfuck program__ - the program name depends on the user. We don't want to force the user to have a lot of same files in all directories. The file type is *.b* (foo.b) and this file is translated in Makefile in parent directory (see the Makefile for more details.)

* __Cell memory__ - result cell memory, this file is defined to have a static name **cell_mem.hex**. The syntax of the file is simple: each line consists of one byte which can be processed in the Bluespec simualation environment. Line 0 equals to address 0, line 1 equals to address 1 and so on.
