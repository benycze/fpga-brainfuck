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


    
    // FSM Pseudocode
    // ====================================
    //
    // We need to do following steps:
    // 1) Enable the device
    // 2) Initiliaze done = false
    // 2) Start the inifinit cycle controlled by the done signal - iff true ==> Stop
    //  * read status register into X
    //  * check X if need to send any data - if yes, send a random symbol (or static one)
    //  * check X if we need to read data - if yes, read untill the flag is disabled
    //  * check X if we are done with testing - if yes set done to true
    //  
    // 3) Waif for several clock cycles
    // 4) Check in loop the content of the CELL memory in the BCPU with the cellMem
    //    instantiated here: 
    //      * If we get same values ==> seems to be working
    //      * One different value ==> print the error and report that we   
    //       time to debug :-(
    Stmt fsmMemTest = seq 
        $display(" == BEGIN - Program test ==============");
        $display("* Work directory with program files:", prgFolderPath);
        $display("* Program HEX file path: ", hexFilePath);
        $display("* Cell memory HEX file path:",cellResPath);
        $display("========================================");
        
        //cellMem.portA.request.put(makeBRAMRequest(False,3,0));
        //$displayh("Data=",cellMem.portA.response.get);

        $display("== END - Program test ================="); 
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbPrgRun 

endpackage : TbPrgRun