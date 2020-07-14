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
import random
import signal
import time


# Number of suc. tests after which we print the '+' character
TEST_DOT_CNT = 100
# Flag to stop testing
TEST_EN = True

def interupt_signal_handler(sig, frame):
    """
    Interupt signal handler
    """
    global TEST_EN
    TEST_EN = False

def get_parser(args):
    """
    Return the parser of arguments

    Parameters:
        - args - arguments to parse
    """
    # Remove the leading app path
    prgname = args[0]
    args = args[1:]

    parser = argparse.ArgumentParser(description='Brainfuck bus program which allows you to read/write 8-bit data'
    'chunks from the FPGA device. Brief information how to use the command: \n\n'
    '   * Read data from address 0x22 - {0} 0x22 \n'
    '   * Write data 0x1 to address 0x33 - {0} 0x33 0x1 \n'
    'You are also allowed to send more bytes at once where the passed address will be used for the first byte (from LSB) and following bytes '
    'will be written on incremented address.'.format(prgname),formatter_class=argparse.RawTextHelpFormatter)

    # Remember the conversion function if you want to write integers as 0x or just like a literal
    int_conv = lambda x: int(x,0)
    parser.add_argument('--device',type=str,nargs=1,help='Specify the path to the device.',default='/dev/ttyUSB0')
    parser.add_argument('--test',type=int,nargs=1,help='Run the infinite r/w test until the CTRL+C is fired. The passed argument is the address space bit width.')
    parser.add_argument("--max-test-addr",type=int_conv,nargs=1,help='Set the maximal tested address of passed address space. Default one is the maximal value.')
    parser.add_argument("--min-test-addr",type=int_conv,nargs=1,help='Set the minimal tested address of passed address space. Default one is the minimal value.')
    parser.add_argument('command',type=int_conv,nargs='*',help='There are two possible commands - read and write.'
    'Read is invoked iff only address is passed. Write is invoked iff we pass additonal value argument.')

    return parser.parse_args(args)

def int_to_bytes(data):
    """
    Convert passed data (int) to bytes

    Return: list of bytes
    """
    # Check if the passed data are 0x0, if yes, return the array with byte representation
    if(data == 0x0):
        return [b'\x00']

    # Byte coversion is done via the cycle, where the process
    # is repeated until the data are equal to 0. Everything is taken in 
    # the little-endian format
    tmp_data = data
    ret = []
    while tmp_data != 0:
        dt = tmp_data & 0xff
        tmp_data = tmp_data >> 8
        con = dt.to_bytes(1,byteorder='little')
        ret.append(con)
    return ret

def print_byte(data):
    """
    Print passed data to the output
    """
    # Print the HEX format of read data
    conv_data = hex(int.from_bytes(data,byteorder='little'))
    print(conv_data)

def start_test(dev,awidth,min_value,max_value):
    """
    Start the test of address space

    Parameters:
        - dev - device to work with
        - awidth - address space width which will be tested
        - min_value - minimal address value from the argument
        - max_value - maximal ddress value from the argument
    """
    def __value_check(func,curr_value,new_value,errmessage):
        if (new_value is None):
            return curr_value

        if func(new_value):
            return new_value
        else:
            raise ValueError(errmessage)

    # Setup test parameters and print some debug info
    signal.signal(signal.SIGINT, interupt_signal_handler)
    tmp_addr    = 0x0
    tmp_data    = []
    succ_test   = 0
    succ_addrs  = 0
    start_time  = int(time.time())
    max_addr    = __value_check(lambda x: x > 0, (2**awidth)-1, max_value, "Maximal value cannot be a negative number!")
    min_addr    = __value_check(lambda x: x > 0, 0, min_value, "Minimal value cannot be a negative value!")

    # Check minimal and maximal values
    if min_addr > max_addr:
        raise ValueError("Minimal value is bigger than maximal value!")

    print("Test mode has been detected. The rest of the command is ignored.\n")
    print(" * Tested address space => {}".format(awidth))
    print(" * Minimal address value => {}".format(hex(min_addr)))
    print(" * Maximal address value => {}".format(hex(max_addr)))
    print(" * Test prints the '+' characted after every {} operations.".format(TEST_DOT_CNT))
    print(" * Test prints the '#' after we process the whole address space.")
    print(" * USE CTRL + C to stop the testing process.\n\n")

    # Setup the starting address
    tmp_addr = min_addr
    while TEST_EN:
        # Generate random data
        rnd_input = random.randint(0,255)
        tmp_data = int_to_bytes(rnd_input)
        # Write & read the data
        write(dev,tmp_addr,tmp_data)
        tmp_read = read(dev,tmp_addr)
        # Check the result
        conv_read = int.from_bytes(tmp_read,byteorder='little')
        if(conv_read == rnd_input):
            # Read data are same, increment the counter and print the progress
            succ_test = succ_test + 1
            if succ_test % TEST_DOT_CNT == 0:
                print("+",end='',flush=True)
        else:
            # Invalid test, report it and return the value
            print("\n\n INVALID TEST ==>\n")
            print("Address: {}".format(hex(tmp_addr)))
            print("Expected data: {}".format(hex(rnd_input)))
            print("Received data: {}".format(hex(conv_read)))
            break

        # Prepare the next iteration, we need to reset the 
        # address iff we reached the maximal one 
        if tmp_addr == max_addr:
            tmp_addr = 0
            print("#",end='',flush=True)
            succ_addrs = succ_addrs + 1
        else:
            tmp_addr = tmp_addr + 1

    # Print some statistics about testing
    stop_time   = int(time.time())
    diff        = stop_time - start_time
    mins,sec    = divmod(diff,60)
    hour,mins   = divmod(mins,60)
    operations_per_sec = float(succ_test)/float(diff)

    print("\n\n================================================")
    print("Performed tests: {}".format(succ_test))
    print("Average operations/sec: {}".format(operations_per_sec))
    print("Complete addres spaces: {}".format(succ_addrs))
    print("Runtime: {}h {}m {}s".format(int(hour),int(mins),int(sec)))

def write(dev,addr,data):
    """
    Write data to FPGA

    Parameters:
        - dev - device to work with
        - addr - address to write to
        - data - data to write 
    """
    tmp_addr = addr
    for b in data:
        dev.write(tmp_addr,b)
        tmp_addr = tmp_addr + 1

def read(dev,addr):
    """
    Read data from the FPGA

    Parameters:
        - addr - address to read from
    """
    return dev.read(addr)


def process(args,dev):
    """
    Process commands and start the required operation
    """
    # The test command has biggere precende
    if(args.test is not None):
        min_value = args.min_test_addr[0] if not(args.min_test_addr is None) else None
        max_value = args.max_test_addr[0] if not(args.max_test_addr is None) else None
        start_test(dev,args.test[0],min_value,max_value)
    elif(len(args.command) == 1):
        # Read command asserted
        addr = args.command[0]
        rd = read(dev,addr)
        print_byte(rd)
    elif(len(args.command) == 2):
        # Write command asserted
        addr = args.command[0]
        data = int_to_bytes(args.command[1])
        write(dev,addr,data)
    else:
        print("Invalid command, see --help for more details.")

def main():
    """
    Main entry function
    """
    # Parse arguments
    args = get_parser(sys.argv) 
    # Start the main body of the program
    dev = None
    try:
        dev = bio.BrainfuckIO(args.device)
        process(args,dev)
    except Exception as e:
        print("Error during the program processing : \n\n",file=sys.stderr)
        print(str(e),file=sys.stderr)
    finally:
        if dev is None:
            dev.close()

if __name__ == "__main__":
    main()
