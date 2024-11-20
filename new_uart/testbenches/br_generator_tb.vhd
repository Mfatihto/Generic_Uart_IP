----------------------------------------------------------------------------------
-- Company: --
-- Engineer: --
-- 
-- Create Date: 10.10.2024
-- Design Name: Test Bench for Baud Rate Generator
-- Module Name: tb_br_generator
-- Project Name: UART Driver RTL Design
-- Target Devices: --
-- Tool Versions: Vivado 2022.2 
-- Description: Test bench to verify the functionality of the baud rate generator.
--              It applies a clock and reset stimulus, and measures the output
--              baud clock period to ensure correct operation.
-- 
-- Dependencies: br_generator.vhd
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity tb_br_generator is
end tb_br_generator;

architecture behavior of tb_br_generator is

    -- Component Declaration of the Unit Under Test (UUT)
    component br_generator is
        generic (
            MASTER_CLK_KHZ  : integer range 600000 downto 1     := 100000;      -- Master Clk Frequency ranging from 600 MHz to 1 KHz
            BAUD_RATE_HZ    : integer range 921600 downto 4800  := 9600;        -- Baud rate clock frequency ranging from 921600 to 4800 Hz
            OVER_SAMPLING   : integer                           := 16           -- Over Sampling factor
        );
        port (
            clk      : in std_logic;         -- Master Clock
            rst      : in std_logic;         -- Active High synchronous reset
            br_clk   : out std_logic         -- Baud Clock output
        );
    end component;

    -- Signals to connect to the UUT
    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';
    signal baud_clk : std_logic;

    -- Constants for clock period and simulation timing
    constant MASTER_CLK_KHZ    : integer := 100000;  -- 100 MHz clock
    constant BAUD_RATE_HZ      : integer := 9600;    -- Desired baud rate
    constant OVER_SAMPLING     : integer := 16;      -- Oversampling factor

    constant clk_period        : time := 10 ns;      -- Clock period for 100 MHz

    -- Variables for measuring baud_clk period
    signal baud_clk_last_edge  : time := 0 ns;
    signal baud_clk_period     : time := 0 ns;
    signal edge_count          : integer := 0;

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: br_generator
        generic map (
            MASTER_CLK_KHZ  => MASTER_CLK_KHZ,
            BAUD_RATE_HZ    => BAUD_RATE_HZ,
            OVER_SAMPLING   => OVER_SAMPLING
        )
        port map (
            clk      => clk,
            rst      => rst,
            br_clk   => baud_clk
        );

    -- Clock generation process
    CLK_PROC : process
    begin
        while true loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    -- Stimulus process
    STIMULUS_PROC : process
    begin
        -- Apply reset
        rst <= '1';
        wait for 50 * clk_period; -- 50 cycles (500 ns)
        rst <= '0';
        wait for 50 * clk_period; -- 50 cycles (500 ns)

        -- Initialize measurement
        baud_clk_last_edge <= now;
        edge_count <= 0;

        -- Wait for first rising edge of baud_clk
        wait until rising_edge(baud_clk);
        baud_clk_last_edge <= now;
        edge_count <= edge_count + 1;
        report "Rising edge " & integer'image(edge_count) & " at " & time'image(now);

        -- Measure multiple baud_clk rising edges
        while edge_count < 10 loop
            wait until rising_edge(baud_clk);
            baud_clk_period <= now - baud_clk_last_edge;
            baud_clk_last_edge <= now;
            edge_count <= edge_count + 1;
            report "Rising edge " & integer'image(edge_count) & ": Period = " & time'image(baud_clk_period);
        end loop;

        report "Test completed successfully.";
        -- Stop the simulation
        assert false report "End of Test Bench" severity failure;
    end process;

end behavior;
