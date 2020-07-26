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
            return ''
        
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
            # Chek if we are not done, skip white spaces
            char = self.__get_char()
            if char == '':
                # Nothing else to read
                self.last_sym is ''
                break

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
            if self.debug:
                print("Lexer: Parser symbol => {}".format(char))

            self.last_sym = char

    def __translate_body(self):
        """
        Translate the body of the BCPU program

        Returns: The translated code (human readable form)
        """
        # The body consits of non-jump instructions - if the instruction [ or ] is detected
        # the following will happen:
        # 1) The [ is translated as the pass to the __translate_cycle method
        # 2) The ] is translated as the return from the method which means that the cycle
        #    is being processed inside the __translate_cycle
        #
        inst_body = []        

        # Get the symbol and analyze iff we are working with the JUMP instruction
        while True:
            self.__get_symbol()
            if self.last_sym is '':
                if self.debug:
                    print("No other symbol to process, ending.")
                break 

            # Check if we are working with any jump symbol
            if BIsa.is_jump_instruction(self.last_sym):
                return self.__translate_cycle()

            # Check if we are working with a body instruction, we will return 
            # the error if not
            if not(BIsa.is_body_instruction(self.last_sym)):
                raise BTranslationError("Unknown symbols {}.".format(self.last_sym), self.line_cnt, self.char_cnt)

            # So far so good, add it into the list and try next symbol
            inst_body.append(self.last_sym)
        # We are out ... time to dump our code
        #TODO: Implement this functionality, return the translated body here

    def __translate_cycle(self):
        """
        Translate the BCPU cycle construction

        Returns: The translated code (human readable form)
        """
        # The translate cycle should detect the opening symbol [ and 
        # closing symbol ]
        # Fine ... check if we have an opening symbol
        if not(self.last_sym is '['):
            raise BTranslationError("Cycle opening [ not found, detected {}.".format(self.last_sym), self.line_cnt, self.char_cnt)

        # Translate the body
        body_code = self.__translate_body()

        # Check if we have a closing symbol
        self.__get_symbol()
        if not(self.last_sym is ']'):
            raise BTranslationError("Cycle closing ] not found, detected {}.".format(self.last_sym), self.line_cnt, self.char_cnt) 

        # We are done ... everything is fine. Time to dump our functionality
        # TODO: Return the translated body here
        return None

    def __memory_map_to_bin(self, mem_map):
        """
        Covert the memroy map to a binary form.

        Return: Byte form of the file uploaded to the BCPU
        """
        return None

    def translate(self):
        """
        Run the translation of the source code
        """
        try:
            # Open the file and process the input body
            # 
            # The program is firstly parsed and constructed to the tree 
            # where the program body is stored inside the list. After we process the whole
            # program we dump the body of the program as the as the last step of each function
            # because what we need is to resolve jump vaues (which are known after the translation.
            #
            # That is the plan - let's rock!!

            self.inf = open(self.in_file,'r')
            while True:
                # Get the memory map and covert it to the binary form
                mem_map = self.__translate_body()
                # Write the memory map if it is required
                if self.memory_map:
                    print("Dumping the memory map to file {}".format(self.memory_map_name))
                    mem_map_file = open(self.memory_map_name,'w')
                    mem_map_file.write(mem_map)
                    mem_map_file.close()

                # Convert the memory map (human readable to the binary form)
                bin_form = self.__memory_map_to_bin(mem_map)
                out_file = open(self.outfile,'wb')
                out_file.write(bin_form)
                out_file.close()
                print("Dumping the binary code for the BCPU.")

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
