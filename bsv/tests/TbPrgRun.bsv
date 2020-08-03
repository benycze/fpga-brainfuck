// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package TbPrgRun;

import bcpu :: *;
import TbCommon :: *;
import StmtFSM :: *;


(* synthesize *)
module mkTbPrgRun (Empty);

    BCpu_IFC mcpu <- mkBCpu;
    
    // Constant variables in the program
    String mifFile = `MIF_FILE;

    Stmt fsmMemTest = seq 
        $display(" == BEGIN - Program test ==============");
        $display("* Starting the processing of MIF file: ", mifFile);

        $display("== END - Program test ================="); 
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbPrgRun 

endpackage : TbPrgRun