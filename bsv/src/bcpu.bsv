// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package bcpu;

interface BCpu_IFC;
    method ActionValue#(int) getValue();
endinterface

(* synthesize *)
module mkBCpu(BCpu_IFC);
    
    method ActionValue#(int) getValue();
        return 42;
    endmethod

endmodule : mkBCpu

endpackage : bcpu