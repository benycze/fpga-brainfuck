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

entity fpga_top is
port (
    -- --------------------------------
    -- CLOCKS (reference)
    ----------------------------------- 
    CLK		        : in std_logic;
    RESET_BTN_N     : in std_logic; 

    -- --------------------------------
    -- LED outptus
    -----------------------------------
    LED_0           : out std_logic;
    LED_1           : out std_logic;
    LED_2           : out std_logic;
    LED_3           : out std_logic;
    LED_4           : out std_logic;
    LED_5           : out std_logic;
    LED_6           : out std_logic;
    LED_7           : out std_logic;

    -- --------------------------------
    -- UART interface
    -- --------------------------------
    UART_TXD  : out std_logic;
    UART_RXD  : in  std_logic

);
end entity;

architecture full of fpga_top is

    -- Constants ----------------------
    constant CLK_FREQ      : integer := 12e6;   -- set system clock frequency in Hz
    constant BAUD_RATE     : integer := 115200; -- baud rate value
    constant PARITY_BIT    : string  := "none"; -- legal values: "none", "even", "odd", "mark", "space"
    constant USE_DEBOUNCER : boolean := True;   -- enable/disable debouncer

    constant RESET_CNT_WIDTH    : integer := 7;
    constant RESET_SYNC_STAGES  : integer := 4;
    
    -- Signals ------------------------

    -- Clock & resets & debouncers
    signal clk_ref      : std_logic;
    signal clk_c0 		: std_logic;
    
    signal reset_cnt_c0	    : unsigned(RESET_CNT_WIDTH-1 downto 0);
    signal reset_cnt_ref	: unsigned(RESET_CNT_WIDTH-1 downto 0);
    signal locked		    : std_logic;

    signal reset_c0_sync        : std_logic;
    signal reset_ref_sync       : std_logic;
    signal reset_c0 	        : std_logic;
    signal reset_ref            : std_logic;

    signal btn_debounced_n      : std_logic;
    signal btn_debounced        : std_logic;

    signal uart_rx_din          : std_logic_vector(7 downto 0);
    signal uart_rx_din_vld      : std_logic;
    signal uart_rx_din_rdy      : std_logic;

    signal uart_rx_dout         : std_logic_vector(7 downto 0);
    signal uart_rx_dout_vld     : std_logic;
    signal uart_rx_frame_error  : std_logic;

    -- Demo signals
    signal led_vector           : std_logic_vector(7 downto 0);
    signal led_vector_vld       : std_logic;
    signal reg_led_vector       : std_logic_vector(7 downto 0);

