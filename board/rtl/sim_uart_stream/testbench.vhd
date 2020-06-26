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
use ieee.math_real.all;

use work.uart_sync_pkg.all;

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
	constant RESET_RX_PERIOD    	: integer := 3;
	constant RESET_RX_WAIT_AFTER	: integer := 20;

	constant RESET_TX_PERIOD    	: integer := 3;
	constant RESET_TX_WAIT_AFTER	: integer := 20;

	-- Configuration of random destination ready signal (maximal number of cycles)
	constant TX_NEXT_RDY_IDLE_MIN	: integer := 2;
	constant TX_NEXT_RDY_IDLE_MAX	: integer := 10;
	
	constant TX_NEXT_RDY_ON_MIN		: integer := 2;
	constant TX_NEXT_RDY_ON_MAX		: integer := 5;

	-- Signals --------------------------------------------
	signal rx_din 				: std_logic_vector(7 downto 0);
	signal rx_din_vld			: std_logic;
	signal rx_din_rdy           : std_logic;
	signal rx_dout         		: std_logic_vector(7 downto 0);
	signal rx_dout_vld 			: std_logic;
	signal rx_frame_error 		: std_logic;
	signal tx_addr_out 			: std_logic_vector(7 downto 0);
	signal tx_data_out 			: std_logic_vector(7 downto 0);
	signal tx_data_write		: std_logic;
	signal tx_data_out_vld		: std_logic;
	signal tx_data_out_next 	: std_logic;
	signal tx_data_in        	: std_logic_vector(7 downto 0);
	signal tx_data_in_vld    	: std_logic;
	signal tx_data_in_next   	: std_logic;

	-- Testing data ---------------------------------------
	type data_rec_t is record
		data	: std_logic_vector(7 downto 0);
		addr	: std_logic_vector(7 downto 0);
	end record;
	type test_data_t is array (integer range <>) of data_rec_t;

	-- Testing data for write command
	constant test_data_wr : test_data_t(0 to 1) := (
		( data => x"fa", addr => x"01"),
		( data => x"aa", addr => x"21")
	);

	-- Testing data for read command
	constant test_data_rd : test_data_t(0 to 1) := (
		( data => x"ab", addr => x"ac"),
		( data => x"22", addr => x"02")
	);

	-- Functions ----------------------

	shared variable seed1	: positive;
	shared variable seed2	: positive;

	-- Genrate a random integer to max value
	impure function get_random(min_v : in integer ; max_v : in integer) return integer is 
		variable rand : real;
	begin
		uniform(seed1, seed2, rand);
		return ( min_v + (integer(rand) mod max_v));
	end function;

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
		TX_DATA_WRITE	  => tx_data_write,
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

	tb_rx : process
		variable data_out 	: std_logic_vector(7 downto 0);
		variable data_ref	: std_logic_vector(7 downto 0);
		variable wr_rec 	: data_rec_t;

		-- This procedure takes the test data and sends the read record to the uart_stream_sync component.
		-- After that, it waits for the data which will be read from the bus.
		procedure write_data (data_in : in data_rec_t; data_out : out std_logic_vector) is
		begin
			-- Take data to write and setup the valid signal. After that, wait until data
			-- are taken and wait for data which incomes
			rx_din 		<= CMD_WRITE;
			rx_din_vld	<= '1';
			wait until (rising_edge(CLK_RX) and rx_din_vld = '1' and rx_din_rdy = '1');
	
			rx_din		<= data_in.addr;
			wait until (rising_edge(CLK_RX) and rx_din_vld = '1' and rx_din_rdy = '1');
	
			rx_din		<= data_in.data;
			wait until (rising_edge(CLK_RX) and rx_din_vld = '1' and rx_din_rdy = '1'); 	    
			rx_din_vld <= '0';
	
			-- Read the returned data 
			wait until (rising_edge(CLK_RX) and rx_dout_vld = '1'); 
			data_out := rx_dout;
		end procedure;
		
		-- This procedure reads the data from the passed address and output is returned in the
		-- data variable.
		procedure read_data ( addr : in std_logic_vector; data_out : out std_logic_vector) is
		begin
			-- Take the address and pass it on the bus with the read command
			rx_din 		<= CMD_READ;
			rx_din_vld	<= '1';
			wait until (rising_edge(CLK_RX) and rx_din_vld = '1' and rx_din_rdy = '1');
	
			rx_din		<= addr;
			wait until (rising_edge(CLK_RX) and rx_din_vld = '1' and rx_din_rdy = '1');
	
			-- Read the returned data 
			wait until (rising_edge(CLK_RX) and rx_dout_vld = '1'); 
			data_out := rx_dout;
		end procedure;

	begin
		-- Initial values 
		rx_din 				<= (others => '0');
		rx_din_vld 			<= '0';

		-- Wait untill the process is being reseted
		wait until rising_edge(CLK_RX);
		wait for RESET_RX_WAIT_AFTER * clk_rx_period;

		-- Time to drive ....

		-- 1) Read test
		for i in 0 to test_data_rd'length-1 loop
			-- Read and check the result
			data_ref := test_data_rd(i).data;
			read_data(test_data_rd(i).addr, data_out);

			assert test_data_rd(i).data = data_out report 
				"tb_rx read ( i = " & integer'image(i) & "): Received (" & to_string(data_out) & ") data are not as expected data (" & to_string(data_ref) & ")." 
				severity error;
		end loop;

		-- 2) Write test
		for i in 0 to test_data_wr'length-1 loop
			-- Write data test (we are just waiting to get the command)
			wr_rec := test_data_wr(i);
			write_data(wr_rec, data_out);

			assert data_out = CMD_ACK report 
				"tb_rx write (i = " & integer'image(i) & "): ACK wasn't received!"
				severity error;
		end loop;

		-- End the testbench
		wait;
	end process;

	tb_tx : process
		variable rd_req : data_rec_t;
		variable wr_req : data_rec_t;
	begin
		-- Initial values 
		tx_data_in			<= (others => '0');
		tx_data_in_vld		<= '0';

		-- Wait untill the process is being reseted
		wait until rising_edge(CLK_TX);
		wait for RESET_TX_WAIT_AFTER * clk_tx_period;

		-- Time to drive ....

		-- 1) Read test
		-- On TX side, we need to wait untill data are ready
		for i in 0 to test_data_rd'length-1 loop
			rd_req :=  test_data_rd(i);
			-- Wait until we have a valid data read request
			wait until (rising_edge(CLK_TX) and tx_data_out_vld = '1' and tx_data_out_next = '1');
			-- Check if the address matches, setup the 
			assert tx_addr_out = rd_req.addr report 
				"tb_tx read (i = " & integer'image(i) & "): Expected address (" & to_string(rd_req.addr) &  ") doesn't match with received address (" & to_string(tx_addr_out) & ")."
				severity error;
			
			assert tx_data_write = '0' report
				"tb_tx read (i = " & integer'image(i) & "): Write command is enabled in the read mode."
				severity error;

			-- Wait untill the rising edge is detected and valid/ready signals are ready
			tx_data_in 		<=  rd_req.data;
			tx_data_in_vld 	<= '1';
			wait until (rising_edge(CLK_TX) and tx_data_in_vld = '1' and tx_data_in_next = '1');
			tx_data_in_vld  <= '0';
		end loop;

		-- 2) Write test
		for i in 0 to test_data_wr'length-1 loop
			-- We just need to check the write command is asserted 
			wr_req := test_data_wr(i);
			wait until (rising_edge(CLK_TX) and tx_data_out_vld = '1' and tx_data_out_next = '1');
			-- Check if the address matches, setup the 
			assert tx_addr_out = wr_req.addr report 
				"tb_tx write (i = " & integer'image(i) & "): Expected address (" & to_string(wr_req.addr) &  ") doesn't match with received address (" & to_string(tx_addr_out) & ")."
				severity error;

			assert tx_data_write = '0' report
				"tb_tx write (i = " & integer'image(i) & "): Read command is enabled in the write mode."
				severity error;

			assert tx_data_out = wr_req.data report
				"tb_tx write (i = " & integer'image(i) & "): Expected data (" & to_string(wr_req.data) &  ") doesn't match with received data (" & to_string(tx_data_out) & ")."
				severity error;

		end loop;

		-- End the testbench
		wait;
	end process;


	-- Random destination ready signaling
	random_tx_rdy : process
		variable rand_wait : integer;
	begin
		-- Wait until the reset is disabled && then wait for a given time in inactive value
		tx_data_out_next 	<= '0';
		wait until (rising_edge(CLK_TX) and RESET_TX = '0'); 
		wait for get_random(TX_NEXT_RDY_IDLE_MIN, TX_NEXT_RDY_IDLE_MAX) * clk_tx_period;
		
		tx_data_out_next 	<= '1';
		wait for get_random(TX_NEXT_RDY_ON_MIN, TX_NEXT_RDY_ON_MAX) * clk_tx_period;
	end process;

end architecture;
