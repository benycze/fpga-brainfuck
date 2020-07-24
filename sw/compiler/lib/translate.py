#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

class BTranslate(object):
    """
    Class for handling of translation from the Brainfuck 
    code to the BCPU code.
    """

    def __init__(self,in_file,debug,memory_map,outfile):
        """
        Initilization of the class which takes care of the 
        translation to the BCPU.

        Parameters:
            - in_file - input file to translate (string)
            - debug - debug is enabled (bool)
            - memory_map - generate the output memory map (bool). 
                The output file will have the map-${outfile}.bin
            - Outfile - output file name (string)
        """
        self.in_file    = in_file
        self.debug      = debug
        self.memory_map = memory_map
        self.outfile    = outfile
        self.memory_map_name = "map-" + outfile + ".bin"