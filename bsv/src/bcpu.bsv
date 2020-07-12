// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcpu;

import bpkg  :: *;
import FIFO  :: *;
import bmem  :: *;
import BRAM  :: *;

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

(* synthesize *)
module mkBCpu(BCpu_IFC);
    
    // ------------------------------------------------------------------------
    // Registers & components 
    // ------------------------------------------------------------------------

    // Registers ------------------------------------------
        // Program counter (we need to address the whole BRAM address space
    Reg#(BMemAddress)   regPc  <- mkReg(0);
        // Command register (8 bits)
    Reg#(Bit#(8))       regCmd <- mkReg(0);
        // Parse the command register
    Bool cmdEn =  unpack(regCmd[0]);

    // Memory blocks --------------------------------------
        // Cell memory
    BRAM_Configure cellCfg = defaultValue;
    cellCfg.allowWriteResponseBypass = False;
    BMem_IFC#(BMemAddress, BData)  cellMem <- mkBMEM(cellCfg);    

        // Instruction memory
    BRAM_Configure instCfg = defaultValue;
    instCfg.allowWriteResponseBypass = False;
    BMem_IFC#(BMemAddress, BData) instMem <- mkBMEM(instCfg);   
    
        // Helping registers
    Reg#(Bool)              readRunning     <- mkReg(False);
    Reg#(BData)             outRegData      <- mkReg(0);       
    Reg#(Bool)              dataDrained     <- mkReg(False);
    Reg#(Maybe#(BData))     regSpaceRet     <- mkReg(tagged Invalid);
    FIFO#(BData)            readRetData     <- mkFIFO;

    // ------------------------------------------------------------------------
    // Rules 
    // ------------------------------------------------------------------------

        // Rules for the selecction of output data from internal registers
        // or command register. Data in command register. BRAM memory is written 
        // into the FIFO, output register data are written to the special register
        // during the read and multiplexed to the output.
    rule drain_data_from_cell_memory (!cmdEn);
        let ret_data <- cellMem.memGetReadResponse(); 
        readRetData.enq(ret_data);
        readRunning <= False;
        $display("BCpu: draining data from cell memory.");
    endrule

    rule drain_data_from_instruction_memory(!cmdEn);
        let ret_data <- instMem.memGetReadResponse();
        readRetData.enq(ret_data);
        readRunning <= False;
        $display("BCpu: draining data from instruction memory.");
    endrule

    rule drain_reg (regSpaceRet matches tagged Valid .data);
        readRetData.enq(data);
        regSpaceRet <= tagged Invalid;
        readRunning <= False;
        $display("BCpu: draining data from the register space");
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
            //cellSpace  : begin
            cellSpace : begin
                $display("BCpu read: Reading the CELL memory.");
                if(!cmdEn)
                    cellMem.memPutReadReq(mem_addr_slice);
                else
                    $display("BCpu read: It is not allowed to work with memory during the operational mode.");
            end
           instSpace  : begin
                $display("BCpu read: Reading the INSTRUCTION memory.");
                if(!cmdEn)
                    cellMem.memPutReadReq(mem_addr_slice);
                else
                    $display("BCpu read: It is not allowed to work with memory during the operational mode.");
            end
            regSpace  : begin
                $display("BCpu read: Reading INTERNAL REGISTERS.");
                case(reg_addr_slice)
                    'h0 : regSpaceRet <= tagged Valid regCmd;                    
                    default : $display("No read operation to internal registers is performed.");
                endcase
            end
           default : begin
                $display("BCpu read: Required address space wasn't found.");
            end
        endcase
        readRunning <= True;

        $displayh("BCpu read: Read method fired on address 0x",addr);
    endmethod

    method ActionValue#(BData) getData();
        // Unlock the read part and after the data are read out
        let data = readRetData.first;
        readRetData.deq(); 
        $displayh("BCpu read: Returned data --> 0x",data);
        return data;
    endmethod

    method Action write(BAddr addr, BData data);

        // Top level address decoder - two top-level bits are used
        // for indexing of the address space
        let space_addr_slice = addr[valueOf(BAddrWidth)-1:valueOf(BAddrWidth)-2];
        let mem_addr_slice   = addr[valueOf(BAddrWidth)-3:0];
        let reg_addr_slice   = addr[3:0];

        case (space_addr_slice) 
            cellSpace : begin
                $display("BCpu write: Writing the CELL memory.");
                cellMem.memPutWriteReq(mem_addr_slice,data);
            end
           instSpace  : begin
                $display("BCpu write: Writing the INSTRUCTION memory.");
                cellMem.memPutWriteReq(mem_addr_slice,data);
            end
            regSpace  : begin
                $display("BCpu write: Writing INTERNAL REGISTERS.");
                case(reg_addr_slice)
                   'h0 : regCmd <= data;                    
                    default : $display("No write operation to internal registers is performed.");
                endcase
            end
            default : begin
                $display("BCpu write: Required address space wasn't found.");
            end
        endcase

        $displayh("BCpu: Write method fired -->  0x", addr, " data --> 0x",data);
    endmethod

    method Bool getReadRunning();
        return readRunning;
    endmethod

    method Bool getCpuEnabled();
        return cmdEn;
    endmethod

endmodule : mkBCpu

endpackage : bcpu