// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcore;

import bpkg :: *;

import BRAM :: *;
import FIFO :: *;
import ClientServer :: *;

import Vector :: *;

interface BRAM2PortClient#(type typeAddr, type typeData);
    // First memory port
    interface BRAMClient#(typeAddr, typeData) portA;
    // Second memory port
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
    Bits#(typeAddr, n_typeAddr), Bits#(typeData, n_typeData),
    Literal#(typeData), Literal#(typeAddr), Arith#(typeAddr)
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
    // Rules and folks
    // ----------------------------------------------------

    // BRAM  DEMO ================================
    Reg#(typeAddr) regAddrCellA <- mkReg(0);
    Vector#(2,Reg#(typeData)) regDest <- replicateM (mkReg(0));

    Integer dataBitSize = valueOf(SizeOf#(typeData));
    rule feed_cell_mem (regCoreEnabled);
        typeData tmpData = unpack(pack(regAddrCellA)[dataBitSize-1:0]);
        let portA = makeBRAMRequest(True, regAddrCellA, tmpData);
        let portB = makeBRAMRequest(True, regAddrCellA + 512, tmpData);
        cellMemPortAReq.wset(portA);
        cellMemPortBReq.wset(portB);
        regAddrCellA <= regAddrCellA + 1;
    endrule

    rule drain_cell_memA if(cellMemPortARes.wget() matches tagged Valid .d);
        regDest[0] <= d;
    endrule

    rule drain_cell_memB if(cellMemPortBRes.wget() matches tagged Valid .d);
        regDest[1] <= d;
    endrule

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

(* synthesize *)
module mkBCoreSynth (BCore_IFC#(BMemAddress,BData));
    BCore_IFC#(BMemAddress, BData) m <- mkBCore;
    return m;
endmodule
    
endpackage : bcore
