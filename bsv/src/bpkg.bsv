// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bpkg;

import BRAM :: *;

// Typedefs ---------------------------------------------------------

// Address for reading from the BCpu entity
typedef 16 BAddrWidth;
typedef Bit#(BAddrWidth) BAddr;

// Data written via the write transaction to the BCpu
typedef 8 BDataWidth;
typedef Bit#(BDataWidth) BData;

// BRAM memory address types (should be two words)
typedef 14 BMemAddrWidth;
typedef Bit#(BMemAddrWidth) BMemAddress;

// Address space constants
Bit#(2) cellSpace = 'b00;
Bit#(2) instSpace = 'b01;
Bit#(2) regSpace  = 'b10;

// Indexes of the command register
Integer bitEnabled     = 0;
Integer bitStepEnabled = 1;

// Configuration of the BCore
Integer bCoreInoutSize = 1024;

// Generate the address from given space and shift inside the space
function BAddr getAddress(Bit#(2) space, Bit#(n) shiftInSpace) provisos(Add#(n, 2, BAddrWidth));
    return {space,shiftInSpace};    
endfunction

// Helping functions ------------------------------------------------

// Create a BRAM request which will be passed to the BRAM
// - write - write transaction is asserted
// - addr  - address to use
// - data  - data to write
function BRAMRequest#(typeAddr, typeData) makeBRAMRequest(Bool write, typeAddr addr, typeData data) 
    provisos (Bits#(typeAddr, n_typeAddr), Bits#(typeData, n_typeData)); 

    return BRAMRequest{ write: write, responseOnWrite:False, address: addr, datain: data }; 
endfunction

endpackage : bpkg