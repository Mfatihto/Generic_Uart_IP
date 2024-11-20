----------------------------------------------------------------------------------
-- Company: --
-- Engineer: Mehmet Fatih Turkoglu
-- 
-- Create Date: 10.10.2024 14:37:09
-- Design Name: UART transmitter block
-- Module Name: tx_block - Behavioral
-- Project Name: UART Driver RTL Design
-- Target Devices: --
-- Tool Versions: Vivado 2022.2
-- Description: tx_block receives br_clk from br_generator ip externally, that takes 
--              data and transfers it as an uart package and prompts the output at
--              the baud rate. Oversampling is used on this IP to sample 
--              BR * SAMPLING_FACTOR Hz frequency to get a better estimation on signals
--              when receiving.
-- 
-- Dependencies: --
-- 
-- Revision: --
-- Revision 0.01 - File Created
-- Additional Comments: --
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity tx_block is
    generic (
        PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
        STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
        DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8;           -- make sure that when DATA_FRAME_LENGTH is choosen to be 9, PARITY_BIT_LENGTH must be 0 !!
        OVER_SAMPLING       : integer                           := 16           -- Over Sampling factor
    );
    port ( 
        br_clk        : in std_logic;     -- Over sampled Baud Rate clk ->  BAUD_RATE_HZ * OVER_SAMPLING Hz      
        tx_data       : in std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0);    
        tx_data_en    : in std_logic;     -- Input data enable bit
        tx_data_done  : out std_logic;    -- End of a UART packet notification
        tx            : out std_logic     -- 1 bit data out with the rate of baudrate
    );
end tx_block;

architecture behavioral of tx_block is
    -- Define the states for the TX state machine
    type tx_state_type is (IDLE_STATE, START_STATE, DATA_STATE, PARITY_STATE, STOP_STATE);

    -- TX data output signal for transmission
    signal data_out_sig : std_logic := '0';

    -- State signals for the current and next states of the TX state machine
    signal curr_state, next_state : tx_state_type := IDLE_STATE;

    -- Clock counter to manage timing within each transmitted bit
    signal clk_cntr         : integer := 0;
    constant CLK_CNTR_VAL   : integer := (OVER_SAMPLING) - 1;             -- Total clock cycles in one bit period

    -- Buffer to store the input data for transmission
    signal data_in_buf : std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0) := (others=>'0');

    -- Index to track the position within the TX data buffer
    signal data_buf_idx : integer range DATA_FRAME_LENGTH - 1 downto 0 := 0;

    -- Buffer end indicator to signal when all bits in data buffer have been transmitted
    signal data_buf_end : std_logic := '0';                             

    -- Parity signal to calculate and send the parity bit (0 for odd, 1 for even)
    signal parity : std_logic := '0';                                   

    -- Counter to track stop bits in the transmission
    signal stop_cntr : integer range STOP_BIT_LENGTH downto 0 := 0;

    -- Data done signal to indicate completion of data transmission
    signal data_done_sig : std_logic := '0';

