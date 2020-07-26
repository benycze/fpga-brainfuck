// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package binst;

    import bpkg :: *;
    import DefaultValue :: *;

    // Exports 
    export binst :: *;
    export bpkg  :: *;

    // Specification of support BCPU instructions. The union is possible to covert
    // to bits and, compare them and print them using the fshow function in the 
    // display method. The list of supported instructions is here:
    // * https://cs.wikipedia.org/wiki/Brainfuck
    //
    // This can be also implemented using the enum :-).
    //
    // Opcodes are assigned from 0 to N-1, where N is the number of instructions

    typedef union tagged {
        void    I_Nop;          // No-operation - added to the instruction set
        void    I_DataPtrInc;   // Increment of data pointer - ">"
        void    I_DataPtrDec;   // Decrement of data pointer - "<"
        void    I_DataInc;      // Increment the value pointed by the pointer - "+"
        void    I_DataDec;      // Decrement the value pointed by the pointer - "-"
        void    I_SendOut;      // Send the current cel to the output - "."
        void    I_SaveIn;       // Save the input to current cell - ","
        void    I_JmpEnd;       // Move the pointer to the corresponding ] - "["
        void    I_JmpBegin;     // Move the poiter to the correspodnig [ - "]"
        void    I_Terminate;    // Program termination - stop the operation
    } BInst deriving (Bits,Eq,FShow);

    // Number of supported instructions
    typedef 9 BInstCount;

    // For more comfortable work, we will implement a unpack functions from BData (8-bit) 
    // to the BInst values (less than 8 bits). The BData is the elementary unit of data which 
    // are used for the operation inside the processor.
    function BInst getInstruction(td data) provisos (
        Bits#(BInst, n_bInst),Bits#(td,n_szT),
        Add#(n_szT,unused,n_szT)
    );
        Integer bInstSize = valueOf(SizeOf#(BInst));
        Bit#(bInstSize) inst = pack(data)[bInstSize-1:0];   
        return unpack(inst);
    endfunction

    // Helping structure which holds the de-coded instruction and helps us
    // to work with a bit flags in the next processing
    typedef struct {
        Bool dataPtrInc;
        Bool dataPtrDec;
        Bool dataInc;
        Bool dataDec;
        Bool takeIn;
        Bool takeOut;
        Bool jmpEnd;
        Bool jmpBegin;
        Bool prgTerminated;
    } RegCmdSt deriving (Bits,FShow);

    instance DefaultValue #(RegCmdSt);
        defaultValue = RegCmdSt{
            dataPtrInc      : False, 
            dataPtrDec      : False,
            dataInc         : False,
            dataDec         : False,
            takeIn          : False,
            takeOut         : False,
            jmpEnd          : False,
            jmpBegin        : False,
            prgTerminated   : False
        };
    endinstance

endpackage : binst