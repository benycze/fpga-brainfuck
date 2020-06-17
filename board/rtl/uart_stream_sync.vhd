
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
    -- UART RX
    -- --------------------------------
    RX_UART_TXD    : out std_logic; -- serial transmit data
    RX_UART_RXD    : in  std_logic; -- serial receive data
    -- USER DATA INPUT INTERFACE
    RX_DIN         : in  std_logic_vector(7 downto 0); -- input data to be transmitted over UART
    RX_DIN_VLD     : in  std_logic; -- when DIN_VLD = 1, input data (DIN) are valid
    RX_DIN_RDY     : out std_logic; -- when DIN_RDY = 1, transmitter is ready and valid input data will be accepted for transmiting
    -- USER DATA OUTPUT INTERFACE
    RX_DOUT        : out std_logic_vector(7 downto 0); -- output data received via UART
    RX_DOUT_VLD    : out std_logic; -- when DOUT_VLD = 1, output data (DOUT) are valid (is assert only for one clock cycle)
    RX_FRAME_ERROR : out std_logic  -- when FRAME_ERROR = 1, stop bit was invalid (is assert only for one clock cycle)

    -- --------------------------------
    -- UART 
    -- --------------------------------
    TX_DATA_OUT       : out std_logic_vector(7 downto 0);
    TX_DATA_OUT_VLD   : out std_logic;
    TX_DATA_OUT_NEXT  : in std_logic;

    TX_DATA_IN        : in std_logic_vector(7 downto 0);
    TX_DATA_IN_VLD    : in std_logic;
    TX_DATA_IN_NEXT   : out std_logic
  );
end uart_stream_sync;

architecture full of uart_stream_sync is

begin

end architecture;