begin

    tx <= data_out_sig;
    tx_data_done <= data_done_sig;

    STATE_UPDATE_PROC : process(br_clk)
    begin
        if(rising_edge(br_clk)) then
            curr_state <= next_state;
        end if;
    end process;

    CLK_CNTR_PROC : process(br_clk)
    begin
        if(rising_edge(br_clk)) then
            if ((clk_cntr = CLK_CNTR_VAL) or (curr_state /= next_state)) then
                clk_cntr <= 0;
            else
                clk_cntr <= clk_cntr + 1;
            end if;
        end if;
    end process ; 

    FSM_STATE_PROC : process(curr_state, next_state, clk_cntr, data_buf_idx, stop_cntr, tx_data_en, data_buf_end)
    begin
        next_state <= curr_state;
        case curr_state is
            when IDLE_STATE     =>
                if(tx_data_en = '1') then
                    next_state <= START_STATE;
                else
                    next_state <= IDLE_STATE;
                end if;

            when START_STATE    =>   
                if(clk_cntr = CLK_CNTR_VAL) then
                    next_state <= DATA_STATE;
                else
                    next_state <= START_STATE;
                end if;

            when DATA_STATE     =>
                if(data_buf_end = '1') then
                    if(PARITY_BIT_LENGTH /= 0) then
                        next_state <= PARITY_STATE;
                    else
                        next_state <= STOP_STATE;
                    end if;
                else
                    next_state <= DATA_STATE;
                end if;

            when PARITY_STATE   =>
                -- if(PARITY_BIT_LENGTH /= 0) then
                    if(clk_cntr = CLK_CNTR_VAL) then
                        next_state <= STOP_STATE;
                    else
                        next_state <= PARITY_STATE;
                    end if;
                -- else
                    -- next_state <= STOP_STATE;
                -- end if;
                
            when STOP_STATE     =>
                if(stop_cntr = STOP_BIT_LENGTH) then
                    next_state <= IDLE_STATE;
                else
                    next_state <= STOP_STATE;
                end if;
        
            when others         =>              -- when a unkown state is captured, go to IDLE_STATE to start over
                next_state <= IDLE_STATE;
        end case;
    end process;

    FSM_OUTPUT_PROC : process(curr_state, clk_cntr, data_buf_idx, data_in_buf, parity, stop_cntr, data_done_sig, data_out_sig)
    begin
        case curr_state is
            when IDLE_STATE     =>
                if((clk_cntr < CLK_CNTR_VAL) and (data_done_sig /= '0')) then     -- keep the rx_done signal high for 1 br period if it was set
                    data_done_sig <= '1';
                else
                    data_done_sig <= '0';
                end if;      
                data_out_sig <= '1';                    -- held output high when idle

            when START_STATE    =>                      -- held output low for 1 baudrate cycle also store the input buffer
                data_done_sig <= '0';
                data_out_sig <= '0';                    -- for 1 bandwidth period of time held output to '0' 
                
            when DATA_STATE     =>                      -- prompt the data_out with data_in_buf 
                data_done_sig <= '0';
                data_out_sig <= data_in_buf(data_buf_idx);  -- sending data_in_buf starting from LSB to MSB

            when PARITY_STATE   =>                      -- put parity bit based on summation of data_in_buf
                data_done_sig <= '0';
                if(parity = '0') then
                    data_out_sig <= '0';                -- odd parity
                else
                    data_out_sig <= '1';                -- even parity
                end if;
                
            when STOP_STATE     =>
                data_out_sig <= '1';
                if(stop_cntr = (STOP_BIT_LENGTH)) then      -- make sure data_done_sig is set for 1 baud rate cycle at the end of the STOP_STATE
                    data_done_sig <= '1';
                else
                    data_done_sig <= '0';
                end if;

            when others         =>
                data_out_sig <= '1';
                data_done_sig <= '0';
        end case;
    end process;

    FSM_DATA_PROC : process(br_clk)
        variable parity_sum : integer range DATA_FRAME_LENGTH downto 0 := 0;
    begin
        if(rising_edge(br_clk)) then
            case curr_state is
                when IDLE_STATE     =>                      -- Reset all the signals at IDLE_STATE
                    data_in_buf <= (others=>'0');
                    data_buf_idx <= 0;
                    parity_sum := 0;
                    data_buf_end <= '0';
                    parity <= '0';
                    stop_cntr <= 0;
    
                when START_STATE    =>                      -- held output low for 1 baudrate cycle also store the input buffer
                    if(clk_cntr = 0) then               -- store the input buffer and parity_sum for once
                        parity_sum := 0;
                        for i in 0 to (DATA_FRAME_LENGTH - 1) loop
                            if(tx_data(i) = '1') then
                                parity_sum := parity_sum + 1;
                            end if;
                        end loop;

                        if((parity_sum mod 2) /= 0) then
                            parity <= '1';                  -- odd parity
                        else
                            parity <= '0';                  -- even parity
                        end if;
                        data_in_buf <= tx_data;
                    else
                        data_in_buf <= data_in_buf;
                    end if;

                    
                when DATA_STATE     =>                      -- prompt the data_out with data_in_buf 
                    if((clk_cntr = CLK_CNTR_VAL) or (next_state /= curr_state)) then
                        if(data_buf_idx = (DATA_FRAME_LENGTH - 1)) then    
                            data_buf_end <= '1';
                        else 
                            data_buf_end <= '0';
                            data_buf_idx <= data_buf_idx + 1;
                        end if;
                    end if;
    
                when PARITY_STATE   =>                      
                    
                when STOP_STATE     =>
                    if((clk_cntr = CLK_CNTR_VAL) and (stop_cntr /= STOP_BIT_LENGTH)) then
                        stop_cntr <= stop_cntr + 1;
                    else
                        stop_cntr <= stop_cntr;
                    end if;
            
                when others         =>
            end case;
        end if;
    end process;

end behavioral;
