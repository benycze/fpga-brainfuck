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

// Helping typedefs for the operation extraction
Integer cODATA_MASK          = 0;
Integer cIDATA_FULL_MASK     = 1;
Integer cODATA_FULL_MASK     = 2;
Integer cINVOPER_MASK        = 3;
Integer cTERMINATED_MASK     = 4;
Integer cWINPUT_MASK         = 5;

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

    BRAM2Port#(BMemAddress,BData) cellRefMem <- mkBRAM2Server(cellMemResCfg);

    // ====================================================
    // Test control logic
    // ====================================================

    // Helping registers
    Reg#(Bool)  done        <- mkReg(False);
    Reg#(BData) readData    <- mkReg('h0);
    Reg#(BData) inputData   <- mkReg('h1);
    Reg#(int)   idx         <- mkReg(0);
    Reg#(Bool)  waintInputTaken <- mkReg(False);
    Reg#(int)   delayIter   <- mkReg(0);

    Reg#(BData) bcpuData    <- mkReg(0);
    Reg#(BData) refData     <- mkReg(0);
    Reg#(Bool)  printDone   <- mkRegU;

    // Read the given address and store data inside the
    // readData register
    function Stmt readBCpu(BAddr address);
        return seq
            mcpu.read(address);
            action 
                let data <- mcpu.getData();
                readData <= data;
            endaction
        endseq;
    endfunction

    // Read all symbols from the input register and print
    // them on the output
    function Stmt readAndPrint();
        return seq
            $display("PRINTING ============================");
            printDone <= False;
            while (printDone == False) seq
                // Read the symbol from the FIFO. print it and 
                // update the registers if the next iteration is required
                mcpu.read(getAddress(regSpace, 4));
                action
                    let tmpData <- mcpu.getData();
                    $write(tmpData);
                endaction

                mcpu.read(getAddress(regSpace, 3));
                action
                    let tmpData <- mcpu.getData();
                    printDone <= !unpack(tmpData[cODATA_FULL_MASK]);
                endaction
            endseq
            $display("\n=====================================");
        endseq;
    endfunction

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
    // 4) Check in loop the content of the CELL memory in the BCPU with the cellRefMem
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
        delay(10);

        // Initialize cell memory to zeros
        $display("Checking the cell memory result =========");
        for(idx <= 0; idx < fromInteger(2 ** valueOf(BMemAddrWidth)); idx <= idx + 1)seq
            action // Make the request to both memory blocks
                mcpu.write(getAddress(cellSpace, truncate(pack(idx))), 'h0);
            endaction
        endseq

        $display("Starting the program ====================");
        // Enable the BCPU
        mcpu.write(getAddress(regSpace,'h0), 'h1);
        delay(2);
        // Start the simulation control loop
        while(delayIter < 10) seq
            // Read the status register
            readBCpu(getAddress(regSpace,'h3));
            // Check the status register if we need to pass any data
            if(readData[cWINPUT_MASK] != 0)seq
                mcpu.write(getAddress(regSpace,4), inputData);
                inputData <= inputData + 1;

                // Wait there until input data are taken
                waintInputTaken <= False;
                while(waintInputTaken == False) seq
                    readBCpu(getAddress(regSpace,'h3));
                    if(readData[cWINPUT_MASK] == 0) waintInputTaken <= True;
                endseq
            endseq

            // Check if we need to read any data, read them untill the flag is set
            if(readData[cODATA_MASK] != 0)seq
                // Disable the BCPU, print the result and and
                // enable it again
                mcpu.write(getAddress(regSpace,'h0), 'h0);
                delay(2);
                readAndPrint();
                mcpu.write(getAddress(regSpace,'h0), 'h1);
            endseq

            // Check if the BCPU is in the exit state or check if we
            // are stoped due to the invalid instruction.
            if(readData[cINVOPER_MASK] != 0)seq
                $display("Invalid operation hash been detected!!!");
                report_and_stop(1);
            endseq

            if(readData[cTERMINATED_MASK] != 0 && delayIter == 0)seq
                $display("Processing has been finished");
                done <= True;
            endseq

            if(done == True) seq
                delayIter <= delayIter + 1;
            endseq
        endseq
        // Disable the BCPU
        mcpu.write(getAddress(regSpace,'h0), 'h0);

        // Add the checking logic here, that is:
        //  * Make request to bcpu and internal memory
        //  * get data from both 
        //  * check the result
        $display("Checking the cell memory result =========");
        for(idx <= 0; idx < fromInteger(2 ** valueOf(BMemAddrWidth)); idx <= idx + 1)seq
            action // Make the request to both memory blocks
                let rdAddress = getAddress(cellSpace, truncate(pack(idx)));
                mcpu.read(rdAddress);
                let req = makeBRAMRequest(False, truncate(pack(idx)), 'h0);
                cellRefMem.portA.request.put(req);
            endaction

            action // Get data from both memory blocks
                let bData <- mcpu.getData();
                bcpuData <= bData;
                let rData <- cellRefMem.portA.response.get;
                refData  <= rData;
            endaction

            if(bcpuData != refData)seq
                $display("Reference cell memory doesn't match!");
                $displayh("* expected: 0x",refData);
                $displayh("* received: 0x",bcpuData);
                $displayh("* address: 0x",idx);
                report_and_stop(1);
            endseq
        endseq

        $display("DONE!! It seems that BCPU is working");
        $display("== END - Program test ================="); 
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbPrgRun 

endpackage : TbPrgRun