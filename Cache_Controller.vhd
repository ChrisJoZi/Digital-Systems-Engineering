----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Asif Choudhury & Christopher Zita
-- 
-- Create Date:    18:24:44 09/24/2025 
-- Design Name: 
-- Module Name:    Cache_Controller - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cache_controller is
    Port ( 
        clk         : in  STD_LOGIC;
        CPU_addr        : in  STD_LOGIC_VECTOR (15 downto 0);
        wr_rd       : in  STD_LOGIC;   -- 1 = write, 0 = read
        chipsel     : in  STD_LOGIC;
        cpu_RDY     : out STD_LOGIC;
        SDRAM_addr  : out STD_LOGIC_VECTOR (15 downto 0);
        SDRAM_wrRd : out STD_LOGIC;
        memstrobe       : out STD_LOGIC;
        SRAM_addr   : out STD_LOGIC_VECTOR (7 downto 0);
        SRAM_wEn    : out STD_LOGIC;
        dinSel     : out STD_LOGIC;
        doutSel    : out STD_LOGIC;
        currentState        : out STD_LOGIC_VECTOR(2 downto 0);
        valid        : out STD_LOGIC;
        dirty        : out STD_LOGIC;
        currentTag  : out STD_LOGIC_VECTOR(7 downto 0)
    );
end cache_controller;

architecture Behavioral of cache_controller is
    signal tag    : std_logic_vector(7 downto 0);
    signal index  : std_logic_vector(2 downto 0);
    signal offset : std_logic_vector(4 downto 0);

    type tag_memory is array (0 to 7) of std_logic_vector(7 downto 0);
    signal tag_array   : tag_memory := (others => (others => '0'));
    signal valid_array : std_logic_vector(7 downto 0) := (others => '0');
    signal dirty_array : std_logic_vector(7 downto 0) := (others => '0');

    -- States
    type state_type is (READY, HIT, MISS, WRITE_BACK, BLOCK_REFILL);
    signal state : state_type := READY;

    signal transfer_counter : unsigned(6 downto 0) := (others => '0');
    signal old_tag : std_logic_vector(7 downto 0) := (others => '0');
    signal pending_wr_rd : std_logic := '0';

begin
    tag    <= CPU_addr(15 downto 8);
    index  <= CPU_addr(7 downto 5);
    offset <= CPU_addr(4 downto 0);
    
    process(clk)
        variable idx : integer range 0 to 7;
    begin
        if rising_edge(clk) then
            idx := to_integer(unsigned(index));
            
            case state is

                when READY =>
                    cpu_RDY     <= '1';
                    SRAM_wEn    <= '0';
                    dinSel     <= '0';
                    doutSel    <= '0';
                    memstrobe       <= '0';
                    SDRAM_wrRd <= '0';
                    transfer_counter <= (others => '0');
                    SRAM_addr   <= index & offset;
                    SDRAM_addr  <= CPU_addr;
                    
                    if chipsel = '1' then
                        cpu_RDY <= '0';
                        if valid_array(idx) = '1' and tag_array(idx) = tag then
                            -- HIT
                            state <= HIT;
                        else
                            -- MISS
                            old_tag <= tag_array(idx);
                            pending_wr_rd <= wr_rd;
                            state <= MISS;
                        end if;
                    end if;


                when HIT =>
                    -- On hit: choose data path
                    SRAM_addr <= index & offset;
                    if wr_rd = '1' then
                        -- Write hit
                        SRAM_wEn <= '1';
                        dinSel  <= '1';  -- select CPU data to BRAM
                        dirty_array(idx) <= '1';
                        valid_array(idx) <= '1';
                    else
                        -- Read hit
                        doutSel <= '1';  -- select BRAM to CPU
                    end if;
                    state <= READY;


                when MISS =>
                    -- Miss: write-back if line valid & dirty, else proceed to refill
                    if valid_array(idx) = '1' and dirty_array(idx) = '1' then
                        SDRAM_wrRd <= '1';          -- prepare for write
                        transfer_counter <= (others => '0');
                        memstrobe <= '0';
                        state <= WRITE_BACK;
                    else
                        SDRAM_wrRd <= '0';          -- prepare for read
                        transfer_counter <= (others => '0');
                        memstrobe <= '0';
                        state <= BLOCK_REFILL;
                    end if;


                when WRITE_BACK =>
                    -- Two-cycle per beat: issue (even) then commit (odd)
                    if transfer_counter(0) = '0' then
                        -- Even: set addresses; next cycle data will be valid from BRAM
                        SDRAM_addr(15 downto 5) <= old_tag & index;
                        SDRAM_addr(4 downto 0)  <= std_logic_vector(transfer_counter(6 downto 2));
                        SRAM_addr               <= index & std_logic_vector(transfer_counter(6 downto 2));
                        memstrobe                   <= '0';
                        transfer_counter        <= transfer_counter + 1;
                    else
                        -- Odd: now BRAM data is valid -> drive SDRAM write
                        SDRAM_wrRd <= '1';
                        memstrobe      <= '1';
                        if transfer_counter(6 downto 2) = "11111" then
                            -- Done write-back
                            dirty_array(idx) <= '0';
                            transfer_counter <= (others => '0');
                            SDRAM_wrRd <= '0';
                            state <= BLOCK_REFILL;
                        else
                            transfer_counter <= transfer_counter + 1;
                        end if;
                    end if;


                when BLOCK_REFILL =>
                    -- Two-cycle per beat: issue (even) then capture (odd)
                    if transfer_counter(0) = '0' then
                        -- Even: set SDRAM read address and target BRAM address
                        SDRAM_addr(15 downto 5) <= tag & index;
                        SDRAM_addr(4 downto 0)  <= std_logic_vector(transfer_counter(6 downto 2));
                        SRAM_addr               <= index & std_logic_vector(transfer_counter(6 downto 2));
                        memstrobe                   <= '1';   -- request read
                        SDRAM_wrRd             <= '0';
                        transfer_counter        <= transfer_counter + 1;
                    else
                        -- Odd: capture SDRAM data into BRAM
                        memstrobe   <= '0';
                        SRAM_wEn <= '1';
                        dinSel <= '0';  -- select SDRAM data -> BRAM
                        if transfer_counter(6 downto 2) = "11111" then
                            -- Done refill: update tag & valid
                            tag_array(idx)   <= tag;
                            valid_array(idx) <= '1';
                            dirty_array(idx) <= '0';
                            -- If original op was write, perform store now
                            if pending_wr_rd = '1' then
                                SRAM_addr <= index & offset;
                                SRAM_wEn <= '1';
                                dinSel <= '1';  -- CPU data -> BRAM
                                dirty_array(idx) <= '1';
                            end if;
                            state <= READY;
                            transfer_counter <= (others => '0');
                        else
                            transfer_counter <= transfer_counter + 1;
                        end if;
                    end if;

            end case;
        end if;
    end process;

    ---------------------------------------------------------
    -- DEBUG OUTPUTS for ILA
    ---------------------------------------------------------
    currentState <= std_logic_vector(to_unsigned(state_type'pos(state), 3));
    valid <= valid_array(to_integer(unsigned(index)));
    dirty <= dirty_array(to_integer(unsigned(index)));
    currentTag <= tag_array(to_integer(unsigned(index)));

end Behavioral;