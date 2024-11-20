----------------------------------------------------------------------------------
-- Company: --
-- Engineer: Mehmet Fatih Turkoglu
-- 
-- Create Date: 09.10.2024 10:37:42
-- Design Name: Baud Rate Generator
-- Module Name: br_generator - Behavioral
-- Project Name: UART Driver RTL Design
-- Target Devices: --
-- Tool Versions: Vivado 2022.2 
-- Description: Baud rate generator ip with the generic parameter to choose
--              at which BR to work with. This ip assumes that the clk comes in
--              with the frequency of given generic MASTER_CLK_KHZ. Also IP takes
--              account for oversampling too with the generic parameter. 
-- 
-- Dependencies: --
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

entity br_generator is
    generic (
        MASTER_CLK_KHZ  : integer range 600000 downto 1     := 100000;      -- Master Clk Frequency ranging from 600 Mhz to 1 Khz
        BAUD_RATE_HZ    : integer range 921600 downto 4800  := 9600;        -- Baud rate clock frequench ranging from 921600 to 4800 Hz
        OVER_SAMPLING   : integer                           := 16           -- Over Sampling factor
    );
    port ( 
        clk      : in std_logic;         -- Master Clk, for basys3 100Mhz
        rst      : in std_logic;         -- Active High sync reset that used to reset the baud rate clock as well as counter counting
        br_clk   : out std_logic         -- Baud Clock output to be used
    );
end br_generator;

architecture behavioral of br_generator is
    constant N              : integer := MASTER_CLK_KHZ * 1000;          -- Numerator (convert kHz to Hz)
    constant D              : integer := BAUD_RATE_HZ * OVER_SAMPLING;   -- Denominator
    constant DIVIDER_VAL    : integer := N / D;             
    signal divider_cntr     : integer range DIVIDER_VAL downto 0 := 0;
    signal baud_clk_sig     : std_logic := '0';
begin

    BAUD_PROC : process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                baud_clk_sig <= '0';
                divider_cntr <= 0;
            else
                if(divider_cntr = ((DIVIDER_VAL / 2) - 1)) then
                    baud_clk_sig <= not baud_clk_sig;
                    divider_cntr <= 0;
                else
                    divider_cntr <= divider_cntr + 1;
                end if;
            end if;
        end if;
    end process;

    br_clk <= baud_clk_sig;

end behavioral;
