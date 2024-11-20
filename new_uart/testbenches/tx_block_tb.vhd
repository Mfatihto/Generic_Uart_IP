----------------------------------------------------------------------------------
-- Company: --
-- Engineer: Mehmet Fatih Turkoglu
--
-- Create Date: 10.10.2024
-- Design Name: UART transmitter block Test Bench
-- Module Name: tx_block_tb - Behavioral
-- Project Name: UART Driver RTL Design
-- Target Devices: --
-- Tool Versions: Vivado 2022.2
-- Description:
--     Test bench for tx_block module. Simulates UART transmission by providing
--     stimuli to the tx_block and observing the data_out signal.
--
-- Dependencies: tx_block.vhd
--
-- Revision: --
-- Revision 0.01 - File Created
-- Additional Comments: --
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tx_block_tb is
end tx_block_tb;

architecture behavioral of tx_block_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component tx_block
        generic (
            PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
            STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
            DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8;  -- Assuming DATA_FRAME_LENGTH = 8
            OVER_SAMPLING       : integer                           := 16;
            BAUD_RATE_HZ        : integer range 921600 downto 4800  := 9600
        );
        port (
            br_clk        : in std_logic;     -- Over sampled Baud Rate clock
            tx_data       : in std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0);
            tx_data_en    : in std_logic;     -- Input data enable bit
            tx_data_done  : out std_logic;    -- End of a UART packet notification
            tx            : out std_logic     -- 1-bit data out at the baud rate
        );
    end component;

    -- Signal Declarations
    signal br_clk_tb      : std_logic := '0';
    signal data_in_tb     : std_logic_vector(7 downto 0) := (others => '0');
    signal data_in_en_tb  : std_logic := '0';
    signal data_done_tb   : std_logic;
    signal data_out_tb    : std_logic;

    -- Clock Period Definitions
    constant BAUD_RATE_HZ     : integer := 9600;
    constant OVER_SAMPLING    : integer := 16;
    constant BR_CLK_FREQ      : integer := BAUD_RATE_HZ * OVER_SAMPLING; -- 9600 * 16 = 153600 Hz
    constant BR_CLK_PERIOD    : time := 1 sec / real(BR_CLK_FREQ);       -- ~6.5104 us

    -- Bit Period Definition
    constant BIT_PERIOD       : time := 1 sec / real(BAUD_RATE_HZ);      -- ~104.1667 us

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: tx_block
        generic map (
            PARITY_BIT_LENGTH   => 1,
            STOP_BIT_LENGTH     => 2,
            DATA_FRAME_LENGTH   => 8,
            OVER_SAMPLING       => OVER_SAMPLING,
            BAUD_RATE_HZ        => BAUD_RATE_HZ
        )
        port map (
            br_clk        => br_clk_tb,
            tx_data       => data_in_tb,
            tx_data_en    => data_in_en_tb,
            tx_data_done  => data_done_tb,
            tx            => data_out_tb
        );

    -- Clock Generation Process
    br_clk_process : process
    begin
        loop
            br_clk_tb <= '0';
            wait for BR_CLK_PERIOD / 2;
            br_clk_tb <= '1';
            wait for BR_CLK_PERIOD / 2;
        end loop;
    end process br_clk_process;

    -- Stimulus Process
    stim_proc: process
    begin
        -- Wait for initial period
        wait for 100 * BR_CLK_PERIOD;

        -- Test Case 1: Transmit 0xAA (10101010)
        data_in_tb <= "11110101";
        data_in_en_tb <= '1';
        wait for BR_CLK_PERIOD;
        data_in_en_tb <= '0';

        -- Wait for transmission to complete
        wait until data_done_tb = '1';
        wait for BIT_PERIOD; -- Wait a bit more to ensure completion

        -- Test Case 2: Transmit 0x55 (01010101)
        data_in_tb <= "01010101";
        data_in_en_tb <= '1';
        wait for BR_CLK_PERIOD;
        data_in_en_tb <= '0';

        wait until data_done_tb = '1';
        wait for BIT_PERIOD;

        -- Test Case 3: Transmit 0xFF (11111111)
        data_in_tb <= "11111111";
        data_in_en_tb <= '1';
        wait for BR_CLK_PERIOD;
        data_in_en_tb <= '0';

        wait until data_done_tb = '1';
        wait for BIT_PERIOD;

        -- Test Case 4: Transmit 0x00 (00000000)
        data_in_tb <= "00000000";
        data_in_en_tb <= '1';
        wait for BR_CLK_PERIOD;
        data_in_en_tb <= '0';

        wait until data_done_tb = '1';
        wait for BIT_PERIOD;

        -- End of simulation
        wait;
    end process stim_proc;

end behavioral;
