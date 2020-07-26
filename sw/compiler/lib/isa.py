#!/usr/bin/env python3

# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

import pdb

class BIsa(object):
    """
    Object with better work with BCPU ISA
    """

    # Width of one instruction in bytes
    INST_WIDTH = 2

    # Table for the supported isa codes
    # The 12 bit shift is because of the jump value
    # instruction
    ISA_TABLE = {
        ";" : (0x0) << 12,      # 0x0000
        ">" : (0x1) << 12,      # 0x1000
        "<" : (0x2) << 12,      # 0x2000
        "+" : (0x3) << 12,      # 0x3000
        "-" : (0x4) << 12,      # 0x4000
        "." : (0x5) << 12,      # 0x5000
        "," : (0x6) << 12,      # 0x6000
        "[" : (0x7) << 12,      # 0x7000
        "]" : (0x8) << 12,      # 0x8000
        "x" : (0x9) << 12,      # 0x9000
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
    def is_bjump(sym):
        """
        The jump is the  [
        """
        return sym is "["

    @staticmethod
    def is_ejump(sym):
        """
        The jump is "]"
        """
        return sym is "]"

    @staticmethod
    def is_body_instruction(sym):
        """
        Returns true iff we are working with a body instructino
        """
        if sym in [";",">","<","+","-",".",",","x"]:
            return True
            
        return False

    @staticmethod
    def __dump_to_bytes(val):
        """
        Dump the passed value to 2 byte array
        """
        ret = (val).to_bytes(2,byteorder='big')
        return ret

    @staticmethod
    def translate_inst(sym):
        """
        Translate the non-jump instruction
        """
        # Check the instruction
        if not(BIsa.is_body_instruction(sym)):
            raise ValueError("Invalid body instruction - {} was received".foramt(sym))
        # Return the translated instruction
        inst = BIsa.ISA_TABLE[sym]
        return BIsa.__dump_to_bytes(inst)

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
        if val < 0 or val > (2**12 - 1):
            raise ValueError("Bad jump value insturction")
        
        # Prepare the jump - convert to bytes
        inst = BIsa.ISA_TABLE[sym] | val
        return BIsa.__dump_to_bytes(inst)

    @staticmethod
    def get_instruction_argument(inst):
        """
        Return the argument value 
        """
        val = ((inst[0] & 0x0f) << 8)  | inst [1] 
        return val
