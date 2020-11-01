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
    // Opcodes are assigned from 0 to N-1, where N is the number of instructions.
    // Width is 16 bits in total.

    typedef union tagged {
        void    I_Nop;                  // No-operation - added to the instruction set
        void    I_DataPtrInc;           // Increment of data pointer - ">"
        void    I_DataPtrDec;           // Decrement of data pointer - "<"
        void    I_DataInc;              // Increment the value pointed by the pointer - "+"
        void    I_DataDec;              // Decrement the value pointed by the pointer - "-"
        void    I_SendOut;              // Send the current cel to the output - "."
        void    I_SaveIn;               // Save the input to current cell - ","
        struct  { Bit#(12) jmpVal; } I_JmpEnd;   // Move the pointer to the corresponding ] - "["    
        struct  { Bit#(12) jmpVal; } I_JmpBegin; // Move the poiter to the correspodnig [ - "]"
        void    I_Terminate;            // Program termination - stop the operation
        void    I_PreloadData;          // Preload data from the register - "&"
    } BInst deriving (Bits,Eq,FShow);

    // Number of supported instructions
    typedef 11 BInstCount;

    // Instruction width
    typedef 16 BInstWidth;

    // For more comfortable work, we will implement a unpack functions from BInst (8-bit) 
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
        Bool        dataPtrInc;
        Bool        dataPtrDec;
        Bool        dataInc;
        Bool        dataDec;
        Bool        takeIn;
        Bool        takeOut;
        Bool        jmpEnd;
        Bit#(12)    jmpVal;
        Bool        jmpBegin;
        Bool        prgTerminated;
        Bool        preaload;
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
            jmpVal          : 0,
            prgTerminated   : False,
            preaload        : False
        };
    endinstance


    // Processing context data
    //
    // These structure holds context data which are passed between
    // stage 1 and 3
    typedef struct {
        d_pc                pcValue;
        UInt#(tag_width)  tagValue;
    } BStContext #(type d_pc, numeric type tag_width) deriving (Bits, FShow);

    instance DefaultValue #(BStContext#(d_pc, tag_width)) provisos(
        Literal#(d_pc)
    );
        defaultValue = BStContext {
            pcValue     : 0,
            tagValue    : 0
        };
    endinstance

    // ST3 to ST1 structure with PC modification information
    // in the case of jumps
    typedef struct {
        Bool    stage3AddrEn;
        d_pc    stage3Addr;
    } BSt3PcContext #(type d_pc) deriving (Bits, FShow);

    instance DefaultValue #(BSt3PcContext#(d_pc)) provisos (
        Literal#(d_pc)
    );
        defaultValue = BSt3PcContext {
            stage3AddrEn    : False,
            stage3Addr      : 0
        };
    endinstance

    // Precomputed jump values for the ST3, including jumps
    // and invalidation of the stage
    typedef struct {
        d_pc jmpBeginAddr;
        d_pc jmpEndAddr;
        d_pc jmpNextPc;
    } BJmpAddrContext #(type d_pc) deriving (Bits, FShow);

    instance DefaultValue #(BJmpAddrContext#(d_pc)) provisos (
        Literal#(d_pc)
    );
        defaultValue = BJmpAddrContext {
            jmpBeginAddr    : 0,
            jmpEndAddr      : 0,

            jmpNextPc       : 0
        };
    endinstance

endpackage : binst