----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/21/2024 02:10:08 PM
-- Design Name: 
-- Module Name: rx_block - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

entity rx_block is
    generic (
        PARITY_BIT_LENGTH   : integer range 1 downto 0          := 1;
        STOP_BIT_LENGTH     : integer range 2 downto 1          := 1; 
        DATA_FRAME_LENGTH   : integer range 9 downto 5          := 8;           -- make sure that when DATA_FRAME_LENGTH is choosen to be 9, PARITY_BIT_LENGTH must be 0 !!
        OVER_SAMPLING       : integer                           := 16          -- Over Sampling factor  
    );
    port 
    ( 
        br_clk        : in std_logic;         -- oversampled baud rate clock -> BAUD_RATE_HZ * OVER_SAMPLING Hz
        rx            : in std_logic;         -- UART rx line
        rx_data_en    : in std_logic;         -- fifo full indication bit, 1 means not full, 0 means full cannot write to fifo
        rx_data_done  : out std_logic;        -- fifo write enable bit
        parity_err    : out std_logic;        -- parity error 
        rx_data       : out std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0)
    );
end rx_block;

architecture behavioral of rx_block is
    -- Define the states for the RX state machine
    type rx_state_type is (IDLE_STATE, START_STATE, DATA_STATE, PARITY_STATE, STOP_STATE);

    -- State signals for the current and next states of the RX state machine
    signal curr_state, next_state : rx_state_type := IDLE_STATE;

    -- Clock counter configuration
    constant CLK_CNTR_VAL   : integer := (OVER_SAMPLING) - 1;                   -- Total clock cycles in a bit period
    signal clk_cntr         : integer := 0;                                     -- Counter to track sampling point within a bit
    constant CLK_CNTR_MID   : integer := (OVER_SAMPLING / 2) - 1;               -- Midpoint for detecting bit transitions

    -- RX line signals for capturing current and next RX line values
    signal rx_curr, rx_next : std_logic := '0';

    -- RX valid signal, where '1' indicates valid RX data and '0' indicates invalid data
    signal rx_valid         : std_logic := '1';                                 -- 1 shows valid and 0 shows not valid at start 

    -- Parity signals to handle received and calculated parity values for error checking
    signal parity_received      : std_logic := '0';                             -- Received parity bit
    signal parity_calculated    : std_logic := '0';                             -- Calculated parity to compare with received parity

    -- Buffer to store incoming RX data bits
    signal rx_buf   : std_logic_vector(DATA_FRAME_LENGTH - 1 downto 0) := (others=>'0');

    -- Index for tracking position in RX data buffer
    signal rx_buf_idx : integer range 0 to DATA_FRAME_LENGTH - 1 := 0;

    -- Indicator for end of RX data buffer
    signal rx_buf_end : std_logic := '0';                                -- RX data buffer end indicator

    -- Counter to track received stop bits
    signal stop_bit_cntr : integer range 0 to STOP_BIT_LENGTH := 0;

    -- RX done signal to indicate completion of RX data reception
    signal rx_done_sig : std_logic := '0';

    -- Parity error signal to indicate if there was a parity mismatch
    signal parity_err_sig : std_logic := '0';

