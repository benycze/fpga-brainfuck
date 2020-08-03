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

    Stmt fsmMemTest = seq 
        $display(" == BEGIN - Program test ==============");

        $display("== END - Program test ================="); 
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbPrgRun 

endpackage : TbPrgRun