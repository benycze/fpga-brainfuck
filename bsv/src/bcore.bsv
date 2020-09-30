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
    
    // We are waiting for input
    method Bool waitingForInput();

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
    Wire#(typeAddr) st2ActPc  <- mkDWire(0);
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

    Wire#(Maybe#(RegCmdSt)) st2toCmdReg     <- mkDWire(tagged Invalid);
    Wire#(Maybe#(RegCmdSt)) cmdRegToSt3     <- mkDWire(tagged Invalid);
    Reg#(Maybe#(RegCmdSt))  regDecCmd       <- mkReg(tagged Invalid);

    // Helping signals for the edge detection
    Reg#(Bool) waitForInoutReg       <- mkReg(False);
    Reg#(Bool) regCoreEnabledDelay   <- mkReg(False);

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

    // Pipeline is enabled when no stalls are there, ST1 are enabled also during the waitForInout 
    // because we need to read/decode instruction for the next stage
    let st1Enabled  = regCoreEnabled && !regProgTerminated && !regInvalid;
    let pipeEnabled = st1Enabled && !waitForInout;

    let inoutAddrBack = (!waitForInoutReg && waitForInout) || 
                        (!regCoreEnabledDelay && regCoreEnabled) && regPc > 0;

    (* fire_when_enabled, no_implicit_conditions *)
    rule wait_inout_reg;
        waitForInoutReg     <= waitForInout;
        regCoreEnabledDelay <= regCoreEnabled;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule st1_instruction_fetch (st1Enabled);
        let actPc   = regPc;
        st2ActPc    <= actPc;
        // In this stage, we have to read the address from the 
        // register or we have to take the value from the stage 3.
            // Prepare parallel values for stages
        let nonStage1Addr = actPc;
        let nonStage2Addr = actPc + 1;
            // Prepare parallel values for non-stages (go back one instruction due to the pipe stage)
        let stage1Addr = stage3Addr - 2;
        let stage2Addr = stage3Addr - 1;
            // Invalidation of the processing (go back one instruction)
        let stage2Inv1Addr = actPc - 2;
        let stage2Inv2Addr = actPc - 1;

        // Modify the the PC value to a previous instruction iff the inout is in progress
        if(inoutAddrBack)begin
            $display("BCore ST1: Stage inout, disable detected, need to go one instruction back in  time ", $time);
            $displayh("BCore ST1: Fixing to addresses 0x", stage2Inv1Addr, " and 0x",stage2Inv2Addr);
            regPc <= stage2Inv1Addr;
        end else if(!waitForInout) begin
            // Select the instruction address to fetch based on the instruction from
            // previous stage. Also compute the next stage address.
            if(stage3AddrEn)begin
                instMemPortAReq.wset(makeBRAMRequest(False, stage1Addr, 0));
                instMemPortBReq.wset(makeBRAMRequest(False, stage2Addr, 0));
                $display("BCore ST1: Stage 2 address writeback detected in instruction fetch stage in time ", $time);
                $displayh("BCore ST1: Fetch addresses 0x", stage1Addr, " and 0x",stage2Addr);
                actPc = stage1Addr;
            end else if(stage2Inv) begin
                instMemPortAReq.wset(makeBRAMRequest(False, stage2Inv1Addr, 0));
                instMemPortBReq.wset(makeBRAMRequest(False, stage2Inv2Addr, 0));
                $display("BCore ST1: Stage 2 invalidation detected in instruction fetch stage in time ", $time);
                $displayh("BCore ST1: Fetch addresses 0x", stage2Inv1Addr, " and 0x",stage2Inv2Addr);
                actPc = stage2Inv1Addr ;
            end else begin
                instMemPortAReq.wset(makeBRAMRequest(False, nonStage1Addr, 0));
                instMemPortBReq.wset(makeBRAMRequest(False, nonStage2Addr, 0)); 
                $display("BCore ST1: Standard instruction fetch in in time ", $time);
                $displayh("BCore ST1: Fetch addresses 0x", nonStage1Addr, " and 0x",nonStage2Addr);
            end

            regPc <= actPc + 2;
        end 
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule st2_instruction_decode_and_operands (pipeEnabled);
        // Take the data from the BRAM
        let inst1Res = instMemPortARes.wget();
        let inst2Res = instMemPortBRes.wget();
        let tmpStage3Inv = stage2Inv;

        // Both instructions should be valid, we pass the check and we can decode the instruction 
        // now. 
        let st3Dec = defaultValue;
        let jmpInvDet = False;
        let st2_en = isValid(inst1Res) && isValid(inst2Res);

        if(st2_en) begin
            $display("BCore ST2: Instruction decode & fetch operation has been started.");
            // Unpack data from maybe    
            let inst1 = fromMaybe(?,inst1Res);
            let inst2 = fromMaybe(?,inst2Res);

            // Make the read request for the current cell value (to prepare it
            // for the next stage)
            let read_addr = regCell;
            cellMemPortAReq.wset(makeBRAMRequest(False,read_addr,0));
            $displayh("BCore ST2: Sending read request to BRAM address 0x",read_addr);

            // Star the decoding and setting of bit flags. This allows faster HW (1 bit comparator)
            // in the next stage but we will consume more bits.  
            BInst instruction = unpack({pack(inst1), pack(inst2)});
            if(!tmpStage3Inv) begin
                // Analyze the instrucion
                let decInst = getInstruction(instruction);
                case (decInst) matches
                    tagged I_Nop: begin 
                        $display("BCore ST2: No-operation was detected.");
                    end
                    tagged I_DataPtrInc: begin 
                        $display("BCore ST2: Data pointer increment");
                        st3Dec.dataPtrInc = True;
                    end
                    tagged I_DataPtrDec: begin 
                        $display("BCore ST2: Data pointer decrement.");
                        st3Dec.dataPtrDec = True;
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
                        // Send signal to a logic which sets enable/disable signals
                        takeDataOutSt2En <= True;
                    end
                    tagged I_SaveIn: begin 
                        $display("BCore ST2: Take data from input.");
                        st3Dec.takeIn = True;
                        // Send signal to a logic which sets enable/disable signals
                        takeDataInSt2En <= True;
                    end
                    tagged I_JmpEnd { jmpVal : .jmpVal1 } : begin 
                        if(isValid(regCellData))begin
                            st3Dec.jmpEnd = True;
                            st3Dec.jmpVal = jmpVal1;
                            $display("BCore ST2: Jump-end instruction, value = 0x", jmpVal1);
                        end else begin
                            jmpInvDet = True;
                            $display("BCore ST2: Jump-end invalidation due to the non-fresh register.");
                        end
                    end
                    tagged I_JmpBegin { jmpVal : .jmpVal1 } : begin 
                        if(isValid(regCellData))begin
                            st3Dec.jmpBegin = True;
                            st3Dec.jmpVal   = jmpVal1;
                            $displayh("BCore ST2: Jump-begin instruction, value = 0x", jmpVal1);
                        end else begin
                            jmpInvDet = True;
                            $display("BCore ST2: Jump-begin invalidation due to the non-fresh register.");
                        end
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
            end
        end

        // Helping variables used in the next code
        let tmpCellData = fromMaybe(?, regCellData);
        let st2JmpEndEn      = st3Dec.jmpEnd && (tmpCellData == 0);
        let st2JmpBeginEn    = st3Dec.jmpBegin && (tmpCellData != 0);

        // Precompute data for the next clock cycle which will be stored in the register 
        // This allows us to achieve a better timing
        // Compute the invalidation of read/write for the next stage
        if(st3Dec.dataPtrInc || st3Dec.dataPtrDec || st2JmpBeginEn || st2JmpEndEn || jmpInvDet) begin
            tmpStage3Inv = True;
            $display("BCore ST2: Stage 2 invalidation was detected, sending up.");
        end else begin
            tmpStage3Inv = False;
            $display("BCore ST2: Stage 2 invalidation not detected.");
        end

        // Jumps - in this case we need to prepare the new address values (we have to count with the value
        // in the first stage.
        //
        // Conver to bits, extend to the address and unpack. We have to send the address invalidation command
        // to the first stage to work with the right instruction in the next clock cycle.
        typeAddr jmpVal = unpack(extend(pack(st3Dec.jmpVal)));
        let jmpBack   = st2ActPc - jmpVal;
        let jmpAhead  = st2ActPc + jmpVal;
 
        if(st2JmpEndEn || st2JmpBeginEn)
            $displayh("BCore ST2: Cell memory data is 0x", tmpCellData);
            // Ahead jump is the default one
        if(st2JmpEndEn) begin
            stage3Addr     <= jmpAhead;
            stage3AddrEn   <= True;
            $displayh("BCore ST2: Stage 2 address jump ahead = 0x", jmpAhead);
        end else if(st2JmpBeginEn) begin
            stage3Addr     <= jmpBack;
            stage3AddrEn   <= True;
            $displayh("BCore ST2: Stage 2 address jump back = 0x", jmpBack);
        end else begin
            stage3AddrEn <= False;
        end

        // Writaback to next stage
        stage2Inv <= tmpStage3Inv;
        if (st2_en) 
            st2toCmdReg <= tagged Valid st3Dec;
        else
            st2toCmdReg <= tagged Invalid;
            
        $display("BCore ST2: Instruction decode and operands in time ",$time);
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule  st2_dec_reg(pipeEnabled || (!waitForInout && !regCoreEnabledDelay));
        let regData = regDecCmd;
        cmdRegToSt3 <= regData;
        regDecCmd   <= st2toCmdReg;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule st3_execution_and_writeback (cmdRegToSt3 matches tagged Valid .decInst);
        // This rule is working based on the valid decoded instruction from the instruction
        // decode stage.
        let tmpCellARes = cellMemPortARes.wget();
        let tmpCellAddr = regCell; 
        //let decInst     = cmdRegToSt3;

        // Check if we have a valid data in the register
        // If yes, we will store data. If no, we will store
        // data from the register.
        let tmpCellAData = fromMaybe(?,tmpCellARes); // Default value
        if(isValid(regCellData)) begin
            // Unpack data from the maybe and use the register data
            tmpCellAData = fromMaybe(?, regCellData);
        end
        $displayh("BCore ST3: Current cell data value is 0x",tmpCellAData);

        // We will invalidate data iff we are moving the pointer
        // or we have a jump instruction. Any inc/dec operations are
        // fine because we have a right data from temporal register

        $display("BCore ST3: Execution valid instruction in time ", $time);

        // Cell address - data are written to the BRAM iff we have detected the address change
        let wb_done = False;
        if(decInst.dataPtrInc || decInst.dataPtrDec || decInst.prgTerminated) begin
            cellMemPortBReq.wset(makeBRAMRequest(True, regCell, tmpCellAData));
            $displayh("BCore ST3: Stage 3 data change, writeback to BRAM: address = 0x", regCell, ", data = 0x",tmpCellAData);
            wb_done = True;
        end 

        if(decInst.dataPtrInc) begin
            tmpCellAddr = tmpCellAddr + 1;
            $displayh("BCore ST3: Stage 3 cell memory increment. New value = 0x", tmpCellAddr);
        end

        if(decInst.dataPtrDec) begin 
            tmpCellAddr = tmpCellAddr - 1;
            $displayh("BCore ST3: Stage 3 cell memory decrement. New value = 0x", tmpCellAddr);
        end

        // Cell value - we don't need to do any write-back to BRAM because we can remember the value and write it back
        // int the case of the pointer update.
        let wb_reg = False; 
        if(decInst.dataInc)begin
            tmpCellAData = tmpCellAData + 1; 
            $displayh("BCore ST3: Stage 3 cell memory data increment. New value = 0x", tmpCellAData);
            wb_reg = True;
        end

        if(decInst.dataDec) begin
            tmpCellAData = tmpCellAData - 1;
            $displayh("BCore ST3: Stage 3 cell memory data decrement. New value = 0x", tmpCellAData);
            wb_reg = True;
        end
                
        // Input/output to/from the cell
        if(decInst.takeIn) begin 
            tmpCellAData = inputData;
            $displayh("BCore ST3: Reading data from input FIFO. Value = 0x", tmpCellAData);
            wb_reg = True;
        end else begin
            if(decInst.takeIn) begin
                $display("BCore ST3: Unable to read from the input FIFO. No data available in time ",$time);
            end
        end

        if(decInst.takeOut) begin
            outDataWire.wset(tmpCellAData);
            $displayh("BCore ST3: Writing data to output FIFO. Value = 0x", tmpCellAData);
        end else begin
            if(decInst.takeOut)begin
                $display("BCore ST3: Unable to write to the output FIFO. Memory is full in time ",$time);
            end
        end

        if(decInst.preaload)begin
            $display("BCore ST3: Data preloading active.");
            wb_reg = True;
        end

        // Write-back to the registers
        regCell <= tmpCellAddr;
        if(wb_done) begin
            regCellData <= tagged Invalid;
            $display("BCore ST3: Invalidating register data, need to fetch a fresh data.");
        end else if(wb_reg) begin
            regCellData <= tagged Valid tmpCellAData;
            $display("BCore ST3: Storing new data into the cell data register.");
        end

        // Terminate the program
        if(decInst.prgTerminated)begin
            regProgTerminated <= True;
            $display("BCore ST3: Program termination was detected, writing data back to memory.");
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
