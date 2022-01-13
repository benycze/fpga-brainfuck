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
    (* always_ready *)
    method Action setEnabled(Bool enabled);
    method Action setPC(typeAddr pc);

    // Data response interface
    (* always_enabled *)
    method typeAddr getPC();

    // Deal with input/output data:
    // - check if the inout data FIFO is full
    // - push data into the FIFO
    // - output data are available
    // - get the output data
    // - output data fifo is full
    (* always_enabled *)
    method Bool inputDataFull();
    method Action inputDataPush(typeData data);
    (* always_enabled *)
    method Bool outputDataAvailable();
    method ActionValue#(typeData) outputDataGet();
    (* always_enabled *)
    method Bool outputDataFull();
    
    // We are waiting for input
    (* always_enabled *)
    method Bool waitingForInput();

    // Invalid opcode detected
    (* always_enabled *)
    method Bool getInvalidOpcode();

    // BCPU stops the operation due to the program temination.
    // This flag is reseted after we fire the setEnabled method
    (* always_enabled *)
    method Bool getTermination();

endinterface

// The BCPU core code which implements the processing of the Brainfuck code.
// Parameters:
// - inoutFifoSize - output/input FIFO size
//
module mkBCore#(parameter Integer inoutFifoSize) (BCore_IFC#(typeAddr,typeData)) provisos (
    Bits#(typeAddr, n_typeAddr), Bits#(typeData, n_typeData),
    Literal#(typeData), Literal#(typeAddr), Arith#(typeAddr),
    Arith#(typeData),  Eq#(typeData), Ord#(typeAddr),
    // For the extend inside the execution_and_writeback rule == the sum of the data length and
    // parameter a__ (from the evaluation) has to be equal to the address length. 12 bit is the 
    // length of the jump value
    Add#(0,n_typeData,BDataWidth), Add#(a__, 12, n_typeAddr),
    // We need to be able to print memory responses
    FShow#(Maybe#(typeData))
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
    Reg#(typeAddr) regPc      <- mkReg(0);
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
    Wire#(Bool)     takeDataInSt2En    <- mkDWire(False);
    Wire#(Bool)     takeDataOutSt2En   <- mkDWire(False);

    // Next stage registers - data/signals for the third stage
    Reg#(typeData)          inputData       <- mkReg(0);
    Reg#(Bool)              stage2Inv       <- mkReg(False);
    Reg#(Bool)              stage3AddrEn    <- mkReg(False);
    Reg#(typeAddr)          stage3Addr      <- mkReg(0);
    Reg#(typeData)          st3Inst2Reg     <- mkReg(0);

    // FIFO memories between stages & tag counters for the synchronization
    // between stages
    Reg#(UInt#(BTagWidth))                          st1TagCnt       <- mkReg(0);
    FIFOF#(RegCmdSt)                                st3DecFifo      <- mkFIFOF;
    FIFOF#(BStContext#(typeAddr, BTagWidth))        st3ContextFifo  <- mkFIFOF;
    FIFOF#(BJmpAddrContext#(typeAddr))              st3JmpFifo      <- mkFIFOF;
    Reg#(UInt#(BTagWidth))                          st2TagCnt       <- mkReg(0);

    FIFOF#(BSt3PcContext#(typeAddr))                st3PcFifo       <- mkUGFIFOF;
    FIFOF#(Bool)                                    st3TagAdjust    <- mkFIFOF;
    Reg#(UInt#(BTagWidth))                          st3TagCnt       <- mkReg(0);

    FIFOF#(typeData)                                 st2BarrierInstFifo1 <- mkFIFOF;
    FIFOF#(typeData)                                 st2BarrierInstFifo2 <- mkFIFOF;

    FIFOF#(BStContext#(typeAddr, BTagWidth))         st2Fifo        <- mkFIFOF;
    FIFOF#(BStContext#(typeAddr, BTagWidth))         st2BarrierFifo <- mkFIFOF;

    // FIFO's for memory data
    FIFOF#(typeData)                                 st3CellData    <- mkFIFOF;
    FIFOF#(typeData)                                 st2InstFifo1   <- mkFIFOF;
    FIFOF#(typeData)                                 st2InstFifo2   <- mkFIFOF;

    // ----------------------------------------------------
    // Rules & folks
    // ----------------------------------------------------

    // Processing will be working in three stages:
    // 1) Instruction fetch - the first stage fetch the instruction from the instruction memory
    //      and increments the PC by 2
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

    // Pipeline is enabled when no stalls are there, ST1 are enabled also during the waitForInout 
    // because we need to read/decode instruction for the next stage
    let stEnabled  = regCoreEnabled && !regProgTerminated && !regInvalid;

    rule st1_instruction_fetch (stEnabled);
        let actPc  = regPc;
        let actTag = st1TagCnt; 
        // Prepare context data
        BSt3PcContext#(typeAddr) st3PcContext = defaultValue;
        if(st3PcFifo.notEmpty()) begin
            st3PcContext = st3PcFifo.first;
        end

        // In this stage, we have to read the address from the 
        // register or we have to take the value from the stage 3.
            // Prepare parallel values for stages
        let nonStage1Addr = actPc;
        let nonStage2Addr = actPc + 1;
            // Stage 3 address
        let st3Addr1 = st3PcContext.stage3Addr;
        let st3Addr2 = st3PcContext.stage3Addr + 1;
            // Invalidate address due to the inout stall
        let st1InvInout1Addr = actPc - 2;
        let st1InvInout2Addr = actPc - 1;

        // Select the instruction address to fetch based on the instruction from
        // previous stage. Also compute the next stage address.
        if(st3PcContext.stage3AddrEn)begin
            instMemPortAReq.wset(makeBRAMRequest(False, st3Addr1, 0));
            instMemPortBReq.wset(makeBRAMRequest(False, st3Addr2, 0));
            actTag = actTag + 1;
            actPc  = st3Addr1;
            $display("BCore ST1: Stage address writeback detected in instruction fetch stage in time ", $time);
            $display("BCore ST1: Fetch addresses 0x%x", st3Addr1, " and 0x%x", st3Addr2);
            st3PcFifo.deq;
        end else begin
            instMemPortAReq.wset(makeBRAMRequest(False, nonStage1Addr, 0));
            instMemPortBReq.wset(makeBRAMRequest(False, nonStage2Addr, 0)); 
            $display("BCore ST1: Standard instruction fetch in in time ", $time);
            $display("BCore ST1: Fetch addresses 0x%x", nonStage1Addr, " and 0x%x",nonStage2Addr);
            actPc = nonStage1Addr;
        end
        $display("BCore ST1: Tag value 0x%x", actTag);

        // Enque the context for the next stage
        let st1Context = BStContext {
            pcValue     : actPc,
            tagValue    : actTag
        };
        st2Fifo.enq(st1Context);

        // Update values for the next cycle
        regPc       <= actPc + 2;
        st1TagCnt   <= actTag;
    endrule

    rule st2_inst_fifo1_fetch(instMemPortARes.wget() matches tagged Valid .inst1);
        st2InstFifo1.enq(inst1);
    endrule

    rule st2_inst_fifo2_fetch(instMemPortBRes.wget() matches tagged Valid .inst2);
        st2InstFifo2.enq(inst2);
    endrule

    rule st2_io_barrier;
        let inst1 = st2InstFifo1.first;
        let inst2 = st2InstFifo2.first; 
        let st1Context = st2Fifo.first;

        let st3Dec = defaultValue;
        BInst instruction = unpack({pack(inst1), pack(inst2)});
        let decInst = getInstruction(instruction);
        case (decInst) matches
            tagged I_SendOut: begin 
                $display("BCore ST2 Barrier: Send data to output.");
                st3Dec.takeOut = True;    
            end
            tagged I_SaveIn: begin 
                $display("BCore ST2 Barrier: Take data from input.");
                st3Dec.takeIn = True;
            end
        endcase

        // Check if we can emit the instruction - we want to finish all IO instructions before
        // we will issue the new instruction
        if(!(st3Dec.takeIn || st3Dec.takeOut ) || !st3DecFifo.notEmpty())begin
            $display("BCore ST2 Barrier: Barrier enabled in time ", $time);
            $display("BCore ST2 Barrier: Context PC = 0x%x",st1Context.pcValue, ", tag = 0x%x", st1Context.tagValue);
            st2BarrierInstFifo1.enq(inst1);
            st2BarrierInstFifo2.enq(inst2);
            st2BarrierFifo.enq(st1Context);
            st2InstFifo1.deq;
            st2InstFifo2.deq;
            st2Fifo.deq;
        end
    endrule

    rule st2_adjust_tag_cnt_from_st3_operation (st3TagAdjust.notEmpty());
        st3TagAdjust.deq;
        let newVal = st2TagCnt + 1;
        st2TagCnt <= newVal;
        $display("BCore ST2: Adjusting internal tag counter based on the result from st3 in time ", $time);
        $display("BCore ST2: New adjusted value is 0x%x", newVal);
    endrule

    rule st2_instruction_decode_and_operands(!st3TagAdjust.notEmpty() && stEnabled);
        // Read instructions
        let inst1 = st2BarrierInstFifo1.first; st2BarrierInstFifo1.deq;
        let inst2 = st2BarrierInstFifo2.first; st2BarrierInstFifo2.deq;

        // Read stage1 context (tag value and other stuff)
        let st1Context = st2BarrierFifo.first; st2BarrierFifo.deq;

        // Check if we need to update the tag due to the jump operation, increase
        // the value if such operation is being detected
        let actSt2Tag = st2TagCnt;
        // Actual tag value & computation of instruction validity - we will take the new
        // tag value into account
        let tagValid = True;
        if (actSt2Tag != st1Context.tagValue) begin
            $display("BCore ST2: Invalid tag value, ignoring the instruction in time ", $time);
            $display("BCore ST2: PC = 0x%x", st1Context.pcValue, ", tag = 0x%x",st1Context.tagValue);
            tagValid = False;
        end

        if(tagValid)begin
            // Both instructions should be valid, we pass the check and we can decode the instruction 
            // now.
            $display("BCore ST2: Instruction decode & fetch operation has been started.");
            $display("BCore ST2: Decoding instruction from PC = 0x%x", st1Context.pcValue,", tag = 0x%x", st1Context.tagValue);
            let ioDet = False;
            let st3Dec = defaultValue;
            BInst instruction = unpack({pack(inst1), pack(inst2)});
            let decInst = getInstruction(instruction);
            case (decInst) matches
                tagged I_Nop: begin 
                    $display("BCore ST2: No-operation was detected.");
                end
                tagged I_DataPtrInc: begin 
                    $display("BCore ST2: Data pointer increment");
                    st3Dec.dataPtrInc   = True;
                end
                tagged I_DataPtrDec: begin 
                    $display("BCore ST2: Data pointer decrement.");
                    st3Dec.dataPtrDec   = True;
                end
                tagged I_DataInc: begin 
                    $display("BCore ST2: Increment data.");
                    st3Dec.dataInc = True;
                end
                tagged I_DataDec: begin 
                    $display("BCore ST2: Decrement data.");
                    st3Dec.dataDec = True;
                end
                tagged I_SendOut: begin 
                    $display("BCore ST2: Send data to output.");
                    st3Dec.takeOut = True;    
                    takeDataOutSt2En <= True;
                end
                tagged I_SaveIn: begin 
                    $display("BCore ST2: Take data from input.");
                    st3Dec.takeIn = True;
                    takeDataInSt2En <= True;
                end
                tagged I_JmpEnd { jmpVal : .jmpVal1 } : begin 
                    st3Dec.jmpEnd = True;
                    st3Dec.jmpVal = jmpVal1;
                    $display("BCore ST2: Jump-end instruction, value = 0x%x", jmpVal1);
                end
                tagged I_JmpBegin { jmpVal : .jmpVal1 } : begin 
                    st3Dec.jmpBegin = True;
                    st3Dec.jmpVal   = jmpVal1;
                    $display("BCore ST2: Jump-begin instruction, value = 0x%x", jmpVal1);
                end
                tagged I_Terminate: begin
                    $display("BCore ST2: Program termination was detected.");
                    st3Dec.prgTerminated = True;
                end 
                tagged I_PreloadData: begin
                    $display("BCore ST2: Data preloading to the cell register.");
                    st3Dec.preaload = True;
                end
                default : begin
                    $display("BCore ST2: Unknown instruction was detected.");
                    regInvalid <= True;
                end
            endcase

            // Compute jump values for the next stage iff the jump will be taken, we also need to prepare
            // the next instruction after curently translated one
            BJmpAddrContext#(typeAddr) jmpContext = defaultValue;
            jmpContext.jmpNextPc = st1Context.pcValue + 2; 
            if(st3Dec.jmpBegin || st3Dec.jmpEnd)begin
                // Conver to bits, extend to the address and unpack. We have to send the address 
                // invalidation command to the first stage to work with the right instruction in
                // the next clock cycle.
                typeAddr jmpVal = unpack(extend(pack(st3Dec.jmpVal)));
                let jmpBack   = st1Context.pcValue - jmpVal;
                let jmpAhead  = st1Context.pcValue + jmpVal;

                jmpContext = BJmpAddrContext {
                    jmpBeginAddr    : jmpBack,
                    jmpEndAddr      : jmpAhead
                };
            end

            // Make the read request for the current cell value (to prepare it
            // for the next stage)
            let read_addr = regCell;
            cellMemPortAReq.wset(makeBRAMRequest(False,read_addr,0));
            $display("BCore ST2: Sending read request to BRAM address 0x%x",read_addr);

            // Prepare data for the next stage
            st3DecFifo.enq(st3Dec);
            st3ContextFifo.enq(st1Context);
            st3JmpFifo.enq(jmpContext);
        end // End of the valid instruction decoding
        $display("BCore ST2: Instruction decode and operands in time ",$time);
    endrule

    rule st3_cell_fifo (cellMemPortARes.wget() matches tagged Valid .cellAData);
        st3CellData.enq(cellAData);
    endrule

    rule st3_execution_and_writeback (st3PcFifo.notFull() &&& !waitForInout && stEnabled);
        // Read data from the stage 2 we are working with here
        let decInst = st3DecFifo.first;
        st3DecFifo.deq;
        let jmpContext = st3JmpFifo.first;
        st3JmpFifo.deq;
        let stContext = st3ContextFifo.first;
        st3ContextFifo.deq;

        // Read data at any stage
        let tmpCellAData = st3CellData.first; st3CellData.deq;
        let tmpCellAddr = regCell; 

        // Check if we have the expected tag value from the stage 1, the
        // invalid value means that we just drain the data and no processing will
        // be perfomed there
        let actSt3TagCnt = st3TagCnt;
        let tagValid = True;
        if(actSt3TagCnt != stContext.tagValue)begin
            $display("BCore ST3: Invalid tag value in time ", $time);
            tagValid = False;
        end
 
        if(tagValid)begin
            // Check if we have a valid data in the register
            // If yes, we will store data. If no, we will store
            // data from the register.
            if(isValid(regCellData)) begin
                // Unpack data from the maybe and use the register data
                tmpCellAData = fromMaybe(?, regCellData);
            end
            $display("BCore ST3: Current cell data value is 0x%x", tmpCellAData);

            // We will invalidate data iff we are moving the pointer
            // or we have a jump instruction. Any inc/dec operations are
            // fine because we have a right data from temporal register
            $display("BCore ST3: Execution valid instruction in time ", $time);
            $display("BCore ST3: PC = 0x%x",stContext.pcValue, ", tag = 0x%x", stContext.tagValue);

            // Helping invalidation variables
            let cellChange = False;
            let jmpDet     = False;
            let wbDone     = False;
            let ioDet      = False;
            let st3Addr    = jmpContext.jmpNextPc;

            // We need to perform a writeback iff we are incrementing/decrementing address or terminationg 
            if(decInst.dataPtrInc || decInst.dataPtrDec || decInst.prgTerminated) begin
                cellMemPortBReq.wset(makeBRAMRequest(True, regCell, tmpCellAData));
                $display("BCore ST3: Stage 3 data change, writeback to BRAM: address = 0x%x", regCell, ", data = 0x%x",tmpCellAData);
                wbDone = True;
            end 

            if(decInst.dataPtrInc) begin
                tmpCellAddr     = tmpCellAddr + 1;
                cellChange      = True;
                $display("BCore ST3: Stage 3 cell memory address increment. New value = 0x%x", tmpCellAddr);
            end

            if(decInst.dataPtrDec) begin 
                // We need to go back to the address 
                tmpCellAddr     = tmpCellAddr - 1;
                cellChange      = True;
                $display("BCore ST3: Stage 3 cell memory address decrement. New value = 0x%x", tmpCellAddr);
            end

            // Cell value - we don't need to do any write-back to BRAM because we can remember the value and 
            // write it back in the case of pointer update operation.
            let wbReg = False; 
            if(decInst.dataInc)begin
                tmpCellAData    = tmpCellAData + 1; 
                wbReg          = True;
                $display("BCore ST3: Stage 3 cell memory data increment. New value = 0x%x", tmpCellAData);
            end

            if(decInst.dataDec) begin
                tmpCellAData    = tmpCellAData - 1;
                wbReg          = True;
                $display("BCore ST3: Stage 3 cell memory data decrement. New value = 0x%x", tmpCellAData);
            end
                    
            // Input/output to/from the cell
            if(decInst.takeIn) begin 
                tmpCellAData    = inputData;
                wbReg           = True;
                ioDet           = True;
                $display("BCore ST3: Reading data from input FIFO. Value = 0x%x", tmpCellAData);
            end else begin
                if(decInst.takeIn) begin
                    $display("BCore ST3: Unable to read from the input FIFO. No data available in time ", $time);
                end
            end

            if(decInst.takeOut) begin
                outDataWire.wset(tmpCellAData);
                $display("BCore ST3: Writing data to output FIFO. Value = 0x%x", tmpCellAData);
                ioDet = True;
            end else begin
                if(decInst.takeOut)begin
                    $display("BCore ST3: Unable to write to the output FIFO. Memory is full in time ", $time);
                end
            end

            if(decInst.preaload)begin
                $display("BCore ST3: Data preloading active.");
                wbReg       = True;
                cellChange  = True;
            end

            if(decInst.jmpBegin && tmpCellAData != 0)begin
                $display("BCore ST3: Jump to begin is active in time ", $time);
                st3Addr = jmpContext.jmpBeginAddr;
                jmpDet  = True;
            end

            if(decInst.jmpEnd && tmpCellAData == 0)begin
                $display("BCore ST3: Jump to end is active in time ", $time);
                st3Addr = jmpContext.jmpEndAddr;
                jmpDet  = True;
            end

            // Pass the pointer change iff we detect any jump or data increment/decrement and
            // increment the tag value if such operation is being detected (we need to skip all
            // data there)
            if(jmpDet || cellChange || ioDet)begin
                // Jump data to the stage 1
                let st3JmpContext = BSt3PcContext {
                    stage3AddrEn : True,
                    stage3Addr   : st3Addr
                };
                
                st3PcFifo.enq(st3JmpContext);
                st3TagAdjust.enq(True);
                actSt3TagCnt = actSt3TagCnt + 1;
                $display("BCore ST3: PC request enque in time ", $time);
                $display("BCore ST3: New tag value is 0x%x", actSt3TagCnt);
            end

            // Write-back to the registers
            st3TagCnt <= actSt3TagCnt;
            regCell <= tmpCellAddr;
            if(wbDone) begin
                regCellData <= tagged Invalid;
                $display("BCore ST3: Invalidating register data, need to fetch a fresh data.");
            end else if(wbReg) begin
                regCellData <= tagged Valid tmpCellAData;
                $display("BCore ST3: Storing new data into the cell data register value 0x%x", tmpCellAData);
            end

            // Terminate the program
            if(decInst.prgTerminated)begin
                regProgTerminated <= True;
                $display("BCore ST3: Program termination was detected, writing data back to memory.");
            end
        end

        $display("BCore ST3: Write-back executed in time ",$time);
    endrule

    // Helping rules to send data out if we are not waiting for data.
    //
    // Used for both input/output 
    rule send_out_data (outDataWire.wget() matches tagged Valid .d);
        // Write to the output FIFO
        outDataFifo.enq(d);
        waitForOutput <= False;
    endrule

    rule save_in_data (waitForInput || takeDataInSt2En);
        // Take data from the input FIFO, store them into the register when
        // the stage 2 is being asserted
        let data = inDataFifo.first;
        inputData <= data;
        inDataFifo.deq();
        waitForInput <= False;
        $display("BCore: Passing the input data ", data, " time ",$time);
    endrule

    // Data inout unblocking rules -- these rules are runned when we are waiting and
    // the "defuse" rule is met to unblock it
    rule enable_input_waiting (!waitForInput);
        if(!inDataFifo.notEmpty() && takeDataInSt2En) begin
            $display("BCore: Input waiting enabled.",$time);
            waitForInput <= True;
        end
    endrule

    rule enable_output_waiting (!waitForOutput);
        if(!outDataFifo.notFull() && takeDataOutSt2En)begin
            $display("BCore: Output waiting enabled.",$time);
            waitForOutput <= True;
        end
    endrule

    // ----------------------------------------------------
    // Define methods & interfaces
    // ----------------------------------------------------

    method Action setEnabled(Bool enabled);
        regCoreEnabled      <= enabled;
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

    method Bool waitingForInput();
        return waitForInput;
    endmethod
    
endmodule : mkBCore

(* synthesize *)
module mkBCoreSynth (BCore_IFC#(BMemAddress,BData));
    BCore_IFC#(BMemAddress, BData) m <- mkBCore(bCoreInoutSize);
    return m;
endmodule
    
endpackage : bcore
