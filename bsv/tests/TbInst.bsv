// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package Tb;

import binst :: *;
import StmtFSM :: *;
import Vector :: *;

(* synthesize *)
module mkTbInst (Empty);

    // Prepare reference data --> vector of shorter values (size of the instruction)
    // See the file src/binst.bsv for more details.
    Vector#(BInstCount, BData) inData  = map(fromInteger,genVector);
    Vector#(BInstCount, BInst) refData = newVector;
    refData[0] = tagged I_Nop;
    refData[1] = tagged I_DataPtrInc;
    refData[2] = tagged I_DataPtrDec;
    refData[3] = tagged I_DataInc;
    refData[4] = tagged I_DataDec;
    refData[5] = tagged I_SendOut;
    refData[6] = tagged I_SaveIn;
    refData[7] = tagged I_JmpEnd;
    refData[8] = tagged I_JmpBegin;

    function Action checkOpcode(BData in, BInst exp);
        return action
            let inConv = getInstruction(in); 
            if(inConv != exp)begin
                $display("Reference and computed opcode doesn't match:");
                $displayh("Expected - 0x", exp);
                $displayh("Receivde - 0x",inConv);
                $finish(1);
            end
        endaction;
    endfunction

    // Helping register
    Reg#(int) s_idx <- mkRegU;
    
    Stmt fsmMemTest = seq 
        $display(" == BINST conversion tests ==============");
        // Check opcodes
        for(s_idx <= 0; s_idx < fromInteger(valueOf(BInstCount)); s_idx <= s_idx + 1)
            checkOpcode(inData[s_idx], refData[s_idx]);

        $display("Everything seems fine :-)");
        $display("== BINST conversion tests ===========");  
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbInst 

endpackage : Tb