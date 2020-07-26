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

    // BCPU stops the operation due to the program temination.
    // This flag is reseted after we fire the setEnabled method
    method Bool getTermination();

endinterface

// The BCPU core code which implements the processing of the Brainfuck code.
// Parameters:
// - inoutFifoSize - output/input FIFO size
//
module mkBCore#(parameter Integer inoutFifoSize) (BCore_IFC#(typeAddr,typeData)) provisos (
    Bits#(typeAddr, n_typeAddr), Bits#(typeData, n_typeData),
    Literal#(typeData), Literal#(typeAddr), Arith#(typeAddr),
    Arith#(typeData),  Eq#(typeData),


    // For the extend inside the execution_and_writeback rule == the sum of the data length and
    // parameter a__ (from the evaluation) has to be equal to the address length
    Add#(a__, n_typeData, n_typeAddr)
);

    // ----------------------------------------------------
    // Registers & folks
    // ----------------------------------------------------
    // Unit enabled/disabled 
    Reg#(Bool) regCoreEnabled       <- mkReg(False);
    Reg#(Bool) regProgTerminated    <- mkReg(False);
    // Handling of data in/out waiting
    Reg#(Bool) waitForInput   <- mkReg(False);
    Reg#(Bool) waitForOutput  <- mkReg(False);
    Bool waitForInout = waitForInput || waitForOutput;
    // Program counter (we need to address the whole BRAM address space)
    Reg#(typeAddr) regPc <- mkReg(0);
    // Cell pointer address (we need to address the whole BRAM address space)
    Reg#(typeAddr)          regCell         <- mkReg(0);
    Reg#(Maybe#(typeData))  regCellData     <- mkReg(tagged Invalid);  
    // Register which sets the invalid opcode flag
    Reg#(Bool) regInvalid <- mkReg(False);
    // FIFO with output data from the BCore
    FIFOF#(typeData) outDataFifo <- mkSizedFIFOF(inoutFifoSize);
    FIFOF#(typeData) inDataFifo  <- mkSizedFIFOF(inoutFifoSize);
    RWire#(typeData) inDataWire     <- mkRWire;
    RWire#(typeData) outDataWire    <- mkRWire;
    Reg#(typeData)   st2JmpVal      <- mkRegU;

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

    // Tell to the BSC compiler that pipeline rules can fire together in the same cycle
    (* conflict_free = "instruction_fetch,instruction_decode_and_operands,execution_and_writeback" *)

    (* fire_when_enabled, no_implicit_conditions *)
    rule instruction_fetch (regCoreEnabled && !regProgTerminated);
        // In this stage, we have to read the address from the 
        // register or we have to take the value from the stage 3.
            // Prepare parallel values for stages
        let nonStage1Addr = regPc;
        let nonStage2Addr = regPc + 1;
            // Prepare parallel values for non-stages
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
        // with the shift value. We don't want to change the program counter iff we are waiting for 
        // the input/output processig
        if(!waitForInout)begin
            regPc <= regPc + 2; 
            $display("BCore: instruction fetch in time ",$time);
        end
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule instruction_decode_and_operands (regCoreEnabled && !waitForInout && !regProgTerminated);
        // Take the data from the BRAM
        let inst1Res = instMemPortARes.wget();
        let inst2Res = instMemPortBRes.wget();

        if(!isValid(inst1Res) || !isValid(inst2Res)) $display("BCore: Not valid memory response in time ",$time);
        if(isValid(inst1Res) && isValid(inst2Res))begin
            // Unpack data from maybe    
            let inst1 = fromMaybe(?,inst1Res);
            let inst2 = fromMaybe(?,inst2Res);

            // Make the read request for the current cell value (to prepare it
            // for the next stage)
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
                        // Stop processing if we cannot push to the output FIFO
                        if(!outDataFifo.notEmpty()) waitForOutput <= True;
                    end
                    tagged I_SaveIn: begin 
                        $display("BCore: Take data from output.");
                        st3Dec.takeIn = True;
                        //Stop processing if no input data are avaialble
                        if(!inDataFifo.notFull()) waitForInput <= True;
                    end
                    tagged I_JmpEnd: begin 
                        $display("BCore: Jump-end instruction.");
                        st3Dec.jmpEnd = True;
                    end
                    tagged I_JmpBegin: begin 
                        $display("BCore: Jump-begin instruction.");
                        st3Dec.jmpBegin = True;
                    end
                    tagged I_Terminate: begin
                        $display("BCore: Program termination was detected.");
                        st3Dec.prgTerminated = True;
                    end 
                    default : $display("BCore: Unknown instruction was detected.");
                endcase
            end

            // Write data to the next stage
            regDecCmd <= st3Dec;
            st2JmpVal <= inst2;
        end
        $display("BCore: instruction decode and operands in time ",$time);
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule execution_and_writeback (regCoreEnabled && !waitForInout && !regProgTerminated);
        // Get data from the previous stage
        let decInst     = regDecCmd;
        let tmpCellARes = cellMemPortARes.wget();
        let tmpCellAddr = regCell; 

        // Check if we have a valid data in the register
        // If yes, we will store data. If no, we will store
        // data from the register.
        let tmpCellAData = fromMaybe(0, tmpCellARes); // Default value
        if(isValid(regCellData)) begin
            // Unpack data from the maybe
            tmpCellAData = fromMaybe(?, regCellData);
        end

        // We will invalidate data iff we are moving the pointer
        // or we have a jump instruction. Any inc/dec operations are
        // fine because we have a right data from temporal register
        if(decInst.dataPtrInc || decInst.dataPtrDec || decInst.jmpEnd || decInst.jmpBegin) 
            stage3Inv.send();

        // Run actions -- we will have a lot of IF statements here

            // Cell address - data are written to the BRAM iff we have detected the address change
        if(decInst.dataPtrInc || decInst.dataPtrDec) cellMemPortBReq.wset(makeBRAMRequest(True, regCell, tmpCellAData));
        if(decInst.dataPtrInc) tmpCellAddr = tmpCellAddr + 1;
        if(decInst.dataPtrDec) tmpCellAddr = tmpCellAddr - 1;

            // Cell value - we don't need to do any write-back to BRAM because we can remember the value and write it back
            // int the case of the pointer update. 
        if(decInst.dataInc) tmpCellAData = tmpCellAData + 1; 
        if(decInst.dataDec) tmpCellAData = tmpCellAData - 1;
                
            // Input/output to/from the cell
        if(decInst.takeIn && inDataFifo.notEmpty()) begin 
            tmpCellAData = fromMaybe(0,inDataWire.wget());
        end else begin
            $display("BCore: Unable to read from the input FIFO. No data available in time ",$time);
        end

        if(decInst.takeOut && outDataFifo.notFull()) begin
            outDataWire.wset(tmpCellAData);
        end else begin
            $display("Unable to write to the output FIFO. THe memory is full in time ",$time);
        end

            // Jumps - in this case we need to prepare the new address values (we have to count with the value
            // in the first stage.
            //
            // Conver to bits, extend to the address and unpack. We have to send the address invalidation command
            // to the first stage to work with the right instruction in the next clock cycle.
        typeAddr jmpVal = unpack(extend(pack(st2JmpVal)));
        let jmpAhead = regPc - 2 - jmpVal;
        let jmpBack  = regPc - 2 + jmpVal;
            // Ahead jump is the default one
        if(decInst.jmpEnd && (tmpCellAData == 0)) begin
            let jmpSel = jmpAhead;
            stage3AddrEn.send();
        end else if(decInst.jmpBegin && (tmpCellAData != 0)) begin
            stage3Addr <= jmpBack;
            stage3AddrEn.send();
        end

        // Write-back to the registers
        regCellData <= tagged Valid tmpCellAData;
        regCell     <= tmpCellAddr;

        // Terminate the program
        regProgTerminated <= decInst.prgTerminated;
        $display("BCore: Write-back executed in time ",$time);
    endrule

    // Helping rules to send data out if we are not waiting for data.
    //
    // Used for both input/output 

    rule send_out_data (outDataWire.wget() matches tagged Valid .d &&& !waitForInout);
        // Write to the output FIFO
        outDataFifo.enq(d);
    endrule

    rule save_in_data(inDataFifo.notEmpty() && !waitForInout);
        // Take data from the input FIFO, store them into the 
        inDataWire.wset(inDataFifo.first);
        inDataFifo.deq();
    endrule

    // Data inout unblocking rules -- these rules are runned when we are waiting and
    // the "defuse" rule is met to unblock it
    rule defuse_input_fifo(waitForInout && inDataFifo.notEmpty());
        waitForInput <= False;
    endrule

    rule defuse_output_fifo(waitForInout && outDataFifo.notFull());
        waitForOutput <= False;
    endrule
  
    // ----------------------------------------------------
    // Define methods & interfaces
    // ----------------------------------------------------

    method Action setEnabled(Bool enabled);
        regCoreEnabled      <= enabled;
        regProgTerminated   <= False;
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

    method Bool getTermination();
        return regProgTerminated;
    endmethod
    
endmodule : mkBCore

(* synthesize *)
module mkBCoreSynth (BCore_IFC#(BMemAddress,BData));
    BCore_IFC#(BMemAddress, BData) m <- mkBCore(bCoreInoutSize);
    return m;
endmodule
    
endpackage : bcore
