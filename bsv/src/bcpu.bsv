// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcpu;

import bpkg :: *;
import FIFO :: *;
import bmem :: *;
import BRAM :: *;

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
    
        // Helping componets
    FIFO#(BData)            retDataFifo     <- mkFIFO;
    Reg#(Bool)              readRunning     <- mkReg(False);
    Reg#(Maybe#(BData))     outRegData      <- mkReg(Invalid);      

    // ------------------------------------------------------------------------
    // Rules 
    // ------------------------------------------------------------------------

        // Rules for the selecction of output data from internal registers
        // or command register. Data in command register. BRAM memory is written 
        // into the FIFO, output register data are written to the special register
        // during the read and multiplexed to the output.
    rule drain_data_from_cell_memory (!cmdEn && readRunning);
        let ret_data <- cellMem.memGetReadResponse();    
        retDataFifo.enq(ret_data);
    endrule

    rule drain_data_from_instruction_memory(!cmdEn && readRunning);
        let ret_data <- instMem.memGetReadResponse();
        retDataFifo.enq(ret_data);
    endrule

    rule drain_ouput_reg(outRegData  matches tagged Valid .d);
        retDataFifo.enq(d);
    endrule

    // ------------------------------------------------------------------------
    // Methods 
    // ------------------------------------------------------------------------
    method Action read(BAddr addr) if(!readRunning);
        // Initial value of output data variable and enable read running
        BData ret_data = 'h0;
        readRunning <= True;
        
        // Top level address decoder - minimal address length is 20 bits
        //
        // 18 bits are used for the address and 20-19 are used for the selection between the
        // data memory, program memory and internal registers
        let space_addr_slice = addr[valueOf(BAddrWidth)-1:valueOf(BAddrWidth)-2];
        let mem_addr_slice   = addr[valueOf(BAddrWidth)-3:0];
        let reg_addr_slice   = addr[3:0];
        case (space_addr_slice) 
            cellSpace  : begin
                $display("BCpu read: Reading the CELL memory.");
                cellMem.memPutReadReq(mem_addr_slice);
            end
           instSpace  : begin
                $display("BCpu read: Reading the INSTRUCTION memory.");
                cellMem.memPutReadReq(mem_addr_slice);
            end
           regSpace : begin
                $display("BCpu read: Reading INTERNAL REGISTERS.");
                case(reg_addr_slice)
                    'h0 : outRegData <= tagged Valid regCmd;                    
                    default : $display("No read operation to internal registers is performed.");
                endcase
            end
           default : begin
                $display("BCpu read: Required address space wasn't found.");
            end
        endcase

        $displayh("BCpu read: Read method fired on address 0x",addr);
    endmethod

    method ActionValue#(BData) getData();
        readRunning <= False;
        // Mark the read operation as finished, get the data
        // and return them to the sender
        let ret = retDataFifo.first;
        retDataFifo.deq();
        $displayh("BCpu read: Returned data --> 0x",ret);
        return ret;
    endmethod

    method Action write(BAddr addr, BData data) if (!readRunning);

        // Top level address decoder - two top-level bits are used
        // for indexing of the address space
        let space_addr_slice = addr[valueOf(BAddrWidth)-1:valueOf(BAddrWidth)-2];
        let mem_addr_slice   = addr[valueOf(BAddrWidth)-3:0];
        let reg_addr_slice   = addr[3:0];

        case (space_addr_slice) 
            cellSpace  : begin
                $display("BCpu write: Writing the CELL memory.");
                cellMem.memPutWriteReq(mem_addr_slice,data);
            end
           instSpace  : begin
                $display("BCpu write: Writing the INSTRUCTION memory.");
                cellMem.memPutWriteReq(mem_addr_slice,data);
            end
            regSpace : begin
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