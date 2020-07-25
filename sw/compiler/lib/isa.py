#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

class BIsa(objec):
    """
    Object with better work with BCPU ISA
    """

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
