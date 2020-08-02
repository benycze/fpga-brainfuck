
// -------------------------------------------------------------------------------
//  PROJECT: FPGA Brainfuck
// -------------------------------------------------------------------------------
//  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
//  LICENSE: The MIT License (MIT), please read LICENSE file
//  WEBSITE: https://github.com/benycze/fpga-brainfuck/
// -------------------------------------------------------------------------------

package TbCommon;

    // Function which prints the result and ends the computation, the passed
    // parater is the return code.
    function Action report_and_stop(Integer ret);
        return action 
            $display("RESULT=",ret);
            $finish();
        endaction;
    endfunction
    
endpackage : TbCommon