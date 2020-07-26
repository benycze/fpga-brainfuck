#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

class BIsa(object):
    """
    Object with better work with BCPU ISA
    """

    # Width of one instruction in bytes
    INST_WIDTH = 2

    # Table for the supported isa codes
    ISA_TABLE = {
        ";" : 0x0,
        ">" : 0x1, 
        "<" : 0x2, 
        "+" : 0x3, 
        "-" : 0x4, 
        "." : 0x5, 
        "," : 0x6, 
        "[" : 0x7, 
        "]" : 0x8  
    }

    @staticmethod
    def contains(sym):
        """
        Returns true iff the symbol is translatable
        """
        return (sym in BIsa.ISA_TABLE)


    @staticmethod
    def is_jump_instruction(sym):
        """
        Returns true iff we are working with the jump
        instruction.
        """
        if sym in ["]","["]:
            return True

        return False

    @staticmethod
    def is_body_instruction(sym):
        """
        Returns true iff we are working with a body instructino
        """
        if sym in [";",">","<","+","-",".",","]:
            return True
            
        return False

    @staticmethod
    def translate_inst(sym):
        """
        Translate the non-jump instruction
        """
        # Check the instruction
        if not(BIsa.is_body_instruction(sym)):
            raise ValueError("Invalid body instruction - {} was received".foramt(sym))
        # Return the translated instruction
        return bytearray([BIsa.ISA_TABLE[sym],0])

    @staticmethod
    def translate_jump(sym,val):
        """
        Translate the jump instruction with a given
        jump value.
        """
        # Check the instruction 
        if not(BIsa.is_jump_instruction(sym)):
            raise ValueError("Invalid jump instruction - {} was received.".format(sym))

        # The jump value is one byte
        if val < 0 or val > 255:
            raise ValueError("Bad jump value insturction")
        # Return the translated instruction
        return bytearray([BIsa.ISA_TABLE[sym],val])
