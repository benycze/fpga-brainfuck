#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

import pdb
import readline
import isa.BIsa as BIsa

class BEof(Exception):
    """
    End of the Brainfuck code was detected
    """
    pass

class BTranslationError(Exception):
    """
    Error during the translation was detected
    """
    def __init__(self,message,line,column):
        self.line = line
        self.column = column
        self.message = "Error {}:{} - {}".format(line,column,message)
        super().__init__(self.message)


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
        # Helping variables - source code parsing
        self.line_buf   = ''
        self.line_cnt   = 0
        self.char_cnt   = 0
        self.last_sym   = ''
        # Helping variables - memroy files
        self.mem_pos    = 0

    def __get_char(self):
        """
        Return a char from the input. The method
        raises eof of the file if we are done.
        """
        # Read line if the buffer is empty
        if self.line_buf == '':
            self.line_cnt = self.line_cnt + 1
            self.line_buf = self.inf.readline()
            self.char_cnt = 0

        if len(self.line_buf) == 0:
            # Nothing else to read 
            raise BEof()
        
        # Extract one character
        self.char_cnt = self.char_cnt + 1
        char = self.line_buf[0]
        self.line_buf = self.line_buf[1:]
        return char

    def __process_comment(self):
        """
        Process comment - read the comment from the input untill the newline is detected
        """
        comment = ""
        while True:
            ## Read the input untill the new line is detected
            char = self.__get_char()
            if (char is '\n') or (char is ''):
                break
            comment = comment + char
        # End of the while
        if(self.debug):
            print("Lexer: Parsed comment => {}".format(comment))

    def __get_symbol(self):
        """
        Get the symbol from the input, skip comments

        Comments are beginning with // and are on one line

        The symbol is stored inside the variable self.last_sym
        """
        while True:
            # Skip white space, check if we are working with
            # comment
            char = self.__get_char()
            if char.isspace():
                continue         

            # Check if we are working with the comment
            if char is "/":
                char = self.__get_char()
                if not(char is "/"):
                    BTranslationError("Expecting / symbol",self.line_cnt,self.char_cnt)
                self.__process_comment()

            # Check if we are working with allowed
            # symbol.
            if not(BIsa.contains(char)):
                raise BTranslationError("Uknown symbol was detected",self.line_cnt,self.char_cnt)          

            # Yahoo ... we can return the symbol which is possible to translate
            if(self.debug):
                print("Lexer: Parser symbol => {}".format(char))

            self.last_sym = char

    def __translate_body(self):
        """
        Translate the body of the BCPU program
        """
        pass

    def __translate_cycle(self):
        """
        Translate the BCPU cycle construction
        """
        pass

    def translate(self):
        """
        Run the translation of the source code
        """
        try:
            # Open the file and process the input body
            self.inf = open(self.in_file,'r')
            while True:
                self.__translate_body()

        except IOError as e:
            print("Error during the file reading/writing operation.")
        except BEof as e:
            if self.debug:
                print("Parsing done!")
        except BTranslationError as e:
            print(str(e))
        finally:
             # Close the file
            self.inf.close()
