// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

// Wrapper around the BRAM memory which solves the precedence

package bmem;

import BRAM  :: *;
import FIFO  :: *;
import FIFOF ::*;
import bpkg  :: *;

interface BMem_IFC#(type typeAddr, type typeData);

    // SW and BMEM interface cannot be used in the same time !!
    // The BSC compiler check this during the translation. No additional
    // code is given there to check the situation. Therefore, if you
    // want to work with the SW part, stop the processing of the HW first.
    
    // SW interface ------------------------------------------
    // Used during the non-active mode (debugging, before the start of the 
    // program and so on). This part of the interface is optimized for
    // multiple reads & writes from the SW 

    // Insert the read request into the memory
    method Action memPutReadReq(typeAddr addr);
    // Insert the write request into the memory
    method Action memPutWriteReq(typeAddr addr, typeData data);
    // Get the read data
    method ActionValue#(typeData) memGetReadResponse();

    // BMEM interface for the application ----------------------
    // Used during the normal operation (no latency), direct access
    interface BRAM2Port#(typeAddr, typeData) bram_ifc;

    // Debug interface -----------------------------------------
    // Special helping debug methods which allows us to 
    // get the last accessed data (read/write) via the memPut* methods.
    // The user is able to get:
    // * Last request data
    // * Last used address (Read/Write)
    // * Last operation (Read/Write)
    // * Returned data from the BRAM (during the read)
    method typeAddr getLastInReqAddr();
    method typeData getLastReqData();
    method typeData getReturnedData();

    // Returns True iff we were requesting the write operation
    // Returns False iff we were requesting the read operation
    // WARNING: Default value is False!!!
    method Bool getLastReqOperation();
    // Number of performed Reads
    method UInt#(10) getReadCount();
endinterface

module mkBMEM #(parameter BRAM_Configure cfg) (BMem_IFC#(typeAddr,typeData)) provisos(
    Bits#(typeAddr,n_typeAddr), Bits#(typeData,n_typeData), Literal#(typeData),
    Eq#(typeAddr), Literal#(typeAddr)
);

    // ----------------------------------------------------
    // Componetns & helping FIFO fronts
    // ----------------------------------------------------
    BRAM2Port#(typeAddr,typeData) cellMemory                <- mkBRAM2Server(cfg);
    FIFOF#(BRAMRequest#(typeAddr, typeData)) readReqFifo    <- mkFIFOF;
    FIFOF#(BRAMRequest#(typeAddr, typeData)) writeReqFifo   <- mkFIFOF;
    FIFO#(typeData)                          retDataFifo    <- mkFIFO;
    Reg#(Bool) wr_rd_switch                         <- mkReg(False);
    Reg#(typeData) returnedBramData                 <- mkReg(0);
    Reg#(BRAMRequest#(typeAddr, typeData)) lastReq  <- mkReg(BRAMRequest {write: False, 
                                                                         responseOnWrite: False, 
                                                                         address: 0, datain: 0} );

    Reg#(UInt#(10)) cntReads                        <- mkReg(0);

    // ----------------------------------------------------
    // Rules and methods
    // ----------------------------------------------------

    rule rule_return_read_req;
        let data <- cellMemory.portA.response.get;
        returnedBramData <= data;
        retDataFifo.enq(data);
        cntReads <= cntReads + 1;
    endrule

    rule rule_fire_bram_cell_both;
        // Both FIFO fronts are available with some requests. Therefore,
        // we will fire this rule and checks what will be fired first
        let addrRd = readReqFifo.first.address;
        let addrWr = writeReqFifo.first.address;
        if(addrRd == addrWr)begin
            // Addresses are same, take the read request
            let req = writeReqFifo.first;
            $display("bmem: addresses are same (write) --> ",req);
            cellMemory.portA.request.put(req);
            writeReqFifo.deq();
        end else begin
            // Addresses are not same, take the request based 
            // on the roudn robin
            if(wr_rd_switch) begin
                // Take the read
                let req = readReqFifo.first;
                cellMemory.portA.request.put(req);
                readReqFifo.deq();
                $display("bmem: addresses are not same (read) --> ",req);
            end else begin
                // Take the write
                let req = writeReqFifo.first;
                cellMemory.portA.request.put(req);
                writeReqFifo.deq();
                $display("bmem: addresses are not same (write) --> ",req);
            end
            // Switch the round robin
            wr_rd_switch <= !wr_rd_switch;
        end // End of addr == addrwr
    endrule

    rule rule_fire_bram_cell_rd (!writeReqFifo.notEmpty());
        // Only the READ request FIFO is available
        let req = readReqFifo.first;
        cellMemory.portA.request.put(req);
        readReqFifo.deq();
        lastReq <= req;
        $display("bmem: addresses are not same (read) --> ",req);
    endrule

    rule rule_fire_bram_cell_wr(!readReqFifo.notEmpty());
        // Only the write fifo is available
        let req = writeReqFifo.first;
        cellMemory.portA.request.put(req);
        writeReqFifo.deq();
        lastReq <= req;
        $display("bmem: addresses are not same (write) --> ",req);
    endrule

    // ----------------------------------------------------
    // Methods 
    // ----------------------------------------------------

    method Action memPutReadReq(typeAddr addr);
        let req = makeBRAMRequest(False, addr, 0);
        readReqFifo.enq(req);
        $display("bmem: Inserting read request");
    endmethod

    method Action memPutWriteReq(typeAddr addr, typeData data);
        let req = makeBRAMRequest(True, addr, data);
        writeReqFifo.enq(req);
        $display("bmem: Inserting write request");
    endmethod

    method ActionValue#(typeData) memGetReadResponse();
        let ret = retDataFifo.first;
        retDataFifo.deq();
        $display("bmem: getReadResponse");
        return ret;
    endmethod

    method typeAddr getLastInReqAddr();
        return lastReq.address;
    endmethod 

    method typeData getLastReqData();
        return lastReq.datain;
    endmethod

    method typeData getReturnedData();
        return returnedBramData;
    endmethod

    method Bool getLastReqOperation();
        return lastReq.write;
    endmethod

    method UInt#(10) getReadCount();
        return cntReads;
    endmethod

    // ----------------------------------------------------
    // Expose the internal interface of the BRAM
    // ----------------------------------------------------
    interface bram_ifc = cellMemory;

endmodule 

endpackage : bmem