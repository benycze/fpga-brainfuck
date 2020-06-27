#!/usr/bin/env python3
#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

import serial

class BrainfuckIO(object):
    """
    This class implements the communication protocol with the UART endpoint insde the FPGA.
    
    Brief usage:
        * Create the component  - uart = BrainfuckIO("/dev/ttyUSB0",115200) where 115200 is the baudrate
        * Call the open method to open the connection - uart.open()
        * Use read/write as you need - data = uart.read(addr) or uart.write(addr,data).
        * Close the connection - uart.close()

        * Information about the object can be printed using the info() method
    """

    # UART end-point constants for signalization of READ/WRITE and ACK 
    # codes.
    CMD_WRITE   = 0x00
    CMD_READ    = 0x01
    CMD_ACK     = 0x02

    # Maximal possible address
    MAX_ADDR = (2**24)-1


    def __init__(self, port, baudrate):
        """
        Initializer for the BrainfuckIO component
        """
        self.port       = port
        self.baudrate   = baudrate
        self.uart       = None

    def open(self):
        """
        Open the UART port
        """
        self.uart = serial.Serial(self.port, self.baudrate)
        self.uart.open()

    def close(self):
        # Check if we have something to close
        if self.uart is None:
            return

        self.uart.close()    

    def write(self, addr, data):
        """
        Write data to given address.

        Parameters:
            - addr - integer, value between 0 and maximal address value
            - data - should be of the type byte (length 1)
        """
        # 1) Send the CMD_WRITE command
        cmd_to_write = BrainfuckIO.CMD_WRITE.to_bytes(1,byteorder='little')
        self.uart.write(cmd_to_write)

        # 2) Convert address to 24-bits, slice it on bytes and send it down
        __check_and_send_address(addr)

        # 3) Convert data to 8-bit 
        if(len(data) > 1):
            raise ValueError("Length of passed data is more than 1 byte")

        self.uart.write(data)

        # 4) Wait until CMD_ACK is received
        read_val = self.uart.read()
        read_val_dec = int.from_bytes(read_val,byteorder='little')
        if(read_val_dec != BrainfuckIO.CMD_ACK):
            raise RuntimeError("Invalid ACK code returned from the end-point.")

    def read(self,addr):
        """
        Read data from given address.

        Parameters:
            * addr - address to read

        Return: Read byte which is stored in the byte type
        """
        # 1) Send the CMD_READ command
        cmd_to_write = BrainfuckIO.CMD_READ.to_bytes(1,byteorder='little')
        self.uart.write(cmd_to_write)

        # 2) Send three 8-bít chunks
        __check_and_send_address(addr)

        # 3) Read data and return them 
        read_val = self.uart.read()
        return read_val

    def __check_and_send_address(self,addr):
        """
        Common method for sending of address to the endpoint

        Parameters:
            * addr - address to write
        """
        if(addr > BrainfuckIO.MAX_ADDR):
            raise ValueError("Passed address is bigger than allowed one.")

        addr_to_write = addr.to_bytes(3,byteorder='little')
        self.uart.write(addr_to_write)

    def __str__(self):
        """
        Convert the class to the string
        """
        ret_str = "BrainfuckIO: baudrate=" + str(self.baudrate) + ", " + str(self.port)
        return ret_str

    def info(self):
        """
        Print some info about the IO class
        """
        print(str(self))
