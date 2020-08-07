// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package TbPrgRun;

import bpkg :: *;
import bcpu :: *;
import TbCommon :: *;
import StmtFSM :: *;

import BRAM :: *;


// ====================================================
// Global variables 
// ====================================================

// Constant variables in the program
// Folder and input file are passed via
String prgFolderPath = `PRG_FOLDER;
String hexFilePath   = prgFolderPath + `HEX_FILE;
String cellResPath   = prgFolderPath + "cell_mem.hex";

(* synthesize *)
module mkTbPrgRun (Empty);

    // ====================================================
    // Test design 
    // ====================================================

    // BCpu design entity
    BCpu_IFC mcpu <- mkBCpuInit(tagged Hex hexFilePath);

    // Memory with cell results
    BRAM_Configure cellMemResCfg = defaultValue;
    cellMemResCfg.allowWriteResponseBypass = False;
    cellMemResCfg.loadFormat = tagged Hex cellResPath;

    BRAM2Port#(BMemAddress,BData) cellMem <- mkBRAM2Server(cellMemResCfg);

    Stmt fsmMemTest = seq 
        $display(" == BEGIN - Program test ==============");
        $display("* Work directory with program files:", prgFolderPath);
        $display("* Program HEX file path: ", hexFilePath);
        $display("* Cell memory HEX file path:",cellResPath);
        $display("========================================");

        //cellMem.portA.request.put(makeBRAMRequest(False,4,0));
        //$displayh("Data=",cellMem.portA.response.get);

        $display("== END - Program test ================="); 
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbPrgRun 

endpackage : TbPrgRun