----------------------------------------------------------------------------------
-- Company: --
-- Engineer: Mehmet Fatih Türkoğlu
-- 
-- Create Date: 09.10.2024 09:48:19
-- Design Name: UART Driver Top Module
-- Module Name: uart_top - Behavioral
-- Project Name: UART Driver RTL Design
-- Target Devices: --
-- Tool Versions: Vivado 2022.2 
-- Description: A hobby project
--                          
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

--use IEEE.NUMERIC_STD.ALL;

entity uart_top is
    generic (
        SYS_CLK_KHZ         : integer range 600000 downto 1     := 100000;      -- System Master Clk Frequency ranging from 600 Mhz to 1 Khz
        BAUD_RATE_HZ        : integer range 921600 downto 4800  := 9600;        -- Baud rate clock frequency ranging from 921600 to 4800 Hz
        OVER_SAMPLING       : integer                           := 16;          -- Over Sampling factor
        PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
        STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
        DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8            -- make sure that when DATA_FRAME_LENGTH is choosen to be 9, PARITY_BIT_LENGTH must be 0 !!
    );
    port (
        clk             : in std_logic;                                         -- System clock 
        tx              : out std_logic;                                        -- tx uart data line
        rx              : in std_logic;                                         -- rx uart data line
        tx_data         : in std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0);  -- tx_data vector fetched from tx_block FIFO read region
        rx_data         : out std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0); -- rx_data vector written to rx_block FIFO write region
        tx_data_en      : in std_logic;                                         -- tx_block FIFO 'FULL' signal flag (inverted)
        tx_data_done    : out std_logic;                                        -- tx_block FIFO read enable signal
        rx_data_en      : in std_logic;                                         -- rx_block FIFO 'EMPTY' signal flag (inverted)
        rx_data_done    : out std_logic;                                        -- rx_block FIFO write enable signal
        parity_err      : out std_logic                                         -- rx_block parity mismatch (calculated vs. received)
    );
end uart_top;

architecture behavioral of uart_top is
    component tx_block is
        generic (
            PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
            STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
            DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8;           -- make sure that when DATA_FRAME_LENGTH is choosen to be 9, PARITY_BIT_LENGTH must be 0 !!
            OVER_SAMPLING       : integer                           := 16           -- Over Sampling factor
        );
        port (
            br_clk        : in std_logic;                                             -- Over sampled Baud Rate clk ->  BAUD_RATE_HZ * OVER_SAMPLING Hz      
            tx_data       : in std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0);    
            tx_data_en    : in std_logic;                                             -- Input data enable bit
            tx_data_done  : out std_logic;                                            -- End of a UART packet notification
            tx            : out std_logic                                             -- 1 bit data out with the rate of baudrate
        );
    end component;

    component rx_block is
        generic (
            PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
            STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
            DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8;           -- make sure that when DATA_FRAME_LENGTH is choosen to be 9, PARITY_BIT_LENGTH must be 0 !!
            OVER_SAMPLING       : integer                           := 16          -- Over Sampling factor  
        );
        port (
            br_clk        : in std_logic;         -- oversampled baud rate clock -> BAUD_RATE_HZ * OVER_SAMPLING Hz
            rx            : in std_logic;         -- UART rx line
            rx_data_en    : in std_logic;         -- fifo full indication bit, 1 means not full, 0 means full cannot write to fifo
            rx_data_done  : out std_logic;        -- fifo write enable bit
            parity_err    : out std_logic;        -- parity error 
            rx_data       : out std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0)
        );
    end component;

    component br_generator is
        generic (
            MASTER_CLK_KHZ  : integer range 600000 downto 1     := 100000;      -- Master Clk Frequency ranging from 600 Mhz to 1 Khz
            BAUD_RATE_HZ    : integer range 921600 downto 4800  := 9600;        -- Baud rate clock frequency ranging from 921600 to 4800 Hz
            OVER_SAMPLING   : integer                           := 16           -- Over Sampling factor
        );
        port (
            clk      : in std_logic;         -- Master Clk, for basys3 100Mhz
            rst      : in std_logic;         -- Active High sync reset that used to reset the baud rate clock as well as counter counting
            br_clk   : out std_logic         -- Baud Clock output to be used
        );
    end component;

    signal br_clk : std_logic := '0';       -- internal baud rate clock signal comes from uart_br_gen device
begin

    uart_br_gen : br_generator
        generic map (
            MASTER_CLK_KHZ      => SYS_CLK_KHZ,
            BAUD_RATE_HZ        => BAUD_RATE_HZ,
            OVER_SAMPLING       => OVER_SAMPLING
        )
        port map (
            clk                 => clk,
            rst                 => '0',             -- Reset is not tend to use in this case
            br_clk            => br_clk
        );

    uart_tx : tx_block
        generic map (
            PARITY_BIT_LENGTH   => PARITY_BIT_LENGTH,
            STOP_BIT_LENGTH     => STOP_BIT_LENGTH,
            DATA_FRAME_LENGTH   => DATA_FRAME_LENGTH,
            OVER_SAMPLING       => OVER_SAMPLING
        )
        port map (
            br_clk              => br_clk,      
            tx_data             => tx_data,                 
            tx_data_en          => tx_data_en,
            tx_data_done        => tx_data_done,
            tx                  => tx
        );
    
    uart_rx : rx_block
        generic map (
            PARITY_BIT_LENGTH   => PARITY_BIT_LENGTH,
            STOP_BIT_LENGTH     => STOP_BIT_LENGTH,
            DATA_FRAME_LENGTH   => DATA_FRAME_LENGTH,
            OVER_SAMPLING       => OVER_SAMPLING
        )
        port map (
            br_clk              => br_clk,
            rx                  => rx,
            rx_data_en          => rx_data_en,
            rx_data_done        => rx_data_done,
            parity_err          => parity_err,
            rx_data             => rx_data
        );

end behavioral;
