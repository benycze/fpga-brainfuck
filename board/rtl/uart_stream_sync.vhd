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
use work.uart_sync_pkg.all;

-- TODO:
-- * Implement the error handling when the RX_DIM_FRAME_ERROR is asserted

entity uart_stream_sync is
  port (
    -- --------------------------------
    -- Clocks & Reset
    -- --------------------------------
    RX_CLK      : in std_logic;
    RX_RESET    : in std_logic;

    TX_CLK      : in std_logic;
    TX_RESET    : in std_logic;

    -- --------------------------------
    -- UART RX & TX folks
    -- --------------------------------
    -- USER DATA OUTPUT INTERFACE
    RX_DOUT        : out  std_logic_vector(7 downto 0); -- input data to be transmitted over UART
    RX_DOUT_VLD    : out std_logic; -- when DIN_VLD = 1, input data (DIN) are valid
    RX_DOUT_RDY    : in std_logic; -- when DIN_RDY = 1, transmitter is ready and valid input data will be accepted for transmiting

    -- USER DATA INPUT INTERFACE
    RX_DIN              : in std_logic_vector(7 downto 0); -- output data received via UART
    RX_DIN_VLD          : in std_logic; -- when DOUT_VLD = 1, output data (DOUT) are valid (is assert only for one clock cycle)
    RX_DIN_FRAME_ERROR  : in std_logic; -- when FRAME_ERROR = 1, stop bit was invalid (is assert only for one clock cycle)

    -- --------------------------------
    -- UART 
    -- --------------------------------
    -- UART --> APP
    TX_ADDR_OUT       : out std_logic_vector(23 downto 0);  -- Output address
    TX_DATA_OUT       : out std_logic_vector(7 downto 0);   -- Output data
    TX_DATA_WRITE     : out std_logic;                      -- Write command
    TX_DATA_OUT_VLD   : out std_logic;                      -- Output data are valid
    TX_DATA_OUT_NEXT  : in std_logic;                       -- We are able to accept new data
    
    -- APP --> UART
    TX_DATA_IN        : in std_logic_vector(7 downto 0);  -- Input data to the application
    TX_DATA_IN_VLD    : in std_logic;                     -- Input data valid
    TX_DATA_IN_NEXT   : out std_logic                     -- Ready to accept new input data
  );
end uart_stream_sync;

architecture full of uart_stream_sync is

  -- Constants ------------------------
    -- Number of synchronization stages
  constant SYNC_STAGES        : natural := 4;
    -- Number of elements inside the FIFO
  constant FIFO_ADDDR_WIDTH   : natural := 5;
    -- Last iteration of address write
  constant CNT_ADDR_MAX       : integer := 2;

  -- Registers  -----------------------
    -- Everything in the TX stage, register for storage of data and addresses
  signal reg_data       : std_logic_vector(7 downto 0);
  signal reg_data_en    : std_logic;
  signal reg_addr       : std_logic_vector(23 downto 0);
  signal reg_addr_en    : std_logic;
  signal write_en       : std_logic;

  signal cnt_addr       : unsigned(1 downto 0);
  signal cnt_addr_en    : std_logic;
  signal cnt_addr_rst   : std_logic;

  -- Signals ---------------------------
  signal data_din_rx          : std_logic_vector(7 downto 0);
  signal data_din_rx_vld      : std_logic;
  signal data_din_rx_rd       : std_logic;

  signal data_dout_rx           : std_logic_vector(7 downto 0);
  signal data_dout_rx_vld       : std_logic; -- Output data valid
  signal data_dout_rx_full      : std_logic; -- Output FIFO is full

  -- VLD/NEXT signals controlled by the FSM
  signal tx_data_in_next_out    : std_logic;
  signal tx_data_out_vld_out    : std_logic;
   
  -- FSM ------------------------------
  type FSM_State_t is 
    (INIT, READ_ADDR, READ_WAIT, READ_NOT_TAKEN, WRITE_ADDR, WRITE_DATA, WRITE_WAIT, WRITE_ACK);

  signal reg_state    : FSM_State_t; 
  signal next_state   : FSM_State_t;

