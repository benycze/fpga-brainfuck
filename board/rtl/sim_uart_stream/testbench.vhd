--------------------------------------------------------------------------------
-- PROJECT: FPGA Brainfuck
--------------------------------------------------------------------------------
-- MODULE:  TESTBANCH OF UART TOP MODULE
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- LICENSE: The MIT License (MIT), please read LICENSE file
-- WEBSITE: https://github.com/jakubcabal/uart-for-fpga
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity testbench is
end testbench;

architecture full of testbench is

    -- Clock & reset folks
    signal CLK_RX           : std_logic;
	signal RESET_RX         : std_logic;
	signal CLK_TX           : std_logic;
	signal RESET_TX         : std_logic;

    constant clk_rx_period  : time := 10 ns;
    constant clk_tx_period  : time := 5 ns;
    
    -- Number of clock cycles in the reset state
    constant RESET_RX_PERIOD    : integer := 3;
    constant RESET_TX_PERIOD    : integer := 3;

begin
    -- ------------------------------------------------------------------------
    -- DUT 
    -- ------------------------------------------------------------------------
    --TODO

    -- ------------------------------------------------------------------------
    -- Clock & reset generation
    -- ------------------------------------------------------------------------

	clk_rx_process : process
	begin
		CLK_RX <= '0';
		wait for clk_rx_period/2;
		CLK_RX <= '1';
		wait for clk_rx_period/2;
	end process;

	reset_rx_gen_p : process
	begin
		RESET_RX <= '1';
		wait for clk_rx_period*RESET_RX_PERIOD;
      	RESET_RX <= '0';
		wait;
	end process;
	
    clk_tx_process : process
	begin
		CLK_TX <= '0';
		wait for clk_tx_period/2;
		CLK_TX <= '1';
		wait for clk_tx_period/2;
	end process;

	reset_tx_gen_p : process
	begin
		RESET_TX <= '1';
		wait for clk_tx_period*RESET_TX_PERIOD;
      	RESET_TX <= '0';
		wait;
	end process;

    -- ------------------------------------------------------------------------
    -- Testbench 
    -- ------------------------------------------------------------------------
    -- TODO

end architecture;
