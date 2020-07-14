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

    // BRAM Wrapper (to simplify the code)
    method Action memPutReadReqA(typeAddr addr);
    // Insert the write request into the memory
    method Action memPutWriteReqA(typeAddr addr, typeData data);
    // Get the read data
    method ActionValue#(typeData) memGetReadResponseA();


    // BRAM Wrapper (to simplify the code)
    method Action memPutReadReqB(typeAddr addr);
    // Insert the write request into the memory
    method Action memPutWriteReqB(typeAddr addr, typeData data);
    // Get the read data
    method ActionValue#(typeData) memGetReadResponseB();

endinterface

module mkBMEM #(parameter BRAM_Configure cfg) (BMem_IFC#(typeAddr,typeData)) provisos(
    Bits#(typeAddr,n_typeAddr), Bits#(typeData,n_typeData), Literal#(typeData),
    Eq#(typeAddr), Literal#(typeAddr)
);

    BRAM2Port#(typeAddr,typeData) cellMemory <- mkBRAM2Server(cfg);

    method Action memPutReadReqA(typeAddr addr);
        let req = makeBRAMRequest(False, addr, 0);
        cellMemory.portA.request.put(req);
        $display("bmem: Inserting read request A.");
    endmethod

    method Action memPutWriteReqA(typeAddr addr, typeData data);
        let req = makeBRAMRequest(True, addr, data);
        cellMemory.portA.request.put(req);
        $display("bmem: Inserting write request A.");
    endmethod

    method ActionValue#(typeData) memGetReadResponseA();
        let ret <- cellMemory.portA.response.get;
        $display("bmem: getReadResponse A.");
        return ret;
    endmethod

    method Action memPutReadReqB(typeAddr addr);
        let req = makeBRAMRequest(False, addr, 0);
        cellMemory.portB.request.put(req);
        $display("bmem: Inserting read request B.");
    endmethod

    method Action memPutWriteReqB(typeAddr addr, typeData data);
        let req = makeBRAMRequest(True, addr, data);
        cellMemory.portB.request.put(req);
        $display("bmem: Inserting write request B.");
    endmethod

    method ActionValue#(typeData) memGetReadResponseB();
        let ret <- cellMemory.portB.response.get;
        $display("bmem: getReadResponse B.");
        return ret;
    endmethod

endmodule 

endpackage : bmem