#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

import brainfuck_io.io as bio
import pdb
import sys
import argparse
from decimal import Decimal

def get_parser(args):
    """
    Return the parser of arguments

    Parameters:
        - args - arguments to parse
    """
    # Remove the leading app path
    prgname = args[0]
    args = args[1:]

    int_conv = lambda x: int(x,0)
    parser = argparse.ArgumentParser(description='Upload the compiled program to the BCPU.'.format(prgname),formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('--device',type=str,nargs=1,help='Specify the path to the device.',default='/dev/ttyUSB0')
    parser.add_argument("--base",type=int_conv,nargs=1,help='Base address used for the uploading. Default value is 0x4000.',default=[0x4000])
    parser.add_argument("--erase",action='store_true',help="Erase the device - initialize with zeros the program and instruction memory.")
    parser.add_argument("--erase-last-address",type=int_conv,nargs=1,help="Last address of the erased address space. Default is 0x7FFF.",default=[0x7FFF])
    parser.add_argument("input",nargs=1,help="File to upload.")
    return parser.parse_args(args)

def print_proc(act_val,max_val,last):
    """
    Print the current percentage of the action iff the 
    last value is changed. The function returns the 
    current number of %. If the las is None .. 0% is beeing printed.
    """
    if last == None:
        print(" \t -> 0 %\r",end="")
        return 0.00

    # Compute the percentage and chekc if we have a change
    proc = Decimal(float(act_val)/float(max_val)*100)
    proc = float(round(proc,2))
    if(proc == last):
        return proc

    # The value has changed, inform the user
    print("\t -> {:.2f} %\r".format(proc),end="")
    return proc

def upload_file(dev,data,base):
    """
    Upload data to the BCPU via the IO line, with given base address
    and data.
    """
    # Check the data size (it cannot be longer than max_len)
    max_len = 0x3FFF
    if len(data) > max_len:
        raise ValueError("The passed data file is longer than {} B! Cannot upload.".format(max_len))

    print("File size has been checked. Let's rock! \n")
    # Uploading is done in byte-related manner
    data_ptr    = 0
    data_len    = len(data)
    proc        = None
    for d in data:
        # Upload data
        tmp_addr = base + data_ptr
        tmp_d = bytes([d])
        dev.write(tmp_addr, tmp_d)
        data_ptr = data_ptr + 1
        # Print the progress
        proc = print_proc(data_ptr,data_len,proc)

    print("\nUploading has been finished.\n")

def erase(dev,top_addr):
    """
    Erase the device from 0 to top_addr
    """
    print("Erasing the device from address 0x{:x} to 0x{:x}.".format(0,top_addr))
    addr = 0
    proc = None
    while addr <= top_addr:
        # Write the address and inform the user
        dev.write(addr,b'\x00')
        proc = print_proc(addr,top_addr,proc)
        addr = addr + 1

    print("\nErasing done.\n")

def main():  

    dev = None
    in_file = None

    try:
        # Parse arguments
        args = get_parser(sys.argv) 
        in_file_path    = args.input[0]
        device_path     = args.device
        base            = args.base[0]
        erase_max_addr  = args.erase_last_address[0]

        # Opent the IO
        dev = bio.BrainfuckIO(device_path)

        # Read data
        in_file = open(in_file_path,'rb')
        data = bytearray(in_file.read())

        # Run the upload
        print("Uploading the file: {}".format(in_file_path))
        print("Using the IO: {}".format(str(dev)))

        if args.erase:
            erase(dev,erase_max_addr)

        upload_file(dev,data,base)

    except IOError as e:
        print("Error during the IO operation!")
    except Exception as e:
        # Catch all remaining exceptions
        print("Error during the processing: ",str(e))
    finally:
        if not(in_file is None):
            in_file.close()

        if not(dev is None):
            dev.close()
        

if __name__ == "__main__":
    main()
