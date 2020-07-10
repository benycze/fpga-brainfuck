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

    constant RESET_CNT_WIDTH        : integer := 7;
    constant RESET_SYNC_STAGES      : integer := 4;

    -- The width is 24 bits, bacause log2(12e6) is 23.52 and
    -- therefore we need to have 24 bits to reach the maximal value in 1 second
    constant BLINK_LED_CNT_WIDTH    : integer := 24;
    
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

    signal design_ready         : std_logic;

    -- Signals for UART RX/TX signalization
    signal led_uart_rx_sig      : std_logic;
    signal led_uart_rx_en       : std_logic;

    signal led_uart_tx_sig      : std_logic;
    signal led_uart_tx_en       : std_logic;

    -- --------------------------------
    -- BCPU component & connection
    -- --------------------------------
    -- This part has to changed iff the bluespec interface is 
    -- also changed.
    component mkBCpu is
      port (
        RDY_read        : out std_logic;
        getData         : out std_logic_vector(7 downto 0);
        RDY_getData     : out std_logic;
        RDY_write       : out std_logic;
        getReadRunning  : out std_logic;
        getCpuEnabled   : out std_logic;
        CLK             : in std_logic;
        RST_N           : in std_logic;
        read_addr       : in std_logic_vector(19 downto 0);
        write_addr      : in std_logic_vector(19 downto 0);
        write_data      : in std_logic_vector(7 downto 0);
        EN_read         : in std_logic;
        EN_write        : in std_logic;
        EN_getData      : in std_logic
      ) ;
    end component;

    signal led_readRunning  : std_logic;
    signal led_cpuEnabled   : std_logic;
    signal bcpu_rst_n       : std_logic;

    signal bcpu_addr_out        : std_logic_vector(23 downto 0);
    signal bcpu_data_out        : std_logic_vector(7 downto 0);
    signal bcpu_data_out_vld    : std_logic;
    signal bcpu_data_out_next   : std_logic;
    signal bcpu_data_out_write  : std_logic;
    signal bcpu_data_in         : std_logic_vector(7 downto 0);
    signal bcpu_data_in_vld     : std_logic;
    signal bcpu_data_in_next    : std_logic;

    signal bcpu_read_en         : std_logic;
    signal bcpu_write_en        : std_logic;

    signal bcpu_rdy_read_out    : std_logic;
    signal bcpu_rdy_write_out   : std_logic;

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
    pll_i : entity work.pll 
    port map(
        inclk0		=> CLK,
        c0			=> clk_c0,
        locked		=> locked
    );

    -- Reference clock signal
    clk_ref <= CLK;

    -- Reset synchronization
    reset_sync_ref_i : entity work.reset_synchronizer 
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

    reset_sync_c0_i : entity work.reset_synchronizer 
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
                if(reset_cnt_c0(RESET_CNT_WIDTH-1) = '0')then
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
                if(reset_cnt_ref(RESET_CNT_WIDTH-1) = '0')then
                    reset_cnt_ref <= reset_cnt_ref + 1;
                end if;
            end if;
        end if;
    end process;

    -- Generated reset signals
    reset_c0    <= not(reset_cnt_c0(RESET_CNT_WIDTH-1));
    reset_ref   <= not(reset_cnt_ref(RESET_CNT_WIDTH-1));

    -- Design is ready iff everything is reseted (and reset is low) - we are using
    -- signals from different clock domains but it doen't matter it is just a LED light
    design_ready <= not(reset_c0 or reset_ref);

    -- ------------------------------------------------------------------------
    -- LED signalization
    -- ------------------------------------------------------------------------

    -- Generation of the UART RX activity LED signal
    led_uart_rx_en <= uart_rx_din_vld and uart_rx_din_rdy;

    led_uart_rx_i : entity work.blink
    generic map (
        CNT_WIDTH       => BLINK_LED_CNT_WIDTH
    )
    port map(
        -- --------------------------------
        -- Clocks & Reset 
        ----------------------------------- 
        CLK		        => clk_ref,
        RESET           => reset_ref,
    
        -- --------------------------------
        -- Input interface
        -- --------------------------------
        INDIC_EN        => led_uart_rx_en,
    
        -- --------------------------------
        -- Output interface 
        -- --------------------------------
        LED_EN          => led_uart_rx_sig
    );

    -- Generation of the UART TX activity LED signal
    led_uart_tx_en <= uart_rx_dout_vld;

    led_uart_tx_i : entity work.blink
    generic map(
        CNT_WIDTH      => BLINK_LED_CNT_WIDTH
    )
    port map(
        -- --------------------------------
        -- Clocks & Reset 
        ----------------------------------- 
        CLK		        => clk_ref,
        RESET           => reset_ref,
    
        -- --------------------------------
        -- Input interface
        -- --------------------------------
        INDIC_EN        => led_uart_tx_en,
    
        -- --------------------------------
        -- Output interface 
        -- --------------------------------
        LED_EN          => led_uart_tx_sig
    );

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
        RX_DIN              => uart_rx_dout,
        RX_DIN_VLD          => uart_rx_dout_vld,
        RX_DIN_FRAME_ERROR  => uart_rx_frame_error,

        -- USER DATA OUTPUT INTERFACE
        RX_DOUT             => uart_rx_din,
        RX_DOUT_VLD         => uart_rx_din_vld,
        RX_DOUT_RDY         => uart_rx_din_rdy,
        
        -- --------------------------------
        -- UART 
        -- --------------------------------
        -- UART --> APP
        TX_ADDR_OUT       => bcpu_addr_out,
        TX_DATA_OUT       => bcpu_data_out,
        TX_DATA_OUT_VLD   => bcpu_data_out_vld,
        TX_DATA_OUT_NEXT  => bcpu_data_out_next,
        TX_DATA_WRITE     => bcpu_data_out_write,

        -- APP --> UART
        TX_DATA_IN        => bcpu_data_in,
        TX_DATA_IN_VLD    => bcpu_data_in_vld,
        TX_DATA_IN_NEXT   => bcpu_data_in_next
        ) ;

    -- ------------------------------------------------------------------------
    -- Brainfuck CPU connection
    -- ------------------------------------------------------------------------

    bcpu_i: mkBCpu
    port map(
        RDY_read        => bcpu_rdy_read_out,
        getData         => bcpu_data_in,
        RDY_getData     => bcpu_data_in_next,
        RDY_write       => bcpu_rdy_write_out,
        getReadRunning  => led_readRunning,
        getCpuEnabled   => led_cpuEnabled,
        CLK             => clk_c0,
        RST_N           => bcpu_rst_n,
        read_addr       => bcpu_addr_out(19 downto 0),
        write_addr      => bcpu_addr_out(19 downto 0),
        write_data      => bcpu_data_out,
        EN_read         => bcpu_read_en,
        EN_write        => bcpu_write_en,
        EN_getData      => bcpu_data_in_vld
    ) ;

    -- Switch the right RDY signal based on the operation
    rdy_switchp:process(all)
    begin
        -- By default, we are switching the READ ready
        bcpu_data_out_next <= bcpu_rdy_read_out;
        if(bcpu_write_en = '1')then
            bcpu_data_out_next <= bcpu_rdy_write_out;
        end if;
    end process;

    -- Generation of read & write signals
    bcpu_read_en    <= not(bcpu_data_out_write) and bcpu_data_out_vld;
    bcpu_write_en   <= bcpu_data_out_write and bcpu_data_out_vld; 

    -- Reset signal is inverted
    bcpu_rst_n <= not(reset_c0);

    -- ------------------------------------------------------------------------
    -- Mapping of output signals
    -- ------------------------------------------------------------------------

    -- Demo output LED connections
    LED_0   <= design_ready;
    LED_1   <= led_uart_tx_sig;
    LED_2   <= led_uart_rx_sig;
    LED_3   <= led_readRunning;
    LED_4   <= led_cpuEnabled;
    LED_5   <= '0';
    LED_6   <= '0';
    LED_7   <= '0';

end architecture;
