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
from lib.isa import BIsa
from lib.template import *

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
        self.memory_map_name = outfile + ".mif"
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
                self.last_sym = ''
                break

            if char.isspace():
                continue         

            # Check if we are working with the comment
            if char is "/":
                char = self.__get_char()
                if not(char is "/"):
                    BTranslationError("Expecting / symbol",self.line_cnt,self.char_cnt)

                # Process the commend and run the parsing again after you are done
                self.__process_comment()
                continue

            # Check if we are working with allowed
            # symbol.
            if not(BIsa.contains(char)):
                raise BTranslationError("Uknown symbol was detected",self.line_cnt,self.char_cnt)          

            # Yahoo ... we can return the symbol which is possible to translate
            if self.debug:
                print("Lexer: Parser symbol => {}".format(char))

            # Remember the symbol and escape from the function
            self.last_sym = char
            break

    def __translate_body(self):
        """
        Translate the body of the BCPU program

        Returns: The translated code (human readable form - tuple (instruction,address)
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
            # Check if we have something to process
            if self.last_sym is '':
                if self.debug:
                    print("No other symbol to process, ending.")

                # No other instruction, return nop
                nop_inst = ((";",0),self.mem_pos)
                self.mem_pos = self.mem_pos + BIsa.INST_WIDTH
                inst_body.append(nop_inst)
                break

            # Check if we are working with any jump symbol, dump the body into the list
            # and escape from the cycle
            if BIsa.is_bjump(self.last_sym):
                cycle_body = self.__translate_cycle()
                inst_body.extend(cycle_body)
                continue

            if BIsa.is_ejump(self.last_sym):
                # We have a closing parenthesis inside the body, end the processing there and return
                # to the upper __translate cycle
                break

            # Check if we are working with a body instruction, we will return 
            # the error if not
            if not(BIsa.is_body_instruction(self.last_sym)):
                raise BTranslationError("Unknown symbol {}.".format(self.last_sym), self.line_cnt, self.char_cnt)

            # So far so good, add it into the list and try next symbol
            inst = ((self.last_sym,0), self.mem_pos)
            if self.debug:
                print("Dumping the instruction: {}".format(str(inst)))

            inst_body.append(inst)
            self.mem_pos = self.mem_pos + BIsa.INST_WIDTH
        # We are out ... time to dump our code
        return inst_body

    def __translate_cycle(self):
        """
        Translate the BCPU cycle construction

        Returns: The translated code (human readable form) - tuple ((jump_instr,val),address)
        """
        inst_body = []

        # The translate cycle should detect the opening symbol [ and 
        # closing symbol ]
        # Fine ... check if we have an opening symbol
        if not(self.last_sym is '['):
            raise BTranslationError("Cycle opening [ not found, detected {}.".format(self.last_sym), self.line_cnt, self.char_cnt)

        # Remember the first address, translate the body, remember the return address and construct
        # the jump instruction
        bAddress = self.mem_pos
        self.mem_pos = self.mem_pos + BIsa.INST_WIDTH
        body_code = self.__translate_body()
        eAddress = self.mem_pos
        self.mem_pos = self.mem_pos + BIsa.INST_WIDTH

        # Check if we have a closing symbol
        if not(self.last_sym is ']'):
            raise BTranslationError("Cycle closing ] not found, detected {}.".format(self.last_sym), self.line_cnt, self.char_cnt) 

        # We are done ... everything is fine. Time to dump our functionality
            # Front jump -- we need to jump to the next address behind the ]
            # Back jump -- we need to jimp the address which is relatively from the ], following the ]
        fJumpOffset = eAddress - bAddress + BIsa.INST_WIDTH
        bJumpOffset = eAddress - bAddress - BIsa.INST_WIDTH

        if self.debug:
            print("bAddress = 0x{:x}".format(bAddress))
            print("eAdress = 0x{:x}".format(eAddress))
            print("fJump \"[\" value is 0x{:x}".format(fJumpOffset))
            print("bJump \"]\" value is 0x{:x}".format(bJumpOffset))

        # Check that offsets are no longer than 255 bytes
        max_jmp = 2 ** 12 - 1
        if fJumpOffset > max_jmp  or bJumpOffset > max_jmp:
            raise BTranslationError("Jump is longer than {} B.".format(max_jmp), self.line_cnt, self.char_cnt)

        # Generate the [
        fJump = (("[",fJumpOffset), bAddress)
        inst_body.append(fJump)
        # Append body to the list
        inst_body.extend(body_code)
        # Generate the ] and return the body
        bJump = (("]",bJumpOffset), eAddress)
        inst_body.append(bJump)
        return inst_body

    def __memory_map_to_bin(self, mem_map):
        """
        Covert the memroy map to a binary form.

        Return: Byte form of the file uploaded to the BCPU
        """
        if(self.debug):
            print("Dumping the memory map to its binary form")

        ret = bytearray()
        for m_elem,_ in mem_map:
            # Check if we are working with symbol or 
            # jump instruction. Each instruction is encoded as (inst, addr),
            # where inst can be a symbol or jump tuple (jmp,val)
            bF = None
            if BIsa.is_jump_instruction(m_elem[0]):
                bF = BIsa.translate_jump(m_elem[0],m_elem[1])
            else:
                bF = BIsa.translate_inst(m_elem[0])
            
            # Append the result of the conversion
            ret.extend(bF)

        return ret

    def __dump_mem_map(self,mem_map):
        """
        Store the memory map into the file. The format of the 
        file is MIF (https://www.intel.com/content/www/us/en/programmable/quartushelp/13.0/mergedProjects/reference/glossary/def_mif.htm)

        All tempaltes are defined in the template.py file.
        """
        ret = mif_hdr_template.format(self.outfile, len(mem_map) * BIsa.INST_WIDTH, 8)
        # Length of dumped data is the number of programm instructions times the instruction
        # size

        # Dump the memory layout
        for m_elem,addr in mem_map:
            # Prepare data - m_elem is not a tuple iff we are not working
            # with a jump instruction
            bData   = 0
            sym     = m_elem[0]
            if BIsa.is_jump_instruction(sym):
                # It is a jump instruction
                bData = BIsa.translate_jump(m_elem[0],m_elem[1])
            else:
                # It is an instruction
                bData = BIsa.translate_inst(sym)

            # Each line starts with a comment, after that we need to dump 
            # address : data
            i_arg = BIsa.get_instruction_argument(bData) # Try to decode it back
            ret += "-- Translated instruction ==> {} (parameter = 0x{} )\n".format(sym,i_arg)
            ret += mif_line_template.format(addr,bData[0])
            ret += mif_line_template.format(addr+1,bData[1])

        # End the file 
        ret += mif_end_template
        return ret


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
            # Get the memory map and covert it to the binary form
            bprogram = self.__translate_body()
            # Add the program termination symbol
            iTerminate = (("x",0), self.mem_pos)
            bprogram.append(iTerminate)
            # Write the memory map if it is required
            if self.memory_map:
                print("Dumping the memory map to file {}".format(self.memory_map_name))
                mem_map_content = self.__dump_mem_map(bprogram)
                mem_map_file = open(self.memory_map_name,'w')
                mem_map_file.write(mem_map_content)
                mem_map_file.close()

            # Convert the memory map (human readable to the binary form)
            bin_form = self.__memory_map_to_bin(bprogram)
            out_file = open(self.outfile,'wb')
            out_file.write(bin_form)
            out_file.close()
            if self.debug:
                print("Dumping the binary code into the file {}.".format(self.outfile))

        except IOError as e:
            print("Error during the file reading/writing operation.")
        except BTranslationError as e:
            print(str(e))
        finally:
             # Close the file
            self.inf.close()

        print("Translation done!")
