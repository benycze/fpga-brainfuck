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
import os
import pdb
import lib.translate as translate

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
    parser.add_argument('--debug',action='store_true',help='Generate debug information')
    parser.add_argument('--memory',action='store_true',help='Store memory layout into the file. Output file name is the output name .mif and .hex.')
    parser.add_argument('--addr-width',type=int,nargs=1,help='Address space width for generated hex file (number of lines,14 bits by default).',default=14)
    parser.add_argument('--output',type=str,nargs=1,help='Name of the output file (default is a.out)',default='a.out')
    parser.add_argument('input',nargs=1,help='Input file to translate')
    return parser.parse_args(args)

def main():
    """
    Main entry function
    """
    args = get_parser(sys.argv) 
    # Arguments parsed, check the validity
    inf         = args.input[0]
    debug       = args.debug
    memory      = args.memory
    addr_width  = args.addr_width   
    output      = args.output[0]

    if not(os.path.exists(inf)):
        print("Source file {} doesn't exists!".format(inf))
    # Run the translation
    try:
        bt = translate.BTranslate(inf,debug,memory,addr_width,output)
        bt.translate()
    except Exception as e:
        print("Error detected during the translation: ",str(e))

if __name__ == "__main__":
    main()