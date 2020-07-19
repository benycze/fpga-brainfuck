// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------
package binst;

    // Specification of support BCPU instructions. The union is possible to covert
    // to bits and, compare them and print them using the fshow function in the 
    // display method. The list of supported instructions is here:
    // * https://cs.wikipedia.org/wiki/Brainfuck
    //
    // This can be also implemented using the enum :-).

    typedef union tagged {
        void    I_Nop;          // No-operation
        void    I_DataPtrInc;   // Increment of data pointer - ">"
        void    I_DataPtrDec;   // Decrement of data pointer - "<"
        void    I_DataInc;      // Increment the value pointed by the pointer - "+"
        void    I_DataDec;      // Decrement the value pointed by the pointer - "-"
        void    I_SendOut;      // Send the current cel to the output - "."
        void    I_SaveIn;       // Save the input to current cell - ","
        void    I_JmpEnd;       // Move the pointer to the corresponding ] - "["
        void    I_JmpBegin;     // Move the poiter to the correspodnig [ - "]"
    } BInst_t deriving (Bits,Eq,FShow);

endpackage : binst