begin

    -- ------------------------------------------------------------------------
    -- Clocks & Reset
    -- ------------------------------------------------------------------------

    -- Clocks are generated by the PLL from reference closk 12MHz. The reset is
    -- asserted automatically when the output clocks are locked. There is also a 
    -- possibility to assert the system reset by the reset buttton.
    --
    -- List of generated clocks & resets:
    -- * clk_c0 and reset_c0 -- main system clocks used in the design (after the PLL)
    -- * CLK (12MHz) and reset_12 -- reference clocks and reset 

    -- Generate input clocks
    pll_i : work.pll 
    port map(
        inclk0		=> CLK,
        c0			=> clk_c0,
        locked		=> locked
    );

    -- Reference clock signal
    clk_ref <= CLK;

    -- Reset synchronization
    reset_sync_ref_i : work.reset_synchronizer 
    generic map(
        STAGES                  => RESET_SYNC_STAGES,
        RESET_ACTIVE_LEVEL      => '0'
    )
    port map(
        --# {{clocks|}}
        Clock       => clk_ref,
        Reset       => RESET_BTN_N,

        --# {{data|}}
        Sync_reset => reset_ref_sync
    );

    reset_sync_c0_i : work.reset_synchronizer 
    generic map(
        STAGES                  => RESET_SYNC_STAGES,
        RESET_ACTIVE_LEVEL      => '0'
    )
    port map(
        --# {{clocks|}}
        Clock       => clk_c0,
        Reset       => RESET_BTN_N,

        --# {{data|}}
        Sync_reset => reset_c0_sync
    );

    -- Reset generation is based on the counter which holds the reset for 
    -- several clock cycles. The generator of the funciton is taken from the
    -- MSB bit of the counter vector.
    reset_c0_p : process(clk_c0)
    begin
        if(rising_edge(clk_c0))then
            if(locked = '0' or reset_c0_sync = '0') then
                -- Reset is locked
                reset_cnt_c0  <= (others=>'0');
            else
                -- Reset needs to be asserted (one clock cycle shoudl be enough)
                if(reset_cnt_c0(6) = '0')then
                    reset_cnt_c0 <= reset_cnt_c0 + 1;
                end if;
            end if;
        end if;
    end process;

    reset_ref_p : process(clk_ref)
    begin
        if(rising_edge(clk_ref))then
            if(reset_ref_sync = '0') then
                -- Reset is locked
                reset_cnt_ref  <= (others=>'0');
            else
                -- Reset needs to be asserted (one clock cycle shoudl be enough)
                if(reset_cnt_ref(6) = '0')then
                    reset_cnt_ref <= reset_cnt_ref + 1;
                end if;
            end if;
        end if;
    end process;

    -- Generated reset signals
    reset_c0    <= not(reset_cnt_c0(RESET_CNT_WIDTH-1));
    reset_ref   <= not(reset_cnt_ref(RESET_CNT_WIDTH-1));

    -- ------------------------------------------------------------------------
    -- UART connection -- it is passed to the 12MHz clock domain
    -- ------------------------------------------------------------------------

    -- UART endpoint for the communication with the software
    uart_i: entity work.UART
    generic map (
        CLK_FREQ      => CLK_FREQ,
        BAUD_RATE     => BAUD_RATE,
        PARITY_BIT    => PARITY_BIT,
        USE_DEBOUNCER => USE_DEBOUNCER
    )
    port map (
        CLK         => clk_ref,
        RST         => reset_ref,
        -- UART INTERFACE
        UART_TXD    => UART_TXD,
        UART_RXD    => UART_RXD,
        -- USER DATA OUTPUT INTERFACE
        DOUT        => uart_rx_dout,
        DOUT_VLD    => uart_rx_dout_vld,
        FRAME_ERROR => uart_rx_frame_error,
        -- USER DATA INPUT INTERFACE
        DIN         => uart_rx_din,
        DIN_VLD     => uart_rx_din_vld,
        DIN_RDY     => uart_rx_din_rdy
    );

    uart_stream_i : entity work.uart_stream_sync
        port map(
        -- --------------------------------
        -- Clocks & Reset
        -- --------------------------------
        RX_CLK      => clk_ref,
        RX_RESET    => reset_ref,
        TX_CLK      => clk_c0,
        TX_RESET    => reset_c0,
        
        -- --------------------------------
        -- UART RX & TX folks
        -- --------------------------------
        -- USER DATA INPUT INTERFACE
        RX_DIN         => uart_rx_din,
        RX_DIN_VLD     => uart_rx_din_vld,
        RX_DIN_RDY     => uart_rx_din_rdy,
        -- USER DATA OUTPUT INTERFACE
        RX_DOUT        => uart_rx_dout,
        RX_DOUT_VLD    => uart_rx_dout_vld,
        RX_FRAME_ERROR => uart_rx_frame_error,
        
        -- --------------------------------
        -- UART 
        -- --------------------------------
        -- UART --> APP
        TX_ADDR_OUT       => open,
        TX_DATA_OUT       => led_vector,
        TX_DATA_OUT_VLD   => led_vector_vld,
        TX_DATA_OUT_NEXT  => '1',

        -- APP --> UART
        TX_DATA_IN        => (others=>'0'),
        TX_DATA_IN_VLD    => '0',
        TX_DATA_IN_NEXT   => open
        ) ;

        -- Register for the storage of LED vector
        led_regp : process( clk_c0 )
        begin
            if(rising_edge(clk_c0))then
                if(reset_c0 = '1')then
                    reg_led_vector <= (others=>'0');
                else
                    if(led_vector_vld = '1')then
                        reg_led_vector <= led_vector;
                    end if;
                end if;
            end if;
        end process ; -- led_regp

        -- Demo output LED connections
        LED_0   <= reg_led_vector(0);
        LED_1   <= reg_led_vector(1);
        LED_2   <= reg_led_vector(2);
        LED_3   <= reg_led_vector(3);
        LED_4   <= reg_led_vector(4);
        LED_5   <= reg_led_vector(5);
        LED_6   <= reg_led_vector(6);
        LED_7   <= reg_led_vector(7);

end architecture;
