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


(* synthesize *)
module mkTbPrgRun (Empty);

    // ====================================================
    // Global variables 
    // ====================================================

    // Constant variables in the program
    // Folder and input file are passed via
    String prgFolderPath = `PRG_FOLDER;
    String mifFilePath   = prgFolderPath + `MIF_FILE;
    String cellResPath   = prgFolderPath + "cell_mem.mif";

    // ====================================================
    // Test design 
    // ====================================================

    // BCpu design entity
    BCpu_IFC mcpu <- mkBCpu;

    // Memory with cell results
    BRAM_Configure cellMemResCfg = defaultValue;
    cellMemResCfg.allowWriteResponseBypass = False;
    cellMemResCfg.loadFormat = tagged Hex cellResPath;

    BRAM2Port#(BMemAddress,BData) cellMem <- mkBRAM2Server(cellMemResCfg);

    Stmt fsmMemTest = seq 
        $display(" == BEGIN - Program test ==============");
        $display("* Work directory with program files:", prgFolderPath);
        $display("* Program MIF file path: ", mifFilePath);
        $display("* Cell memory MIF file path:",cellResPath);
        $display("========================================");

        cellMem.portA.request.put(makeBRAMRequest(False,0,0));
        $displayh("Data=",cellMem.portA.response.get);



        $display("== END - Program test ================="); 
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbPrgRun 

endpackage : TbPrgRun