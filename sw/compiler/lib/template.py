#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

# The following templates are strings and it it required to fill them using the 
# "format" method

# MIF file header template
# Parameters to fill:
# * Memory DEPTH
# * Width of one element
#
# All elements and addresses are in HEX format 
mif_hdr_template = """
-- Program - {}

DEPTH = {}; -- The size of memory in words
WIDTH = {}; -- The size of data in bits
ADDRESS_RADIX = HEX;          -- The radix for address values
DATA_RADIX = HEX;             -- The radix for data values
CONTENT                       -- start of (address : data pairs)
BEGIN\n
"""

# One line of the MIF the format is ADDRESS : VALUE
mif_line_template = "{:x} : {:x};\n"

# End of the template
mif_end_template = "END;"

# Hexadecimal dump line
hex_line_template = "{:x} {:x}\n"