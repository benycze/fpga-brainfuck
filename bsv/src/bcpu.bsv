// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcpu;

import bpkg  :: *;
import bcore :: *;
import binst :: *;

import BRAM  :: *;
import FIFOF :: *;
import ClientServer :: *;
import Connectable  :: *;

// Generic CPU interface -- the type addr specifies the
// memory address widht and type data specifies the initial 
// width which is used for the CPU operation
interface BCpu_IFC;

    // Pause the BCPU before you start reading/writing
    // memory which is mainly allocated for internal purposes.
    // Registers are allowed to read/write during the normal operation. 
    // The read or write  can be performed in the same clock cycle.
    
    // Read transaction from the BCpu
    // - addr - address to read
    method Action read(BAddr addr);
    
    // Returns the read data from the BCpu 
    method ActionValue#(BData) getData();

    // Write transaction to the BCpu
    // - addr - address to write
    // - data - data to write
    method Action write(BAddr addr, BData data);

    // Read is in progress
    method Bool getReadRunning();
    // BCPU is enabled to operate
    method Bool getCpuEnabled();

endinterface

// Configuration stream typedef
typedef union tagged {
    BMemAddress     RegPc;      // New program counter
    BData           RegCmd;     // New command register
} BCoreWriteReq deriving (Bits, FShow);

