-- -------------------------------------------------------------------------------
--  PROJECT: FPGA Brainfuck
-- -------------------------------------------------------------------------------
--  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
--  LICENSE: The MIT License (MIT), please read LICENSE file
--  WEBSITE: https://github.com/benycze/fpga-brainfuck/
-- -------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.uart_sync_pkg.all;

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
    -- USER DATA INPUT INTERFACE
    RX_DIN         : in  std_logic_vector(7 downto 0); -- input data to be transmitted over UART
    RX_DIN_VLD     : in  std_logic; -- when DIN_VLD = 1, input data (DIN) are valid
    RX_DIN_RDY     : out std_logic; -- when DIN_RDY = 1, transmitter is ready and valid input data will be accepted for transmiting
    -- USER DATA OUTPUT INTERFACE
    RX_DOUT        : out std_logic_vector(7 downto 0); -- output data received via UART
    RX_DOUT_VLD    : out std_logic; -- when DOUT_VLD = 1, output data (DOUT) are valid (is assert only for one clock cycle)
    RX_FRAME_ERROR : out std_logic; -- when FRAME_ERROR = 1, stop bit was invalid (is assert only for one clock cycle)

    -- --------------------------------
    -- UART 
    -- --------------------------------
    -- UART --> APP
    TX_ADDR_OUT       : out std_logic_vector(7 downto 0); -- Output address
    TX_DATA_OUT       : out std_logic_vector(7 downto 0); -- Output data
    TX_DATA_WRITE     : out std_logic;                    -- Write command
    TX_DATA_OUT_VLD   : out std_logic;                    -- Output data are valid
    TX_DATA_OUT_NEXT  : in std_logic;                     -- We are able to accept new data
    
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
  constant FIFO_RX_REQ_SIZE   : natural := 8;

  -- Registers  -----------------------
    -- Everything in the TX stage, register for storage of data and addresses
  signal reg_data       : std_logic_vector(7 downto 0);
  signal reg_data_en    : std_logic;
  signal reg_addr       : std_logic_vector(7 downto 0);
  signal reg_addr_en    : std_logic;
  signal write_en       : std_logic;

  -- Signals ---------------------------
    -- Signals for transition from RX --> FSM
  signal data_din_in      : std_logic_vector(8 downto 0);
  signal data_din_out     : std_ulogic_vector(8 downto 0);
  signal data_din_sent    : std_logic;
  signal data_din_sending : std_logic;
  signal data_din_out_vld : std_logic;

  signal data_din_fifo_in           : std_ulogic_vector(8 downto 0);
  signal data_din_fifo_in_vld       : std_ulogic;
  signal data_din_fifo_out          : std_ulogic_vector(8 downto 0);
  signal data_din_fifo_rd           : std_ulogic;
  signal reg_data_din_fifo_empty    : std_logic;
  signal data_din_fifo_empty        : std_logic;

    -- Signals for transtion from FSM --> TX
  signal data_dout_in           : std_logic_vector(8 downto 0);
  signal data_dout_out          : std_ulogic_vector(8 downto 0);
  signal data_dout_new_data     : std_logic;

  -- Synchronized data in the DIN TX Clock domain
    -- Input signals from the UART
  signal data_din_rx      : std_logic_vector(7 downto 0);
  signal data_din_rx_vld  : std_logic;

    -- Output signals to UART
  signal data_dout_rx           : std_logic_vector(7 downto 0);
  signal data_dout_rx_vld       : std_logic; -- Output data valid
  signal data_dout_rx_send      : std_logic; -- Output data send
  signal data_dout_rx_sending   : std_logic; -- Output data are being sending 
  signal data_dout_rx_frame_err : std_logic; -- Frame error indication 

  -- VLD/NEXT signals controlled by the FSM
  signal tx_data_in_next_out    : std_logic;
  signal tx_data_out_vld_out    : std_logic;
   
  -- FSM ------------------------------
  type FSM_State_t is 
    (INIT, READ_ADDR, READ_WAIT, READ_NOT_TAKEN, WRITE_ADDR, WRITE_DATA, WRITE_WAIT, WRITE_ACK, WAIT_TRANS);

  signal reg_state    : FSM_State_t; 
  signal next_state   : FSM_State_t;

