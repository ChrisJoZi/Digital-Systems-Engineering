----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Asif Choudhury & Christopher Zita
-- 
-- Create Date:    22:19:01 10/16/2025 
-- Design Name: 
-- Module Name:    SDRAM_Controller - Behavioral 
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

entity SDRAM_Controller is
    Port ( 
		clk   : in  STD_LOGIC;
		addr  : in  STD_LOGIC_VECTOR (15 downto 0);
		datain   : in  STD_LOGIC_VECTOR (7 downto 0);            
		dataout  : out STD_LOGIC_VECTOR (7 downto 0); 
		wr_rd : in  STD_LOGIC;
		Memstrobe : in  STD_LOGIC
    );
end SDRAM_Controller;

architecture Behavioral of SDRAM_Controller is
    type ramemory is array (7 downto 0, 31 downto 0) of std_logic_vector(7 downto 0);
    signal sdram_mem : ramemory := (others => (others => (others => '0')));
begin
    process (clk)
        variable block_index : integer range 0 to 7;
        variable word_index  : integer range 0 to 31;
    begin
        if rising_edge(clk) then
            block_index := to_integer(unsigned(addr(7 downto 5)));
            word_index  := to_integer(unsigned(addr(4 downto 0)));

            if Memstrobe = '1' then
                if wr_rd = '1' then
                    sdram_mem(block_index, word_index) <= datain;
                else
                    dataout <= sdram_mem(block_index, word_index);
                end if;
            end if;
            
        end if;
    end process;

end Behavioral;
