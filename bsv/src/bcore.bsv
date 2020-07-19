// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcore;

import bpkg  :: *;
import binst :: *;

import BRAM :: *;
import FIFO :: *;
import FIFOF :: *;
import Vector :: *;
import ClientServer :: *;

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
    method Action setPC(typeAddr pc);

    // Data response interface
    method typeAddr getPC();

    // Deal with input/output data:
    // - check if the inout data FIFO is full
    // - push data into the FIFO
    // - output data are available
    // - get the output data
    // - output data fifo is full
    method Bool inputDataFull();
    method Action inputDataPush(typeData data);
    method Bool outputDataAvailable();
    method ActionValue#(typeData) outputDataGet();
    method Bool outputDataFull();

    // Invalid opcode detected
    method Bool getInvalidOpcode();

endinterface

// The BCPU core code which implements the processing of the Brainfuck code.
// Parameters:
// - inoutFifoSize - output/input FIFO size
//
module mkBCore#(parameter Integer inoutFifoSize) (BCore_IFC#(typeAddr,typeData)) provisos (
    Bits#(typeAddr, n_typeAddr), Bits#(typeData, n_typeData),
    Literal#(typeData), Literal#(typeAddr), Arith#(typeAddr)
);

    // ----------------------------------------------------
    // Registers & folks
    // ----------------------------------------------------
    // Unit enabled/disabled --- we can use wire here
    Reg#(Bool) regCoreEnabled <- mkReg(False);
    // Program counter (we need to address the whole BRAM address space)
    Reg#(typeAddr) regPc <- mkReg(0);
    // Cell pointer address (we need to address the whole BRAM address space)
    Reg#(typeAddr) regCell <- mkReg(0);
    // Register which sets the invalid opcode flag
    Reg#(Bool) regInvalid <- mkReg(False);
    // FIFO with output data from the BCore
    FIFOF#(typeData) outDataFifo <- mkSizedFIFOF(inoutFifoSize);
    FIFOF#(typeData) inDataFifo  <- mkSizedFIFOF(inoutFifoSize);

    // FIFO memories to read/write requests to BRAM
    RWire#(BRAMRequest#(typeAddr,typeData))  cellMemPortAReq <- mkRWire;
    RWire#(typeData)                         cellMemPortARes <- mkRWire;
    RWire#(BRAMRequest#(typeAddr,typeData))  cellMemPortBReq <- mkRWire;
    RWire#(typeData)                         cellMemPortBRes <- mkRWire;

    RWire#(BRAMRequest#(typeAddr,typeData))  instMemPortAReq <- mkRWire;
    RWire#(typeData)                         instMemPortARes <- mkRWire;
    RWire#(BRAMRequest#(typeAddr,typeData))  instMemPortBReq <- mkRWire;
    RWire#(typeData)                         instMemPortBRes <- mkRWire;

    // Helping wires between pipe stages
    PulseWire       stage3AddrEn    <- mkPulseWire;
    Wire#(typeAddr) stage3Addr      <- mkDWire(0);
    PulseWire       stage3Inv       <- mkPulseWire;

    // Next stage registers - data/signals for the third stage
    Reg#(typeData)  st3Inst2Reg     <- mkReg(0);
    Reg#(RegCmdSt)  regDecCmd       <- mkReg(defaultValue);

    // ----------------------------------------------------
    // Rules & folks
    // ----------------------------------------------------

    // Processing will be working in three stages:
    // 1) Instruction fetch - the first stage fetch the instruction from the instruction memory
    //      and increments the PC by 2 (we need to skip the 
    //
    // 2) Instruction decode & operand fetch - this stage decodes the instruction and fetches 
    //      all required operadns (typically just the cell pointer) and pass them to the next
    //      stage.
    //
    // 3) Execution & write-back - this stage executes the decoded instructions and writes back
    //      the result. 
    //
    // For the case of "[" and "]" is used the stack which stores the value of the PC (program counter).
    // In such case, we need take a value from the top of the stack, pass it to the instruction memory and
    // invalidate the current instruction for the next stage (set the NOP). If the [ instruction is found,
    // we need to check if the value differs from 0. Iff yes, we will continue with data processing. If no, 
    // we will take the value from the PC+1, add it to the current PC and set it to the PC (and also invalidate the 
    // previous stage).
    // If the value is 0, we add the value which is stored on the next address in the instruction memory 
    // (therefore the 256-byte jump is allowed). In such case, the currently processed instruction (in previous
    // stage has to be invalidated) and we need to set the right address in the stage 1 (instruction fetch).
    // 
    // When the invalidation is detected, we need to take the value from the third stage. The input/output
    // is processed in the last stage. In such case, we take the input, store it into the BRAM and invalidate
    // the previous stage (we can do it just in the case that we have some instruction which needs to use the 
    // currenly written value but we will do it like that to have a simpler HW).

    (* fire_when_enabled, no_implicit_conditions *)
    rule instruction_fetch;
        // In this stage, we have to read the address from the 
        // register or we have to take the value from the stage 3.
            // Prepare parallel values for stages
        let nonStage1Addr = regPc;
        let nonStage2Addr = regPc + 1;
            // Prepare parralel values for non-stages
        let stage1Addr = stage3Addr;
        let stage2Addr = stage3Addr + 1;
            // Invalidation of the processing (go back one instruction
        let stage3Inv1Addr = regPc - 2;
        let stage3Inv2Addr = regPc - 1;
    
        // Select the instruction address to fetch based on the instruction from
        // previous stage
        if(stage3Inv) begin
            instMemPortAReq.wset(makeBRAMRequest(False, stage3Inv1Addr, 0));
            instMemPortBReq.wset(makeBRAMRequest(False, stage3Inv2Addr, 0));
        end else if(stage3AddrEn)begin
            instMemPortAReq.wset(makeBRAMRequest(False, stage1Addr, 0));
            instMemPortBReq.wset(makeBRAMRequest(False, stage2Addr, 0));
        end else begin
            instMemPortAReq.wset(makeBRAMRequest(False, nonStage1Addr, 0));
            instMemPortBReq.wset(makeBRAMRequest(False, nonStage2Addr, 0)); 
        end

        // Increment the counter by 2 (instructions are 16 bit wide), we need to skip the 8-bit blocks
        // with the shift value.
        regPc <= regPc + 2; 
        $display("BCore: instruction fetch in time ",$time);
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule instruction_decode_and_operands;
        // Take the data from the BRAM
        let inst1Res = instMemPortARes.wget();
        let inst2Res = instMemPortBRes.wget();

        if(!isValid(inst1Res) || !isValid(inst2Res))
            $display("BCore: Some of passed data are not valid: ",inst1Res," and ",inst2Res);

        // Unpack data from maybe    
        let inst1 = fromMaybe(?,inst1Res);
        let inst2 = fromMaybe(?,inst2Res);

        // Make the read request for the current cell value (to prepare it
        // for the next stage)
        let cellAddr = regCell;
        cellMemPortAReq.wset(makeBRAMRequest(False,regCell,0));

        // Both instructions should be valid, we pass the check and we can decode the instruction 
        // now. 
        let st3Dec = defaultValue;
        // Star the decoding and setting of bit flags. This allows faster HW (1 bit comparator)
        //  in the next stage but we will consume more bits.
        if(!stage3Inv) begin
            $display("BCore: Stage invalidation was asserted, keeping all default register values.");    
        end else begin  
            // Analyze the instrucion
            let decInst = getInstruction(inst1);
            case (decInst) matches
                tagged I_Nop: begin 
                    $display("BCore: No-operation was detected.");
                end
                tagged I_DataPtrInc: begin 
                    $display("BCore: Data pointer increment");
                    st3Dec.dataPtrInc = True;
                end
                tagged I_DataPtrDec: begin 
                    $display("BCore: Data pointer decrement.");
                    st3Dec.dataPtrDec = True;
                end
                tagged I_DataInc: begin 
                    $display("BCore: Increment data.");
                    st3Dec.dataInc = True;
                end
                tagged I_DataDec: begin 
                    $display("BCore: Decrement data.");
                    st3Dec.dataDec = True;
                end
                tagged I_SendOut: begin 
                    $display("BCore: Send data to output.");
                    st3Dec.takeOut = True;
                end
                tagged I_SaveIn: begin 
                    $display("BCore: Take data from output.");
                    st3Dec.takeIn = True;
                end
                tagged I_JmpEnd: begin 
                    $display("BCore: Jump-end instruction.");
                    st3Dec.jmpEnd = True;
                end
                tagged I_JmpBegin: begin 
                    $display("BCore: Jump-begin instruction.");
                    st3Dec.jmpBegin = True;
                end
                default : $display("BCore: Unknown instruction was detected.");
            endcase
        end

        // Write data to the next stage
        regDecCmd <= st3Dec;
        $display("BCore: instruction decode and operands in time ",$time);
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule execution_and_writeback;
        // Get data from the previous stage
        // Read data from the CELL
        // Set the invalidation if any jump was detected
    endrule

    // ----------------------------------------------------
    // Define methods & interfaces
    // ----------------------------------------------------

    method Action setEnabled(Bool enabled);
        regCoreEnabled <= enabled;
    endmethod

    method typeAddr getPC();
        return regPc;
    endmethod

    method Action setPC(typeAddr pc);
        regPc <= pc;
    endmethod

    interface BRAM2PortClient cell_ifc;
        interface BRAMClient portA = toGPClient(cellMemPortAReq, cellMemPortARes);
        interface BRAMClient portB = toGPClient(cellMemPortBReq, cellMemPortBRes);
    endinterface

    interface BRAM2PortClient inst_ifc;
        interface BRAMClient portA = toGPClient(instMemPortAReq, instMemPortARes);
        interface BRAMClient portB = toGPClient(instMemPortBReq, instMemPortBRes);
    endinterface

    method Bool inputDataFull();
        return !inDataFifo.notFull();
    endmethod 

    method Action inputDataPush(typeData data);
        inDataFifo.enq(data);
    endmethod

    method Bool outputDataAvailable();
        return outDataFifo.notEmpty();
    endmethod

    method ActionValue#(typeData) outputDataGet();
        let ret = outDataFifo.first;
        outDataFifo.deq();
        return ret;
    endmethod   

    method Bool outputDataFull();
        return !outDataFifo.notFull();
    endmethod 

    method Bool getInvalidOpcode();
        return regInvalid;
    endmethod
    
endmodule : mkBCore

(* synthesize *)
module mkBCoreSynth (BCore_IFC#(BMemAddress,BData));
    BCore_IFC#(BMemAddress, BData) m <- mkBCore(bCoreInoutSize);
    return m;
endmodule
    
endpackage : bcore
