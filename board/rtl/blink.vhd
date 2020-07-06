-- -------------------------------------------------------------------------------
--  PROJECT: FPGA Brainfuck
-- -------------------------------------------------------------------------------
--  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
--  LICENSE: The MIT License (MIT), please read LICENSE file
--  WEBSITE: https://github.com/benycze/fpga-brainfuck/
-- -------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  generic (
      -- Counter signal width. The counter signal widht
      -- is based on the passed flock frequency. For example,
      -- if input clock is 12MHz and you want a 1s flash, then you
      -- need log2(12e6) bits to represent a one second.
      CNT_WIDTH     : natural := 24
  );
  port (
    -- --------------------------------
    -- Clocks & Reset 
    ----------------------------------- 
    CLK		        : in std_logic;
    RESET           : in std_logic; 

    -- --------------------------------
    -- Input interface
    -- --------------------------------
    INDIC_EN        : in std_logic;

    -- --------------------------------
    -- Output interface 
    -- --------------------------------
    LED_EN          : out std_logic
) ;
end blink ;

architecture full of blink is

    signal cnt_sig  : unsigned(CNT_WIDTH downto 0);
    signal reg_en   : std_logic;
    signal cnt_done : std_logic;

begin

    reg_enp : process( CLK )
    begin
        if(rising_edge(CLK))then
            if(RESET = '1' or cnt_done = '1')then
                reg_en <= '0';
            else 
                if(INDIC_EN = '1' and reg_en = '0')then
                    reg_en <= '1';
                end if;
            end if;
        end if;
    end process ; -- reg_enp

    -- Generation of the done signal - we are done when the MSB bit is 1 and 
    -- signalization is enabled
    cnt_done <= std_logic(cnt_sig(CNT_WIDTH)) and reg_en;

    -- Counter for counting of one second - it is one bit longer to catch the moment 
    -- when we reached the full value of CNT_WIDTH-1
    cntp : process( CLK )
    begin
        if(rising_edge(CLK))then
            if(RESET = '1' or cnt_done = '1')then
                cnt_sig <= (others => '0');
            else
                if(reg_en = '1')then
                    cnt_sig <= cnt_sig + 1;
                end if;
            end if ;
        end if;
    end process ; -- cntp

    -- LED output is connected to the MSB-1 position (we will have it enabled for
    -- the half of the counting period). It is negated because we want to turn the 
    -- LED on in the beginning
    LED_EN <= not std_logic(cnt_sig(CNT_WIDTH-1)) and reg_en;

end architecture ; -- full