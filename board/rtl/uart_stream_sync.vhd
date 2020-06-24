-- -------------------------------------------------------------------------------
--  PROJECT: FPGA Brainfuck
-- -------------------------------------------------------------------------------
--  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
--  LICENSE: The MIT License (MIT), please read LICENSE file
--  WEBSITE: https://github.com/benycze/fpga-brainfuck/
-- -------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

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
    TX_DATA_OUT_VLD   : out std_logic;                    -- Output data are valid
    TX_DATA_OUT_NEXT  : in std_logic;                     -- We are able to accept new data
    
    -- APP --> UART
    TX_DATA_IN        : in std_logic_vector(7 downto 0);  -- Input data to the application
    TX_DATA_IN_VLD    : in std_logic;                     -- Input data valid
    TX_DATA_IN_NEXT   : out std_logic                     -- Ready to accept new input data
  );
end uart_stream_sync;

architecture full of uart_stream_sync is

  -- Component declaration ---------

  component handshake_synchronizer is
    generic (
      STAGES : natural := 2; --# Number of flip-flops in the synchronizer
      RESET_ACTIVE_LEVEL : std_ulogic := '1' --# Asynch. reset control level
    );
    port (
      --# {{clocks|}}
      Clock_tx : in std_ulogic; --# Transmitting domain clock
      Reset_tx : in std_ulogic; --# Asynchronous reset for Clock_tx

      Clock_rx : in std_ulogic; --# Receiving domain clock
      Reset_rx : in std_ulogic; --# Asynchronous reset for Clock_rx


      --# {{data|Send port}}
      Tx_data   : in std_ulogic_vector; --# Data to send
      Send_data : in std_ulogic;  --# Control signal to send new data
      Sending   : out std_ulogic; --# Active while TX is in process
      Data_sent : out std_ulogic; --# Flag to indicate TX completion

      --# {{Receive port}}
      Rx_data  : out std_ulogic_vector; --# Data received in clock_rx domain
      New_data : out std_ulogic   --# Flag to indicate new data
    );
  end component;

  -- Constant -------------------------
    -- Commands to perform
  constant CMD_WRITE  : std_logic_vector(7 downto 0) := x"00"; 
  constant CMD_READ   : std_logic_vector(7 downto 0) := x"01";
  constant CMD_ACK    : std_logic_vector(7 downto 0) := x"02";

    -- Number of synchronization stages
  constant SYNC_STAGES  : natural := 4;

  -- Registers  -----------------------
    -- Everything in the TX stage, register for storage of data and addresses
  signal reg_data       : std_logic_vector(7 downto 0);
  signal reg_data_en    : std_logic;
  signal reg_addr       : std_logic_vector(7 downto 0);
  signal reg_addr_en    : std_logic;

  -- Signals ---------------------------
    -- Signals for transition from RX --> FSM
  signal data_din_in      : std_logic_vector(8 downto 0);
  signal data_din_out     : std_ulogic_vector(8 downto 0);
  signal data_din_sending : std_logic;
  signal data_din_out_vld : std_logic;

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
  signal data_dout_rx_send      : std_logic; -- Output data send (one clk cycle is enough)
  signal data_dout_rx_frame_err : std_logic; -- Frame error indication (onec clock cycle is enough)

  -- VLD/NEXT signals controlled by the FSM
  signal tx_data_in_next_out    : std_logic;
  signal tx_data_out_vld_out    : std_logic;
   
  -- FSM ------------------------------
  type FSM_State_t is 
    (INIT, READ_ADDR, READ_WAIT, WRITE_ADDR, WRITE_DATA, WRITE_WAIT,WAIT_TRANS);

  signal reg_state    : FSM_State_t; 
  signal next_state   : FSM_State_t;

begin
  -- --------------------------------------------------------------------------
  -- Transfer serial signals from the UART clock domain to FSM clock doimain
  -- --------------------------------------------------------------------------
    -- RX ---> FSM
  rx_din_sync_i : handshake_synchronizer
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
      Data_sent   => open,

      --# {{Receive port}}
      Rx_data   => data_din_out,
      New_data  => data_din_out_vld
    );

  -- Pack data and RDY signal
  data_din_in <= RX_DIN_VLD & RX_DIN; 
  RX_DIN_RDY  <= not(data_din_sending);

  -- Unpack data
  data_din_rx     <= std_logic_vector(data_din_out(7 downto 0));
  data_din_rx_vld <= std_logic(data_din_out_vld);
  
  --> FSM --> TX
  rx_dout_sync_i : handshake_synchronizer
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
      Sending     => open,
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
          if(data_din_rx = CMD_WRITE)then
            -- Read command detected
            next_state <= READ_ADDR;
          elsif(data_din_rx = CMD_READ)then
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
              next_state <= READ_WAIT;
            end if;

      when READ_WAIT => 
             -- We are waiting on data which comes through the APP --> UART interface
             if(TX_DATA_IN_VLD = '1' and tx_data_in_next_out = '1')then 
                if(data_dout_rx_send = '1')then
                  next_state <= INIT;
                else
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
            if(tx_data_in_next_out = '1' and TX_DATA_IN_VLD = '1')then
              if(data_dout_rx_send = '1')then
                next_state <= INIT;
              else
                next_state <= WAIT_TRANS;
              end if;
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
    tx_data_in_next_out <= '0';
    tx_data_out_vld_out <= '0';
    data_dout_rx_frame_err <= '0';
    data_dout_rx <= (others => '0');
    data_dout_rx_vld <= '0';
    reg_data_en <= '0';
    reg_addr_en <= '0';
  
    case( reg_state ) is
           
      when READ_ADDR => 
            -- We are waiting to 8 bit address which will come here ... therefore, we need
            -- to enable address register to receive the data
            if(data_din_rx_vld = '1')then
              reg_addr_en <= '1';
            end if;

      when READ_WAIT => 
            -- We are waiting on data which comes through the APP --> UART interface
            -- During the wait, we will assert that we are ready to accept data and we will 
            -- set the VLD signal to UART
            tx_data_in_next_out   <= '1';
            data_dout_rx          <= TX_DATA_IN;
            data_dout_rx_vld      <= TX_DATA_IN_VLD;

      when WRITE_ADDR => 
            -- We are waiting to 8 bit address which will come here ... therefore, we need
            -- to enable the address register to receive the data
            if(data_din_rx_vld = '1')then
              reg_addr_en <= '1';
            end if;

      when WRITE_DATA => 
            -- We are waiting for data to write, in this state we are just enabling the 
            -- address register
            if(data_din_rx_vld = '1')then
              reg_data_en <= '1';
            end if;

      when WRITE_WAIT =>
            -- We are waiting here untill the data are taken by the component, after that
            -- we need to send the ACK command to the software
            tx_data_out_vld_out   <= '1';
            data_dout_rx          <= CMD_ACK;
            data_dout_rx_vld      <= TX_DATA_OUT_NEXT;

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

end architecture;