begin
  
  -- --------------------------------------------------------------------------
  -- Transfer serial signals from the UART clock domain to FSM clock doimain
  -- --------------------------------------------------------------------------

  -- RX ---> TX (FSM)
  rx_asfifo_i : entity work.ASFIFO
    generic map (
        DATA_WIDTH    => 8,
        ADDR_WIDTH    => FIFO_ADDDR_WIDTH
    )
    port map(
        -- FIFO WRITE INTERFACE
        WR_CLK      => RX_CLK,
        WR_RST      => RX_RESET,
        WR_DATA     => RX_DIN,
        WR_REQ      => RX_DIN_VLD,
        WR_FULL     => open,
        -- FIFO READ INTERFACE
        RD_CLK      => TX_CLK,
        RD_RST      => TX_RESET,
        RD_DATA     => data_din_rx,
        RD_DATA_VLD => data_din_rx_vld,
        RD_REQ      => data_din_rx_rd
    );

  -- TX (FSM) ---> RX
  tx_asfifo_i : entity work.ASFIFO
    generic map(
        DATA_WIDTH  => 8,
        ADDR_WIDTH  => FIFO_ADDDR_WIDTH
    )
    port map(
        -- FIFO WRITE INTERFACE
        WR_CLK      => TX_CLK,
        WR_RST      => TX_RESET,
        WR_DATA     => data_dout_rx,
        WR_REQ      => data_dout_rx_vld,
        WR_FULL     => data_dout_rx_full,
        -- FIFO READ INTERFACE
        RD_CLK      => RX_CLK,
        RD_RST      => RX_RESET,
        RD_DATA     => RX_DOUT,
        RD_DATA_VLD => RX_DOUT_VLD,
        RD_REQ      => RX_DOUT_RDY
    );

  -- --------------------------------------------------------------------------
  -- Control FSM (TX_CLK)
  -- --------------------------------------------------------------------------
  -- Map valid signals (just for the case that someone will use the older version of VHDL)
  TX_DATA_IN_NEXT <= tx_data_in_next_out;
  TX_DATA_OUT_VLD <= tx_data_out_vld_out;

  -- The FPGA stream convers the input searial stream to the general - ADDRESS and DATA interface without
  -- the possibility to stop the output stream of data. 

  -- Reading:
  -- ========
  -- During the read operation, we send the command 0x0 in the firs byte. Then we send 8-bit address and 
  -- after that we will get the 8-bit data on the data input in the application.

  -- Writing:
  -- ========
  -- During the write operation, we send the command 0x1 in the first byte, address and data to write. 
  -- After the written data are accepted, we will send the ACK (0x2) after the command was successfully submited
  -- to the system.

  -- Register for storage of the current state
  fsm_state_regp:process(TX_CLK)
  begin
    if(rising_edge(TX_CLK))then
      if(TX_RESET = '1')then
        reg_state <= INIT;
      else
        reg_state <= next_state;
      end if;
    end if;
  end process;

  -- Selection of the next state based on the description
  -- provided up
  next_statep:process(all)
  begin
    -- Default values
    next_state <= reg_state;

    case( reg_state ) is
    
      when INIT =>
        -- First, we need to wait for incomming data and check the result
        if(data_din_rx_vld = '1')then
          if(data_din_rx = CMD_READ)then
            -- Read command detected
            next_state <= READ_ADDR;
          elsif(data_din_rx = CMD_WRITE)then
            -- Write command detected
            next_state <= WRITE_ADDR;
          else
            -- Unknown command, stay in the INIT stage
            next_state <= INIT;
          end if;
        end if;
        
      when READ_ADDR => 
            -- We are waiting to 8 bit address which will come here
            if(data_din_rx_vld = '1' and cnt_addr = CNT_ADDR_MAX)then
              next_state <= READ_NOT_TAKEN;
            end if;

      when READ_NOT_TAKEN => 
            -- Read command was asserted but data are not taken yet
            if(TX_DATA_OUT_NEXT = '1' and tx_data_out_vld_out = '1')then
                next_state <= READ_WAIT;
            end if;

      when READ_WAIT => 
             -- We are waiting on data which comes through the APP --> UART interface
             if(TX_DATA_IN_VLD = '1' and tx_data_in_next_out = '1')then 
                if( data_dout_rx_full = '0')then
                  next_state <= INIT;
                end if;
             end if;

      when WRITE_ADDR => 
            -- We are waiting to 8 bit address which will come here. We will go to the next
            -- state when we write the last address.
            if(data_din_rx_vld = '1' and cnt_addr = CNT_ADDR_MAX)then
              next_state <= WRITE_DATA;
            end if;

      when WRITE_DATA => 
            -- We are waiting for data to write
            if(data_din_rx_vld = '1')then
              next_state <= WRITE_WAIT;
            end if;

      when WRITE_WAIT =>
            -- We are waiting here untill the data are taken by the component, after that
            -- we need to send the ACK command to the software
            if(TX_DATA_OUT_NEXT = '1' and tx_data_out_vld_out = '1')then
                next_state <= WRITE_ACK;
            end if;

      when WRITE_ACK => 
            -- We need to send the ACK to the software
            if(data_dout_rx_full = '0')then
              next_state <= INIT;
            end if;

      when others => null;
    end case ;

  end process;

  out_genp:process(all)
  begin 
    -- Default values of all signals
    tx_data_in_next_out     <= '0';
    tx_data_out_vld_out     <= '0';
    data_dout_rx            <= (others => '0');
    data_dout_rx_vld        <= '0';
    reg_data_en             <= '0';
    reg_addr_en             <= '0';
    write_en                <= '0';
    cnt_addr_rst            <= '0';
    cnt_addr_en             <= '0';
    data_din_rx_rd          <= '0';

    case( reg_state ) is

      when INIT => 
          -- We can prepare the address counter for address storage
          cnt_addr_rst      <= '1';
          data_din_rx_rd    <= '1';
        
      when READ_ADDR => 
          -- We are waiting to 8 bit address which will come here ... therefore, we need
          -- to enable address register to receive the data. We need to enable the counter to move to the 
          -- next index.
          if(data_din_rx_vld = '1')then
            reg_addr_en       <= '1';
            cnt_addr_en       <= '1';
            data_din_rx_rd    <= '1';
          end if;

      when READ_NOT_TAKEN => 
          -- Read reaquest is ready to be processed here.
          -- We are still waiting on the following unit if it takes the command. In such situation,
          -- we are rady to accept data, send data and we have to copy the output.
          data_dout_rx          <= TX_DATA_IN;
          data_dout_rx_vld      <= TX_DATA_IN_VLD;
          tx_data_out_vld_out   <= '1'; -- We are asserting the output (it is valid)
          tx_data_in_next_out   <= '0'; -- We are redy to receive any data

      when READ_WAIT => 
          -- We are waiting on data which comes through the APP --> UART interface
          -- During the wait, we will assert that we are ready to accept data and we will 
          -- set the VLD signal to UART. We are ready to accept any data iff the output FIFO is 
          -- not full.
          if(data_dout_rx_full = '0')then
            tx_data_in_next_out   <= '1'; -- We are ready to receive
          end if;

          -- Copy signals from the component
          data_dout_rx          <= TX_DATA_IN;
          data_dout_rx_vld      <= TX_DATA_IN_VLD;

      when WRITE_ADDR => 
          -- We are waiting to 8 bit address which will come here ... therefore, we need
          -- to enable the address register to receive the data. We need to enable the counter to move to the 
          -- next index.
          write_en <= '1';
          if(data_din_rx_vld = '1')then
            reg_addr_en     <= '1';
            cnt_addr_en     <= '1';
            data_din_rx_rd  <= '1';
          end if;

      when WRITE_DATA => 
            -- We are waiting for data to write, in this state we are just enabling the 
            -- address register
            write_en <= '1';
            if(data_din_rx_vld = '1')then
              reg_data_en     <= '1';
              data_din_rx_rd  <= '1';
            end if;

      when WRITE_WAIT =>
            -- We are waiting here untill the data are taken by the component, after that
            -- we need to send the ACK command to the software
            write_en              <= '1';
            tx_data_out_vld_out   <= '1';

      when WRITE_ACK => 
            -- Now we need to send the write ACK command, the valid is active until the 
            -- sending signal is asserted. After that, we need to remove the valid signal
            data_dout_rx          <= CMD_ACK;

            if(data_dout_rx_full = '0')then
              data_dout_rx_vld      <= '1';
            end if;

      when others => null;
    end case ;
  end process;

  -- --------------------------------------------------------------------------
  -- Output registers & counters
  -- --------------------------------------------------------------------------

  addr_cntp : process( TX_CLK )
  begin
    if rising_edge(TX_CLK) then
      if(TX_RESET = '1' or cnt_addr_rst = '1')then
        cnt_addr <= (others => '0');
      else
        if (cnt_addr_en = '1') then
          cnt_addr <= cnt_addr + 1;
        end if ;
      end if;
    end if ;
  end process ; -- addr_cntp

  data_regp:process(TX_CLK)
  begin
    if(rising_edge(TX_CLK))then
      if(reg_data_en = '1')then
        reg_data <= data_din_rx;
      end if;
    end if;
  end process; -- data_regp

  addr_regp : process( TX_CLK )
  begin
    if(rising_edge(TX_CLK))then
      if(reg_addr_en = '1')then
        case( cnt_addr ) is
          when "00" => reg_addr(7 downto 0)   <= data_din_rx;
          when "01" => reg_addr(15 downto 8)  <= data_din_rx;
          when "10" => reg_addr(23 downto 16) <= data_din_rx;
          when others => null;
        end case ;
      end if;
    end if;
  end process ; -- addr_regp

  -- Map registers to outputs
  TX_ADDR_OUT       <= reg_addr;
  TX_DATA_OUT       <= reg_data;
  TX_DATA_WRITE     <= write_en;

end architecture;