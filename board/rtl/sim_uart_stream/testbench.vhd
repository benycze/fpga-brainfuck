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

library work;

entity testbench is
end testbench;

architecture full of testbench is

    -- Clock & reset folks --------------------------------
    signal CLK_RX           : std_logic;
	signal RESET_RX         : std_logic;
	signal CLK_TX           : std_logic;
	signal RESET_TX         : std_logic;

    constant clk_rx_period  : time := 10 ns;
    constant clk_tx_period  : time := 5 ns;
    
    -- Number of clock cycles in the reset state
    constant RESET_RX_PERIOD    : integer := 3;
	constant RESET_TX_PERIOD    : integer := 3;
	
	-- Signals --------------------------------------------
	signal rx_din 				: std_logic_vector(7 downto 0);
	signal rx_din_vld			: std_logic;
	signal rx_din_rdy           : std_logic;
	signal rx_dout         		: std_logic_vector(7 downto 0);
	signal rx_dout_vld 			: std_logic;
	signal rx_frame_error 		: std_logic;
	signal tx_addr_out 			: std_logic_vector(7 downto 0);
	signal tx_data_out 			: std_logic_vector(7 downto 0);
	signal tx_data_out_vld		: std_logic;
	signal tx_data_out_next 	: std_logic;
	signal tx_data_in        	: std_logic_vector(7 downto 0);
	signal tx_data_in_vld    	: std_logic;
	signal tx_data_in_next   	: std_logic;

begin
    -- ------------------------------------------------------------------------
    -- DUT 
    -- ------------------------------------------------------------------------
	uut: entity work.uart_stream_sync 
	port map (
		-- --------------------------------
		-- Clocks & Reset
		-- --------------------------------
		RX_CLK      => CLK_RX,
		RX_RESET    => RESET_RX,
	
		TX_CLK      => CLK_TX,
		TX_RESET    => RESET_TX,
	
		-- --------------------------------
		-- UART RX & TX folks
		-- --------------------------------
		-- USER DATA INPUT INTERFACE
		RX_DIN         => rx_din,
		RX_DIN_VLD     => rx_din_vld,
		RX_DIN_RDY	   => rx_din_rdy,
		-- USER DATA OUTPUT INTERFACE
		RX_DOUT        => rx_dout,
		RX_DOUT_VLD    => rx_dout_vld,
		RX_FRAME_ERROR => rx_frame_error,
	
		-- --------------------------------
		-- UART 
		-- --------------------------------
		-- UART --> APP
		TX_ADDR_OUT       => tx_addr_out,
		TX_DATA_OUT       => tx_data_out,
		TX_DATA_OUT_VLD   => tx_data_out_vld,
		TX_DATA_OUT_NEXT  => tx_data_out_next,
		
		-- APP --> UART
		TX_DATA_IN        => tx_data_in,
		TX_DATA_IN_VLD    => tx_data_in_vld,
		TX_DATA_IN_NEXT   => tx_data_in_next
	);

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
