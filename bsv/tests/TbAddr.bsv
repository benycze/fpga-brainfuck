// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package TbAddr;

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
        $display("Instruction memory initilization init to zeros ...");
        for(idx <= 0; idx < fromInteger(2 ** valueOf(BMemAddrWidth)); idx <= idx + 1) seq
            action 
                //$display("Write to BRAM started in time ",$time);
                BAddr addr = truncate(pack('h4000 + idx));
                mcpu.write(addr,'h0);
            endaction
        endseq

        $display("Enable the operation and try to read a register (read running = ", mcpu.getReadRunning(), ") ...");
        mcpu.write(getAddress(regSpace,0),'h1);
        $display("Unit enable = ",mcpu.getCpuEnabled());
        mcpu.read(getAddress(regSpace,0));
        action
            let ret <- mcpu.getData();
            $display("Command register during the EN mode --> 0x%x",ret);
        endaction
        $display("Disabling the unit ...");
        mcpu.write(getAddress(regSpace,0),'h0);
        delay(5);

        $display("Try to write the step enabled and check if the unit was enabled");
        mcpu.write(getAddress(regSpace,0),'h2);
        delay(2);
        mcpu.read(getAddress(regSpace,0));
        action
            let ret <- mcpu.getData();
            if(ret != 0) begin
                $display("Step flag has to be zero now.");
                report_and_stop(1);
            end
            $display("Command register during the EN mode --> 0x%x",ret);
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
                $display("* expected - 0x%x",pc1," (MSB) and 0x%x",pc0," (LSB)");
                $display("* received - 0x%x",addr_reg1,"(MSB) and 0x%x",addr_reg0," (LSB)");
                
                report_and_stop(1);
            end
        endaction
        $display("PC testing was finished!! Time = ", $time);

         // Run the test
        delay(20);
        $display("Testing read/write to cell memory. Time =", $time);
        for(idx <= 0; idx < fromInteger(2 ** valueOf(BMemAddrWidth)); idx <= idx + 1) seq
            action 
                //$display("Write to BRAM started in time ",$time);
                BAddr addr = truncate(pack(idx));
                BData data = truncate(pack(idx));
                data_reg0 <= data;
                addr_reg0 <= addr;
                mcpu.write(addr,data);
            endaction

            action 
                //$display("Read request started in time ",$time);
                let ret     <- mcpu.read(addr_reg0);
                // Store reference data to the next cycle
                data_reg1 <= data_reg0;
                addr_reg1 <= addr_reg0;
            endaction

            action
                let ret <- mcpu.getData();
                if(ret != data_reg1)begin   
                    $display("Read data 0x%x",ret," and write data 0x%x",idx," doesn't match!");
                    report_and_stop(1);
                end
            endaction
        endseq

        $display("== END READ & WRITE tests ===========");  
        report_and_stop(0);
    endseq;

    mkAutoFSM(fsmMemTest);

endmodule : mkTbAddr 

endpackage : TbAddr
