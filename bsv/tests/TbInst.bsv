// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package TbInst;

import binst :: *;
import StmtFSM  :: *;
import TbCommon :: *;
import Vector :: *;

(* synthesize *)
module mkTbInst (Empty);

    // Prepare reference data --> we are interested in the top, level data because
    // the MSB encodes instruciton and 12 bits contains "aaa" (BSV not-initlaized values)
    Vector#(BInstCount, Bit#(BInstWidth)) inData  = newVector;
    inData[0] = 'h0aaa; 
    inData[1] = 'h1aaa;
    inData[2] = 'h2aaa; 
    inData[3] = 'h3aaa;
    inData[4] = 'h4aaa;
    inData[5] = 'h5aaa;
    inData[6] = 'h6aaa;
    inData[7] = 'h7002;
    inData[8] = 'h8abc;
    inData[9] = 'h9aaa;

    Vector#(BInstCount, BInst) refData = newVector;
    refData[0] = tagged I_Nop;
    refData[1] = tagged I_DataPtrInc;
    refData[2] = tagged I_DataPtrDec;
    refData[3] = tagged I_DataInc;
    refData[4] = tagged I_DataDec;
    refData[5] = tagged I_SendOut;
    refData[6] = tagged I_SaveIn;
    refData[7] = tagged I_JmpEnd { jmpVal : 2};
    refData[8] = tagged I_JmpBegin { jmpVal : 'habc};
    refData[9] = tagged I_Terminate;

    function Action checkOpcode(Bit#(BInstWidth) in, BInst exp);
        return action
            let inConv = getInstruction(in); 
            if(inConv != exp)begin
                $display("Reference and computed opcode doesn't match:");
                $displayh("Expected - 0x", exp);
                $displayh("Received - 0x", inConv);
                report_and_stop(1);
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
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbInst 

endpackage : TbInst