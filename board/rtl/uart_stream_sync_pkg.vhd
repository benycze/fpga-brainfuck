-- -------------------------------------------------------------------------------
--  PROJECT: FPGA Brainfuck
-- -------------------------------------------------------------------------------
--  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
--  LICENSE: The MIT License (MIT), please read LICENSE file
--  WEBSITE: https://github.com/benycze/fpga-brainfuck/
-- -------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package uart_sync_pkg is
    
    -- Write command 
    constant CMD_WRITE  : std_logic_vector(7 downto 0) := x"00"; 
    -- Read command 
    constant CMD_READ   : std_logic_vector(7 downto 0) := x"01";
    -- Acknowledge of the asserted write command
    constant CMD_ACK    : std_logic_vector(7 downto 0) := x"02";

end package ;