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
import TbCommon :: *;
import StmtFSM  :: *;

(* synthesize *)
module mkTbAddr (Empty);

    BCpu_IFC mcpu <- mkBCpu;

    // Helping loop index register
    Reg#(UInt#(32)) idx     <- mkReg(0);

    Reg#(BData) data_reg0   <- mkReg(0);
    Reg#(BAddr) addr_reg0   <- mkReg(0);
    Reg#(BData) data_reg1   <- mkReg(0);
    Reg#(BAddr) addr_reg1   <- mkReg(0);

    // Testing data for the PC
    BData pc0 = 'h31;
    BData pc1 = 'h02;

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
                    report_and_stop(1);
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

        $display("Try to write the step enabled and check if the  unit was enabled");
        mcpu.write(getAddress(regSpace,0),'h2);
        delay(1);
        mcpu.read(getAddress(regSpace,0));
        action
            let ret <- mcpu.getData();
            if(ret != 0) begin
                $display("Step flag has to be zero now.");
                report_and_stop(1);
            end
            $displayh("Command register during the EN mode --> 0x",ret);
        endaction

        delay(10);
        $display("PC testing - upload and download of the value");
        mcpu.write(getAddress(regSpace,1), pc0);
        mcpu.write(getAddress(regSpace,2), pc1);
        mcpu.read(getAddress(regSpace,1));
        action
            let readData <- mcpu.getData();
            data_reg0 <= readData;
            mcpu.read(getAddress(regSpace,2));
        endaction
        action 
            let readData <-  mcpu.getData();
            data_reg1 <= readData;
        endaction   
        action
            if(data_reg0 != pc0 && data_reg1 != pc1)begin
                $display("PC value read/write is not working!");
                $display("* expected - 0x",pc1," (MSB) and 0x",pc0," (LSB)");
                $displayh("* received - 0x",addr_reg1,"(MSB) and 0x",addr_reg0," (LSB)");
                report_and_stop(1);
            end
        endaction
        $display("PC testing was finished!!");
        $display("== END READ & WRITE tests ===========");  
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbAddr 

endpackage : Tb