begin
  -- --------------------------------------------------------------------------
  -- Transfer serial signals from the UART clock domain to FSM clock doimain
  -- --------------------------------------------------------------------------
  -- Preparation of input data
  data_din_in <= RX_DIN_VLD & RX_DIN;

    -- RX ---> FSM
  rx_din_sync_i : entity work.handshake_synchronizer
    generic map (
      STAGES                => SYNC_STAGES,
      RESET_ACTIVE_LEVEL    => '1'
    )
    port map(
      --# {{clocks|}}
      Clock_tx  => RX_CLK,
      Reset_tx  => RX_RESET,

      Clock_rx  => TX_CLK,
      Reset_rx  => TX_RESET,

      --# {{data|Send port}}
      Tx_data     => std_ulogic_vector(data_din_in),
      Send_data   => RX_DIN_VLD,
      Sending     => data_din_sending,
      Data_sent   => data_din_sent,

      --# {{Receive port}}
      Rx_data   => data_din_fifo_in,
      New_data  => data_din_fifo_in_vld
    );

  -- Synchronization between data and handshake unit
  rx_handshake_rdy_i: entity work.handshake_rdy
    port map(
      -- --------------------------------
      -- Clocks & Reset
      -- --------------------------------
      CLK      => RX_CLK,
      RESET    => RX_RESET,
  
      -- --------------------------------
      -- Input & output
      -- --------------------------------
      DATA_SENT       => data_din_sent,
      DATA_SENDING    => data_din_sending,
      VLD             => RX_DIN_VLD,
  
      DATA_RDY        => RX_DIN_RDY
    ) ;

    rx_req_fifo_i : entity work.simple_fifo
    generic map(
      RESET_ACTIVE_LEVEL  => '1',
      MEM_SIZE            => FIFO_RX_REQ_SIZE,
      SYNC_READ           => true
      )
    port map(
      Clock     => TX_CLK,
      Reset     => TX_RESET,

      We        => data_din_fifo_in_vld,
      Wr_data   => data_din_fifo_in,
  
      Re        => data_din_fifo_rd,
      Rd_data   => data_din_out,
  
      Empty     => data_din_fifo_empty,
      Full      => open,
  
      Almost_empty_thresh   => 1,
      Almost_full_thresh    => 1,
      Almost_empty          => open,
      Almost_full           => open
      );

  -- Unpack data - data are ready if we have someting in FIFO, but data 
  -- are available one clock later.
  data_din_rx     <= std_logic_vector(data_din_out(7 downto 0));
  data_din_rx_vld <= std_logic(data_din_out(8)) and not(reg_data_din_fifo_empty);

  fifo_dout_vld_genp : process( TX_CLK )
  begin
    if(rising_edge(TX_CLK))then
      if(TX_RESET = '1')then
        reg_data_din_fifo_empty <= '1';
      else
        reg_data_din_fifo_empty <= data_din_fifo_empty;
      end if;
    end if;
  end process ; -- identifier


  --> FSM --> TX
  rx_dout_sync_i : entity work.handshake_synchronizer
    generic map(
      STAGES              => SYNC_STAGES,
      RESET_ACTIVE_LEVEL  => '1'
    )
    port map(
      --# {{clocks|}}
      Clock_tx    => TX_CLK,
      Reset_tx    => TX_RESET,

      Clock_rx    => RX_CLK,
      Reset_rx    => RX_RESET,

      --# {{data|Send port}}
      Tx_data     => std_ulogic_vector(data_dout_in),
      Send_data   => data_dout_rx_vld,
      Sending     => data_dout_rx_sending,
      Data_sent   => data_dout_rx_send,

      --# {{Receive port}}
      Rx_data     => data_dout_out,
      New_data    => data_dout_new_data
    );
    -- Input data mapping
    data_dout_in    <= data_dout_rx_frame_err & data_dout_rx;
    -- Mapping of transferred signals to outputs
    RX_DOUT         <= std_logic_vector(data_dout_out(7 downto 0));
    RX_DOUT_VLD     <= std_logic(data_dout_new_data);
    RX_FRAME_ERROR  <= std_logic(data_dout_out(8));

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
            if(data_din_rx_vld = '1')then
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
                if(data_dout_rx_sending = '1')then
                  next_state <= WAIT_TRANS;
                end if;
             end if;

      when WRITE_ADDR => 
            -- We are waiting to 8 bit address which will come here
            if(data_din_rx_vld = '1')then
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
              if(data_dout_rx_sending = '1')then
                next_state <= WAIT_TRANS;
              end if;
    
      when WAIT_TRANS => 
              -- We are waiting untill data are transferred to RX clock domain, but we don't need
              -- to have the valid outputs high because the data is already in transfer
              if(data_dout_rx_send = '1')then
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
    data_dout_rx_frame_err  <= '0';
    data_dout_rx            <= (others => '0');
    data_dout_rx_vld        <= '0';
    reg_data_en             <= '0';
    reg_addr_en             <= '0';
    write_en                <= '0';
    data_din_fifo_rd        <= '1';

    case( reg_state ) is
           
      when READ_ADDR => 
            -- We are waiting to 8 bit address which will come here ... therefore, we need
            -- to enable address register to receive the data
            if(data_din_rx_vld = '1')then
              reg_addr_en <= '1';
            end if;

      when READ_NOT_TAKEN => 
      -- Read reaquest is ready to be processed here.
      -- We are still waiting on the following unit if it takes the command. In such situation,
      -- we are rady to accept data, send data and we have to copy the output.
        data_dout_rx          <= TX_DATA_IN;
        data_dout_rx_vld      <= TX_DATA_IN_VLD;
        tx_data_out_vld_out   <= '1'; -- We are asserting the output
        tx_data_in_next_out   <= '0'; -- We are redy to receive
        data_din_fifo_rd      <= '0';

      when READ_WAIT => 
            -- We are waiting on data which comes through the APP --> UART interface
            -- During the wait, we will assert that we are ready to accept data and we will 
            -- set the VLD signal to UART
            if(data_dout_rx_sending = '1')then
              tx_data_in_next_out   <= '1'; -- We are ready to receive
            end if;

            -- Copy signals from the component
            data_dout_rx          <= TX_DATA_IN;
            data_dout_rx_vld      <= TX_DATA_IN_VLD;
            
            -- We are not reading any data in this state
            data_din_fifo_rd      <= '0';

      when WRITE_ADDR => 
            -- We are waiting to 8 bit address which will come here ... therefore, we need
            -- to enable the address register to receive the data
            write_en <= '1';
            if(data_din_rx_vld = '1')then
              reg_addr_en <= '1';
            end if;

      when WRITE_DATA => 
            -- We are waiting for data to write, in this state we are just enabling the 
            -- address register
            write_en <= '1';
            if(data_din_rx_vld = '1')then
              reg_data_en <= '1';
            end if;

      when WRITE_WAIT =>
            -- We are waiting here untill the data are taken by the component, after that
            -- we need to send the ACK command to the software
            write_en              <= '1';
            tx_data_out_vld_out   <= '1';
            data_din_fifo_rd      <= '0';

      when WRITE_ACK => 
            -- Now we need to send the write ACK command, the valid is active until the 
            -- sending signal is asserted. After that, we need to remove the valid signal
            data_dout_rx          <= CMD_ACK;
            data_dout_rx_vld      <= '1';
            data_din_fifo_rd      <= '0'; 

      when WAIT_TRANS => 
            -- FIFO is not read during the waiting for the transfer from one to another clock domain
            if(data_dout_rx_send = '0')then
              data_din_fifo_rd <= '0';
            end if;

      when others => null;
    end case ;
  end process;

  -- --------------------------------------------------------------------------
  -- Output registers 
  -- --------------------------------------------------------------------------
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
        reg_addr <= data_din_rx;
      end if;
    end if;
  end process ; -- addr_regp

  -- Map registers to outputs
  TX_ADDR_OUT       <= reg_addr;
  TX_DATA_OUT       <= reg_data;
  TX_DATA_WRITE     <= write_en;

end architecture;