begin

    rx_next <= rx;
    parity_err <= parity_err_sig;

    STATE_UPDATE_PROC : process(br_clk)
    begin
        if(rising_edge(br_clk)) then
            curr_state <= next_state;
            rx_curr <= rx_next;
            rx_data_done <= rx_done_sig;
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

    FSM_STATE_PROC : process(curr_state, next_state, clk_cntr, rx_curr, rx_next, rx_buf_end, rx_data_en, rx_valid, parity_received, parity_calculated, stop_bit_cntr, rx_buf)
    begin
        next_state <= curr_state;
        case curr_state is
            when IDLE_STATE     =>
                if((rx_curr = '1' and rx_next = '0') and (rx_data_en = '1')) then    -- start receiving uart data when a falling-edge detected when fifo is not full
                    next_state <= START_STATE;
                else
                    next_state <= IDLE_STATE;
                end if;

            when START_STATE    =>
                if(rx_valid /= '1') then                    -- if there is not a valid UART receive comes then go back to IDLE_STATE for a new receive
                    next_state <= IDLE_STATE;
                elsif(clk_cntr = CLK_CNTR_VAL) then         -- at the end of the br period while rx_valid is high go to the DATA_STATE              
                    next_state <= DATA_STATE;
                else
                    next_state <= START_STATE;
                end if;

            when DATA_STATE     =>
                if(rx_buf_end = '1') then
                    if(PARITY_BIT_LENGTH /= 0) then
                        next_state <= PARITY_STATE;
                    else
                        next_state <= STOP_STATE;
                    end if;
                else
                    next_state <= DATA_STATE;
                end if;

            when PARITY_STATE   =>
                -- if(PARITY_BIT_LENGTH /= 0) then                         -- check wheter parity is used first 
                    if(clk_cntr = CLK_CNTR_VAL) then                    -- compare calculated and received parities at the end of the baud period
                        next_state <= STOP_STATE;                       -- go to stop state if parities match
                    else
                        next_state <= PARITY_STATE;
                    end if;
                -- else
                --     next_state <= STOP_STATE;
                -- end if;

            when STOP_STATE     =>
                if(stop_bit_cntr = STOP_BIT_LENGTH) then
                    next_state <= IDLE_STATE;
                else
                    next_state <= STOP_STATE;    
                end if;

            when others         =>             
                next_state <= IDLE_STATE;
        end case;
    end process;

    FSM_OUTPUT_PROC : process(curr_state, stop_bit_cntr, clk_cntr, parity_received, parity_calculated, rx_buf, rx_done_sig, parity_err_sig)
    begin
        rx_data <= rx_buf;
        case curr_state is
            when IDLE_STATE     =>
                if((clk_cntr < CLK_CNTR_VAL) and (rx_done_sig /= '0')) then     -- keep the rx_done signal high for 1 br period if it was set
                    rx_done_sig <= '1';
                else
                    rx_done_sig <= '0';
                end if;    
                parity_err_sig <= '0';
            when START_STATE    =>
                rx_done_sig <= '0';
                parity_err_sig <= '0';
            when DATA_STATE     =>
                rx_done_sig <= '0';
                parity_err_sig <= '0';
            when PARITY_STATE   =>
                rx_done_sig <= '0';
                if((clk_cntr = CLK_CNTR_VAL) and (parity_received /= parity_calculated)) then   -- when parities are not match held parity_err_sig output high for 1 br period
                    parity_err_sig <= '1';
                else
                    parity_err_sig <= '0';
                end if;
            when STOP_STATE     =>
                if((stop_bit_cntr = STOP_BIT_LENGTH)) then    -- held rx_done signal for 1 br period long when all the stop bits are received
                    rx_done_sig <= '1';
                    parity_err_sig <= '0';
                else
                    rx_done_sig <= '0';
                    if(parity_err_sig /= '1') then
                        parity_err_sig <= '0';
                    else
                        parity_err_sig <= '1';
                    end if;
                end if;
            when others         =>
                rx_done_sig <= '0';
                parity_err_sig <= '0';
        end case;
    end process;

    DATA_PROC : process(br_clk)
        variable parity_sum : integer range DATA_FRAME_LENGTH downto 0 := 0;
    begin
    if(rising_edge(br_clk)) then
        case curr_state is
            when IDLE_STATE     =>
                rx_valid <= '1';
                rx_buf_idx <= 0;
                rx_buf_end <= '0';
                stop_bit_cntr <= 0;
                parity_received <= '0';
                parity_calculated <= '0';

            when START_STATE    =>
                if((clk_cntr <= CLK_CNTR_MID + 1) and (rx_curr /= '0')) then    -- while counting to the CLK_CNTR_MID if a rx value goes to high then its a not valid UART receive
                    rx_valid <= '0';
                end if;

            when DATA_STATE     =>
                if((clk_cntr = CLK_CNTR_MID)) then
                    rx_buf(rx_buf_idx) <= rx_curr;
                    if(rx_buf_idx = DATA_FRAME_LENGTH - 1) then
                        rx_buf_idx <= 0;
                    else
                        rx_buf_idx <= rx_buf_idx + 1;
                    end if;
                elsif((rx_buf_idx = 0) and (clk_cntr = CLK_CNTR_VAL)) then 
                    rx_buf_end <= '1';
                end if;  

            when PARITY_STATE   =>
                if((clk_cntr = CLK_CNTR_MID) and (PARITY_BIT_LENGTH /= 0)) then
                    parity_received <= rx_curr;
                elsif(clk_cntr = CLK_CNTR_VAL - 1) then                             -- 1 clock cycle before end of the br period calculate parity                        
                    parity_sum := 0;
                    for i in 0 to (DATA_FRAME_LENGTH - 1) loop
                        if(rx_buf(i) = '1') then
                            parity_sum := parity_sum + 1;
                        end if;

                        if((parity_sum mod 2) /= 0) then
                            parity_calculated <= '1';                  -- odd parity
                        else
                            parity_calculated <= '0';                  -- even parity
                        end if;
                    end loop;
                end if;

            when STOP_STATE     =>                                          -- wait STOP_BIT_LENGTH * br period time before going to the IDLE_STATE
                if((clk_cntr = CLK_CNTR_VAL) and (stop_bit_cntr /= STOP_BIT_LENGTH)) then
                    stop_bit_cntr <= stop_bit_cntr + 1;
                else
                    stop_bit_cntr <= stop_bit_cntr;
                end if;

            when others         =>
        end case;
    end if;
end process;

end behavioral;
