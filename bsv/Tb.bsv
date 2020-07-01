// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package Tb;

import bcpu :: *;

    (* synthesize *)
    module mkTb (Empty);

        BCpu_IFC mcpu <- mkBCpu;
        
        rule hello_rule;
            let res = mcpu.getValue();
            $display("Hello world --> my number is ", res);
            $finish;
        endrule

    endmodule : mkTb 

endpackage : Tb