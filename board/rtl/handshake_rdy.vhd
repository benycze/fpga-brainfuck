-- -------------------------------------------------------------------------------
--  PROJECT: FPGA Brainfuck
-- -------------------------------------------------------------------------------
--  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
--  LICENSE: The MIT License (MIT), please read LICENSE file
--  WEBSITE: https://github.com/benycze/fpga-brainfuck/
-- -------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity handshake_rdy is
  port (
    -- --------------------------------
    -- Clocks & Reset
    -- --------------------------------
    CLK      : in std_logic;
    RESET    : in std_logic;

    -- --------------------------------
    -- Input & output
    -- --------------------------------
    DATA_SENT       : in std_logic;
    DATA_SENDING    : in std_logic;
    VLD             : in std_logic;

    DATA_RDY        : out std_logic
  ) ;
end handshake_rdy ;

architecture full of handshake_rdy is

    -- FSM ------------------------------
    type FSM_State_t is (RDY,CMT,SENDING);

    signal reg_state    : FSM_State_t;
    signal next_state   : FSM_State_t;

begin

    fsm_state_regp:process(CLK)
    begin
      if(rising_edge(CLK))then
        if(RESET = '1')then
          reg_state <= RDY;
        else
          reg_state <= next_state;
        end if;
      end if;
    end process;

    next_statep:process( all )
    begin
        -- Default values
        next_state <= reg_state;

        case( reg_state ) is
        
            when RDY =>
                -- In this state, we are ready to accept any request from the input when VLD comes to '1'
                -- In such situation we need to go to the sending state and stop a redy signal for one clock 
                -- cycle untill the unit is sending data (which is in the next state).
                if(VLD = '1')then
                    next_state <= CMT;
                end if;

            when CMT =>
                -- We are commiting that data can be taken, we are waiting there until the sending signal is asserted high.
                -- RDY signal is set to '1' whe
                if(DATA_SENDING = '1')then
                    next_state <= SENDING;
                end if;

            when SENDING =>               
                -- In this state, we need to wait until data are being transfered to another clock domain. This situation
                -- is signalized using the SENT signal. We are also not accepting any 
                if(DATA_SENT = '1')then
                    next_state <= RDY;
                end if;
         
            when others => null;
        
        end case ;

    end process;

    out_genp : process( all )
    begin
        -- Default signal values
        DATA_RDY <= '1';

        case( reg_state ) is
        
            when RDY =>
                -- We need to stop sending when the VLD signal comes (we need to hold data to the next clock cycle)
                if(VLD = '1')then
                    DATA_RDY <= '0';
                end if;
            
            when CMT => 
                -- We need to commit the data after the sending signal is asserted
                DATA_RDY <= '0';
                if(DATA_SENDING = '1')then
                    DATA_RDY <= '1';
                end if;

            when SENDING =>
                -- We are holing RDY inactive until. RDY signal will be activated in the 
                -- RDY state.
                DATA_RDY <= '0';
        
            when others => null;
        
        end case ;
    end process ; -- out_genp

end architecture ; -- full