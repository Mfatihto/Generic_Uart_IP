library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rx_block_tb is
end rx_block_tb;

architecture behavioral of rx_block_tb is

    -- Component declaration for rx_block
    component rx_block is
        generic (
            PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
            STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
            DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8; -- Ensure when DATA_FRAME_LENGTH is chosen to be 9, PARITY_BIT_LENGTH must be 0
            OVER_SAMPLING       : integer                           := 16; -- Over Sampling factor  
            BAUD_RATE_HZ        : integer range 921600 downto 4800  := 9600 -- Baud rate ranging from 921600 to 4800 Hz
        );
        port ( 
            br_clk        : in std_logic;         -- Oversampled baud rate clock
            rx            : in std_logic;         -- UART rx line
            rx_data_en    : in std_logic;         -- FIFO full indication bit (1 means not full)
            rx_data_done  : out std_logic;        -- FIFO write enable bit
            parity_err    : out std_logic;        -- Parity error 
            rx_data       : out std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0)
        );
    end component;


    -- Clock period definitions
    constant BAUD_RATE_HZ           : integer   := 9600;
    constant OVER_SAMPLING          : integer   := 16;
    constant BR_CLK_FREQ            : integer   := BAUD_RATE_HZ * OVER_SAMPLING; -- 153600 Hz
    constant BR_CLK_PERIOD          : time      := 1 sec / real(BR_CLK_FREQ);       -- Approximately 6.5104 us
    constant DATA_FRAME_LENGTH      : integer   := 8;    
    constant STOP_BIT_LENGTH        : integer   := 1;    
    constant PARITY_BIT_LENGTH      : integer   := 1;    
    constant BIT_PERIOD             : time      := BR_CLK_PERIOD * OVER_SAMPLING;   -- UART bit duration (~104.1667 us)
    
    -- Helper constants
    constant FRAME_SIZE      : integer := 1 + DATA_FRAME_LENGTH + PARITY_BIT_LENGTH + STOP_BIT_LENGTH; -- Total bits in UART frame

    
    -- Signals for connecting to rx_block
    signal br_clk     : std_logic := '0';
    signal rx         : std_logic := '1'; -- UART idle state is high
    signal wr_en      : std_logic := '1'; -- FIFO is not full
    signal rx_done    : std_logic;
    signal parity_err : std_logic;
    signal rx_data    : std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0);

begin

    -- Instantiate the rx_block
    uut: rx_block
        generic map (
            PARITY_BIT_LENGTH   => PARITY_BIT_LENGTH,
            STOP_BIT_LENGTH     => STOP_BIT_LENGTH,
            DATA_FRAME_LENGTH   => DATA_FRAME_LENGTH,
            OVER_SAMPLING       => OVER_SAMPLING,
            BAUD_RATE_HZ        => BAUD_RATE_HZ
        )
        port map (
            br_clk        => br_clk,
            rx            => rx,
            rx_data_en    => wr_en,
            rx_data_done  => rx_done,
            parity_err    => parity_err,
            rx_data       => rx_data
        );

    -- Clock generation process for br_clk
    br_clk_process : process
    begin
        while true loop
            br_clk <= '0';
            wait for BR_CLK_PERIOD / 2;
            br_clk <= '1';
            wait for BR_CLK_PERIOD / 2;
        end loop;
    end process;

    -- Stimulus process to send UART frames
    stimulus_process : process
        variable tx_data_bits : std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0);
        variable uart_frame   : std_logic_vector(FRAME_SIZE - 1 downto 0); -- Start bit + Data bits + Parity bit + Stop bit(s)
        variable parity_bit   : std_logic;
        variable num_ones     : integer;
        variable i            : integer;
    begin
        -- Wait for the system to stabilize
        wait for 100 us;
        wr_en <= '1';
        -- **First Test Case: Correct Data Frame ('A' character)**
        -- Prepare data to send: character 'A' (ASCII 65, binary 01000001)
        tx_data_bits := "11000001";

        -- Reverse bits for LSB first transmission
        tx_data_bits := tx_data_bits(DATA_FRAME_LENGTH - 1 downto 0);

        -- Prepare UART frame
        -- Start bit
        uart_frame(0) := '0';
        -- Data bits (LSB first)
        for i in 0 to DATA_FRAME_LENGTH - 1 loop
            uart_frame(i + 1) := tx_data_bits(i);
        end loop;
        -- Calculate parity (even parity)
        num_ones := 0;
        for i in 0 to DATA_FRAME_LENGTH - 1 loop
            if tx_data_bits(i) = '1' then
                num_ones := num_ones + 1;
            end if;
        end loop;
        if (num_ones mod 2) = 0 then
            parity_bit := '1'; -- Odd number of ones, parity bit is '1' for even parity
        else
            parity_bit := '0'; -- Even number of ones, parity bit is '0' for even parity
        end if;
        uart_frame(DATA_FRAME_LENGTH + 1) := parity_bit;
        -- Stop bit(s)
        for i in 0 to STOP_BIT_LENGTH - 1 loop
            uart_frame(DATA_FRAME_LENGTH + PARITY_BIT_LENGTH + 1 + i) := '1';
        end loop;

        -- Transmit the UART frame on rx line
        for i in 0 to FRAME_SIZE - 1 loop
            rx <= uart_frame(i);
            wait for BIT_PERIOD;
        end loop;

        -- Return rx to idle state
        rx <= '1';

        -- Wait to observe outputs
        wait for 2 ms;

        -- **Second Test Case: Data Frame with Parity Error**
        -- Introduce a parity error by flipping the parity bit
        if parity_bit = '0' then
            uart_frame(DATA_FRAME_LENGTH + 1) := '1';
        else
            uart_frame(DATA_FRAME_LENGTH + 1) := '0';
        end if;

        -- Transmit the UART frame with parity error
        for i in 0 to FRAME_SIZE - 1 loop
            rx <= uart_frame(i);
            wait for BIT_PERIOD;
        end loop;

        -- Return rx to idle state
        rx <= '1';

        -- Wait to observe outputs
        wait for 2 ms;

        -- **Third Test Case: Data Frame with Framing Error (Invalid Stop Bit)**
        -- Prepare a correct data frame but set the stop bit to '0' (should be '1')
        uart_frame(DATA_FRAME_LENGTH + PARITY_BIT_LENGTH + 1) := '0'; -- Invalid stop bit

        -- Transmit the UART frame with framing error
        for i in 0 to FRAME_SIZE - 1 loop
            rx <= uart_frame(i);
            wait for BIT_PERIOD;
        end loop;

        -- Return rx to idle state
        rx <= '1';

        -- Wait to observe outputs
        wait for 2 ms;

        -- End of simulation
        wait;
    end process;

end behavioral;