module mkBCpuInit#(LoadFormat loadFormat) (BCpu_IFC);
    
    // ------------------------------------------------------------------------
    // Registers & components 
    // ------------------------------------------------------------------------

    // Registers ------------------------------------------
        // Command register (8 bits)
    Reg#(BData)     regCmd      <- mkReg(0);
        // Work register for the PC
    Reg#(BData)     regWorkPcLsb <- mkReg(0);

        // Parse the command register
    Bool cmdEn  =  unpack(regCmd[bitEnabled]);
    Bool stepEn =  unpack(regCmd[bitStepEnabled]);

    // Memory blocks --------------------------------------
        // Cell memory
    BRAM_Configure cellCfg  = defaultValue;
    cellCfg.latency         = 2;
    cellCfg.allowWriteResponseBypass = False;
    cellCfg.outFIFODepth    = 4;
    BRAM2Port#(BMemAddress,BData)  cellMem <- mkBRAM2Server(cellCfg);  

        // Instruction memory
    BRAM_Configure instCfg  = defaultValue;
    instCfg.latency         = 2;
    instCfg.loadFormat      = loadFormat;
    instCfg.outFIFODepth    = 4;
    instCfg.allowWriteResponseBypass = False;

    BRAM2Port#(BMemAddress,BData) instMem <- mkBRAM2Server(instCfg);  

        // BCPU Core
    BCore_IFC#(BMemAddress, BData) bCore <- mkBCoreSynth;

        // Connect the core with memories
    mkConnection(bCore.cell_ifc.portB,cellMem.portB);
    mkConnection(bCore.inst_ifc.portB,instMem.portB);
        // Port A is also used for the access form SW and CPU
    FIFOF#(BRAMRequest#(BMemAddress,BData)) cellReq <- mkFIFOF;
    FIFOF#(BRAMRequest#(BMemAddress,BData)) instReq <- mkFIFOF;
    
        // Helping registers
    Reg#(BData)                 outRegData      <- mkReg(0);       
    Reg#(Bool)                  dataDrained     <- mkReg(False);
    Reg#(Maybe#(BData))         regSpaceRet     <- mkReg(tagged Invalid);
    Reg#(Bool)                  regCellRead     <- mkReg(False);
    Reg#(Bool)                  regInstRead     <- mkReg(False);
    Reg#(Bool)                  regRegRead      <- mkReg(False);
    FIFOF#(BData)               readRetData     <- mkFIFOF;
    FIFOF#(BCoreWriteReq)       bcoreConfig     <- mkFIFOF;
    Reg#(Bool)                  bcoreUpdate     <- mkReg(False);

    let readRunning  = regCellRead || regInstRead || regRegRead;
    let writeRunning = !cellReq.notFull() || !instReq.notFull() || ! bcoreConfig.notFull();

    // Read / write registers because we don't want to block the read/write 
    // methods. Therefore, the input/outout FIFO fronts has 1 more available 
    // slot because the FIFO flag is asserted when it is already full --> write/read
    // from the software will fail in that case.
    Reg#(Maybe#(BData))     outputBcoreData <- mkReg(tagged Invalid);
    Reg#(Maybe#(BData))     inputBCoreData  <- mkReg(tagged Invalid);

    // Helping logic for enabling/disabling of multiplexing logic
    Wire#(Bool) instMemReq      <- mkDWire(False);
    Wire#(Bool) instMemResp     <- mkDWire(False);
    Reg#(UInt#(MemReqCntWidth)) instMemCnt <- mkReg(0);

    Wire#(Bool) cellMemReq      <- mkDWire(False);
    Wire#(Bool) cellMemResp     <- mkDWire(False);
    Reg#(UInt#(MemReqCntWidth)) cellMemCnt <- mkReg(0);

    // ------------------------------------------------------------------------
    // Rules 
    // ------------------------------------------------------------------------

        // Counter logic for the arbitration
    rule inst_mem_counter;
        if (instMemReq && !instMemResp)
            instMemCnt <= instMemCnt + 1;
        else if(!instMemReq && instMemResp)
            instMemCnt <= instMemCnt - 1;
        else
            instMemCnt <= instMemCnt;
    endrule

    rule cell_mem_counter;
        if (cellMemReq && !cellMemResp)
            cellMemCnt <= cellMemCnt + 1;
        else if(!cellMemReq && cellMemResp)
            cellMemCnt <= cellMemCnt - 1;
        else
            cellMemCnt <= cellMemCnt;
    endrule

        // Rules for multiplexing of port A from SW and CORE
    rule drain_req_from_cell_fifo (!cmdEn && cellMemCnt == 0);
        //$display("BCpu: Request drained from the SW, port A, cell memory, time ", $time);
        let data = cellReq.first;
        cellReq.deq;
        cellMem.portA.request.put(data);
    endrule

    rule drain_req_from_cell_client (cmdEn || cellMemCnt != 0);
        //$display("BCpu: Request drained from the BCPU port A, cell memory, time ", $time);
        let data <- bCore.cell_ifc.portA.request.get();
        cellMem.portA.request.put(data);
        cellMemReq <= True;
    endrule

    rule drain_req_from_inst_fifo (!cmdEn && instMemCnt == 0);
        //$display("BCpu: Request drained from the SW, port A, inst memory, time ", $time);
        let data = instReq.first;
        instReq.deq;
        instMem.portA.request.put(data);
    endrule
    
    rule drain_req_from_inst_client (cmdEn || instMemCnt != 0);
        //$display("BCpu: Request drained from the BCPU port A, inst memory, time ", $time);
        let data <- bCore.inst_ifc.portA.request.get();
        instMem.portA.request.put(data);
        instMemReq <= True;
    endrule

    rule put_inst_back_to_bcore (cmdEn || instMemCnt != 0);
        //$display("BCpu: Pushing the response back to BCPU, port A, inst memory, time ", $time);
        let data <- instMem.portA.response.get;
        bCore.inst_ifc.portA.response.put(data);
        instMemResp <= True;
    endrule

    rule put_cell_back_to_bcore (cmdEn || cellMemCnt != 0);
        //$display("BCpu: Pushing the reponse back to the BCPU, port A, cell memory, time ", $time);
        let data <- cellMem.portA.response.get;
        bCore.cell_ifc.portA.response.put(data);
        cellMemResp <= True;
    endrule

        // Rules for the selecttion of output data from internal registers
        // or command register. Data in command register. BRAM memory is written 
        // into the FIFO, output register data are written to the special register
        // during the read and multiplexed to the output.
    (* descending_urgency = "drain_reg,drain_data_from_cell_memory_app, drain_data_from_instruction_memory_app" *)
    rule drain_data_from_cell_memory_app (!cmdEn && regCellRead);
        let ret_data <- cellMem.portA.response.get; 
        readRetData.enq(ret_data);
        regCellRead <= False;
        //$display("BCpu: Draining data from cell memory (during non-operational mode).");
        //$display("BCpu: Drained data = ", fshow(ret_data));
    endrule

    rule drain_data_from_instruction_memory_app(!cmdEn && regInstRead);
        let ret_data <- instMem.portA.response.get;
        readRetData.enq(ret_data);
        regInstRead <= False;
        //$display("BCpu: Draining data from instruction memory (during non-operational mode).");
        //$display("BCpu: Drained data = ", fshow(ret_data));
    endrule

    rule drain_reg (regSpaceRet matches tagged Valid .data &&& regRegRead);
        readRetData.enq(data);
        regSpaceRet <= tagged Invalid;
        regRegRead  <= False;
        //$display("BCpu: Draining data from the register space");
        //$display("BCpu: Drained data = ", data);
    endrule

    // Drain and apply rules which can be taken immediatelly
    // The content of the command register is interpreted in 
    // the next rule.
    (* descending_urgency = "drain_bcpu_config, apply_reg_cmd_config" *)
    rule drain_bcpu_config;
        // Update the configuration if we have something
        // to do
   
        // Take data and deque
        let configData = bcoreConfig.first;
        bcoreConfig.deq;

        // Run the configuration
        case (configData) matches
            tagged RegPc .newPc     : bCore.setPC(newPc);
            tagged RegCmd .newCmd   : regCmd <= newCmd;
            default : $display("Unknown command");
        endcase

        //  $display("BCpu: Configuration for the BCore was drained.");
    endrule

    // Configure enable/disable signals to the BCore based on the 
    // command register
    rule apply_reg_cmd_config; 
        // Take the value of the register (we will modify it)
        let tmpCmdReg = regCmd;
 
        if(stepEn || cmdEn)  begin
            // Enable the CPU, switch the step off
            bCore.setEnabled(True);
        end else begin
            bCore.setEnabled(False);
        end

        // Switch the stop off, if it was enabled (and with logical 0)
        tmpCmdReg[bitStepEnabled] = tmpCmdReg[bitStepEnabled] & 0;
        // Write new command register
        regCmd      <= tmpCmdReg;
    endrule

    rule drain_bcore_output_data (outputBcoreData matches tagged Invalid);
        //$display("Draining output data from the BCore unit");
        let data <- bCore.outputDataGet();
        outputBcoreData <= tagged Valid data;
    endrule

    rule push_bcore_input_data (inputBCoreData matches tagged Valid .d);
        //$display("Pushing inptut data to the BCore unit 0x%x",d);
        bCore.inputDataPush(d);
        inputBCoreData <= tagged Invalid;
    endrule

    // ------------------------------------------------------------------------
    // Methods 
    // ------------------------------------------------------------------------
    method Action read(BAddr addr) if (!readRunning);
        // Initial value of output data variable and enable read running
        // Top level address decoder - minimal address length is 20 bits
        //
        // 18 bits are used for the address and 20-19 are used for the selection between the
        // data memory, program memory and internal registers
        let space_addr_slice = addr[valueOf(BAddrWidth)-1:valueOf(BAddrWidth)-2];
        let mem_addr_slice   = addr[valueOf(BAddrWidth)-3:0];
        let reg_addr_slice   = addr[3:0];
        case (space_addr_slice) 
            cellSpace : begin
                regCellRead <= True;
                //$display("BCpu read: Reading the CELL memory.");
                if(!cmdEn)
                    cellReq.enq(makeBRAMRequest(False,mem_addr_slice,0));
                else
                    $display("BCpu read: It is not allowed to work with memory during the operational mode.");
            end
           instSpace  : begin
                regInstRead <= True;
                //$display("BCpu read: Reading the INSTRUCTION memory.");
                if(!cmdEn)
                    instReq.enq(makeBRAMRequest(False,mem_addr_slice,0));
                else
                    $display("BCpu read: It is not allowed to work with memory during the operational mode.");
            end
            regSpace  : begin
                //$display("BCpu read: Reading INTERNAL REGISTERS.");
                // Turn the register read
                regRegRead <= True;
                // Prepare data there & send them
                let pcVal    = bCore.getPC();
                let flagData = {'0, 
                    pack(bCore.waitingForInput()),
                    pack(bCore.getTermination()),
                    pack(bCore.getInvalidOpcode()),
                    pack(bCore.outputDataFull()),
                    pack(bCore.inputDataFull()),
                    pack(isValid(outputBcoreData))
                };

                case(reg_addr_slice)
                    'h0 : regSpaceRet <= tagged Valid regCmd;    
                    'h1 : regSpaceRet <= tagged Valid pcVal[valueOf(BDataWidth)-1:0];
                    'h2 : regSpaceRet <= tagged Valid pcVal[valueOf(BMemAddrWidth)-1:valueOf(BDataWidth)];
                    'h3 : regSpaceRet <= tagged Valid flagData;
                    'h4 : begin
                            regSpaceRet <= tagged Valid fromMaybe(0,outputBcoreData);
                            outputBcoreData <= tagged Invalid;
                        end
                    default : $display("No read operation to internal registers is performed.");
                endcase
            end // End of the Register space
           default : begin
                $display("BCpu read: Required address space wasn't found.");
            end
        endcase

        //$display("BCpu read: Read method fired on address 0x%x",addr);
    endmethod

    method ActionValue#(BData) getData();
        // Unlock the read part and after the data are read out
        let data = readRetData.first;
        readRetData.deq(); 
        //$display("BCpu read: Returned data --> 0x%x",data);
        //$display("BCpu read done in time ", $time);
        return data;
    endmethod

    method Action write(BAddr addr, BData data);// if (!writeRunning);

        // Top level address decoder - two top-level bits are used
        // for indexing of the address space
        let space_addr_slice = addr[valueOf(BAddrWidth)-1:valueOf(BAddrWidth)-2];
        let mem_addr_slice   = addr[valueOf(BAddrWidth)-3:0];
        let reg_addr_slice   = addr[3:0];

        case (space_addr_slice) 
            cellSpace : begin
                //$display("BCpu write: Writing the CELL memory.");
                if(!cmdEn)
                    cellReq.enq(makeBRAMRequest(True,mem_addr_slice,data));
                else
                    $display("BCpu write: It is not allowed to work with memory during the operational mode.");
           end
           instSpace  : begin
                //$display("BCpu write: Writing the INSTRUCTION memory.");
                if(!cmdEn)
                    instReq.enq(makeBRAMRequest(True,mem_addr_slice,data));
                else
                    $display("BCpu write: It is not allowed to work with memory during the operational mode."); 
            end
            regSpace  : begin
                //$display("BCpu write: Writing INTERNAL REGISTERS.");
                case(reg_addr_slice)
                   'h0 : bcoreConfig.enq(tagged RegCmd data);            
                   'h1 : regWorkPcLsb   <= data;
                   'h2 : begin
                            // Setup new PC based on passed data
                            let tmpPc = {data,regWorkPcLsb};
                            let newPc = unpack(tmpPc[valueOf(BMemAddrWidth)-1:0]);
                            bcoreConfig.enq(tagged RegPc newPc);
                        end
                    'h3: $display("This offset is allocated for flag registers which are read-only.");
                    'h4: inputBCoreData <= tagged Valid data;
                    default : $display("No write operation to internal registers is performed.");
                endcase
            end
            default : begin
                $display("BCpu write: Required address space wasn't found.");
            end
        endcase

       //$display("BCpu: Write method fired -->  0x%x", addr, " data --> 0x%x",data);
    endmethod

    method Bool getReadRunning();
        return readRunning;
    endmethod

    method Bool getCpuEnabled();
        return cmdEn;
    endmethod

endmodule : mkBCpuInit

// Module without the inilization
(* synthesize *)
module mkBCpu(BCpu_IFC);
    BCpu_IFC rIfc <- mkBCpuInit(None);
    return rIfc;
endmodule : mkBCpu

endpackage : bcpu
