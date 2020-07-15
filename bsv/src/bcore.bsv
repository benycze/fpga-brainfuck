// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcore;

import BRAM :: *;
import FIFO :: *;
import ClientServer :: *;

interface BRAM2PortClient#(type typeAddr, type typeData);
    // First port memory
    interface BRAMClient#(typeAddr, typeData) portA;
    // Second port memory
    interface BRAMClient#(typeAddr, typeData) portB;
endinterface


interface BCore_IFC#(type typeAddr, type typeData);

    // Memory interfaces
    interface BRAM2PortClient#(typeAddr, typeData) cell_ifc;
    interface BRAM2PortClient#(typeAddr, typeData) inst_ifc;

    // Control interface
    method Action setEnabled(Bool enabled);
endinterface

module mkBCore(BCore_IFC#(typeAddr,typeData)) provisos (
    Bits#(typeAddr, n_typeAddr), Bits#(typeData, n_typeData), Literal#(typeAddr)    
);

    // ----------------------------------------------------
    // Registers & folks
    // ----------------------------------------------------
    // Unit enabled/disabled --- we can use wire here
    Reg#(Bool) regCoreEnabled <- mkReg(False);
    // Program counter (we need to address the whole BRAM address space
    Reg#(typeAddr) regPc <- mkReg(0);

    // FIFO memories to read/write requests 
    RWire#(BRAMRequest#(typeAddr,typeData))  cellMemPortAReq <- mkRWire;
    RWire#(typeData)                         cellMemPortARes <- mkRWire;
    RWire#(BRAMRequest#(typeAddr,typeData))  cellMemPortBReq <- mkRWire;
    RWire#(typeData)                         cellMemPortBRes <- mkRWire;

    RWire#(BRAMRequest#(typeAddr,typeData))  instMemPortAReq <- mkRWire;
    RWire#(typeData)                         instMemPortARes <- mkRWire;
    RWire#(BRAMRequest#(typeAddr,typeData))  instMemPortBReq <- mkRWire;
    RWire#(typeData)                         instMemPortBRes <- mkRWire;


    // ----------------------------------------------------
    // Define methods & interfaces
    // ----------------------------------------------------

    method Action setEnabled(Bool enabled);
        regCoreEnabled <= enabled;
    endmethod

    interface BRAM2PortClient cell_ifc;
        interface BRAMClient portA = toGPClient(cellMemPortAReq, cellMemPortARes);
        interface BRAMClient portB = toGPClient(cellMemPortBReq, cellMemPortBRes);
    endinterface

    interface BRAM2PortClient inst_ifc;
        interface BRAMClient portA = toGPClient(instMemPortAReq, instMemPortARes);
        interface BRAMClient portB = toGPClient(instMemPortBReq, instMemPortBRes);
    endinterface
    
endmodule : mkBCore

    
endpackage : bcore
