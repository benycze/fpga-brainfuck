#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

import argparse
import sys
import pdb

def get_parser(args):
    """
    Return the parser of arguments

    Parameters:
        - args - arguments to parse
    """
    # Remove the leading app path
    prgname = args[0]
    args = args[1:]

    parser = argparse.ArgumentParser(description='Compiler from the brainfuck language to the Brainfuck code to '
    'the BCPU'.format(prgname),formatter_class=argparse.RawTextHelpFormatter)

    # Remember the conversion function if you want to write integers as 0x or just like a literal
    parser.add_argument('--debug',type=bool,help='Generate debug information',default=False)
    parser.add_argument("--memory",type=bool,help='Store memory layout into the file.',default=False)
    parser.add_argument("--output",type=str,nargs=1,help="Name of the output file (default is a.out)",default="a.out")
    parser.add_argument("input",nargs=1,help="Input file to translate")

    return parser.parse_args(args)

def main():
    """
    Main entry function
    """
    args = get_parser(sys.argv) 

if __name__ == "__main__":
    main()