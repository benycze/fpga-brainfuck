// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package Tb;

import bcpu :: *;
import bpkg :: *;

import StmtFSM :: *;

(* synthesize *)
module mkTb (Empty);

    BCpu_IFC mcpu <- mkBCpu;

    // Helping loop index register
    Reg#(UInt#(32)) idx     <- mkReg(0);

    Reg#(BData) data_reg0   <- mkReg(0);
    Reg#(BAddr) addr_reg0   <- mkReg(0);
    Reg#(BData) data_reg1   <- mkReg(0);
    Reg#(BAddr) addr_reg1   <- mkReg(0);

    Stmt fsmMemTest = seq 
        $display(" == READ & WRITE tests ==============");
        $display("Testing read/write to cell memory ...");

         // Run the test
        for(idx <= 0; idx < 255; idx <= idx + 1) seq
            action 
                $display("Write to BRAM started in time ",$time);
                BAddr addr = truncate(pack(idx));
                BData data = truncate(pack(idx));
                data_reg0 <= data;
                addr_reg0 <= addr;
                mcpu.write(addr,data);
            endaction

            action 
                $display("Read request started in time ",$time);
                let ret     <- mcpu.read(addr_reg0);
                // Store reference data to the next cycle
                data_reg1 <= data_reg0;
                addr_reg1 <= addr_reg0;
            endaction

            action
                let ret <- mcpu.getData();
                if(ret != data_reg1)begin   
                    $displayh("Read data 0x",ret," and write data 0x",idx," doesn't match!");
                    $finish(1);
                end
            endaction
        endseq

        $display("Enable the operation and try to read a register (read running = ", mcpu.getReadRunning(), ") ...");
        mcpu.write(getAddress(regSpace,0),'h1);
        $display("Unit enable = ",mcpu.getCpuEnabled());
        mcpu.read(getAddress(regSpace,0));
        action
            let ret <- mcpu.getData();
            $displayh("Command register during the EN mode --> 0x",ret);
        endaction
        mcpu.write(getAddress(regSpace,0),'h0);

        $display("== END READ & WRITE tests ===========");  
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTb 

endpackage : Tb