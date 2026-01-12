----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Asif Choudhury & Christopher Zita
-- 
-- Create Date:    21:17:35 10/20/2025 
-- Design Name: 
-- Module Name:    TOP_Module - Behavioral 
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TOP_Module is
Port ( 
        clk : in  STD_LOGIC;
        led : out STD_LOGIC_VECTOR (7 downto 0);
        switches : in  STD_LOGIC_VECTOR (3 downto 0)
    );
end TOP_Module;

architecture Behavioral of TOP_Module is
	component icon
        PORT (
            CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0)
        );
    end component;
    
    component ila
        PORT (
            CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
            CLK : IN STD_LOGIC;
            DATA : IN STD_LOGIC_VECTOR(98 DOWNTO 0);
            TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    end component;
    
    signal control0 : std_logic_vector(35 downto 0);
    signal ila_data : std_logic_vector(98 downto 0);
    signal trig0    : std_logic_vector(7 downto 0);
	 
	 component CPU_gen
        Port (
            clk     : in  STD_LOGIC;
            rst     : in  STD_LOGIC;
            trig    : in  STD_LOGIC;
            Address : out STD_LOGIC_VECTOR (15 downto 0);
            wr_rd   : out STD_LOGIC;
            cs      : out STD_LOGIC;
            DOut    : out STD_LOGIC_VECTOR (7 downto 0)
        );
    end component;
	 
	 component Cache_Controller
        Port (
            clk         : in  STD_LOGIC;
            CPU_addr    : in  STD_LOGIC_VECTOR (15 downto 0);
            wr_rd       : in  STD_LOGIC;
            chipsel     : in  STD_LOGIC;
            cpu_RDY     : out STD_LOGIC;
            SDRAM_addr  : out STD_LOGIC_VECTOR (15 downto 0);
            SDRAM_wrRd 	: out STD_LOGIC;
            memstrobe   : out STD_LOGIC;
            SRAM_addr   : out STD_LOGIC_VECTOR (7 downto 0);
            SRAM_wEn    : out STD_LOGIC;
            dinSel     	: out STD_LOGIC;
            doutSel    	: out STD_LOGIC;
            currentState   : out STD_LOGIC_VECTOR(2 downto 0);
            valid       : out STD_LOGIC;
            dirty       : out STD_LOGIC;
            currentTag  : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;
	 
	 component cache_sram
        PORT (
				clka : IN STD_LOGIC;
				wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
				addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
        );
    end component;
	 
	 component SDRAM_Controller
        Port (
            clk   : in  STD_LOGIC;
            addr  : in  STD_LOGIC_VECTOR (15 downto 0);
            datain   : in  STD_LOGIC_VECTOR (7 downto 0);            
				dataout  : out STD_LOGIC_VECTOR (7 downto 0); 
            wr_rd : in  STD_LOGIC;
            Memstrobe : in  STD_LOGIC
        );
    end component;
	 
	 signal CPU_addr  : std_logic_vector(15 downto 0);
	 signal CPU_rdy   : std_logic;
	 signal CPU_wr_rd : std_logic;
	 signal CPU_din 	: std_logic_vector(7 downto 0);
    signal CPU_dout  : std_logic_vector(7 downto 0);
    signal CPU_cs    : std_logic;
    
    signal SRAM_addr : std_logic_vector(7 downto 0);
    signal SRAM_din  : std_logic_vector(7 downto 0);
    signal SRAM_dout : std_logic_vector(7 downto 0);
    signal SRAM_wen 	: std_logic;
    signal SRAM_wen_vec : std_logic_vector(0 downto 0);
    
    signal SDRAM_addr  : std_logic_vector(15 downto 0);
    signal SDRAM_din   : std_logic_vector(7 downto 0);
    signal SDRAM_dout  : std_logic_vector(7 downto 0);
    signal SDRAM_wr_rd : std_logic;
    signal MEMSTRB     : std_logic;
    
    signal data_in_sel  : std_logic;
    signal data_out_sel : std_logic;
    signal auto_trig : std_logic := '0';
    signal trig_count : std_logic_vector(27 downto 0) := (others => '0');
    signal current_state        : std_logic_vector(2 downto 0);
    signal valid_bit        : std_logic;
    signal dirty_bit        : std_logic;
    signal current_tag  : std_logic_vector(7 downto 0);
	 signal counter : std_logic_vector(29 downto 0);
	 
	 

begin
	sys_icon : icon
		port map (
		CONTROL0 => control0);
	 
	sys_ila : ila
		port map (
		 CONTROL => control0,
		 CLK => clk,
		 DATA => ila_data,
		 TRIG0 => trig0);
	
	process(clk)
		begin
        if rising_edge(clk) then
            if trig_count = X"0000100" then
                auto_trig <= '1';
                trig_count <= (others => '0');
            else
                auto_trig <= '0';
                trig_count <= trig_count + '1';
            end if;
        end if;
	end process;
	
	process(clk)
    begin
        if rising_edge(clk) then
            if switches(0) = '1' then
                counter <= counter + '1';
            else
                counter <= counter - '1';
            end if;
        end if;
    end process;
	 
	 CPU_gen_top : CPU_gen
        port map (
            clk     => clk,
            rst     => '0',
            trig    => auto_trig,
            Address => CPU_addr,
            wr_rd   => CPU_wr_rd,
            cs		  => CPU_cs,
            DOut    => CPU_dout
        );
    
    cache_controller_top : Cache_Controller
        port map (
            clk         => clk,
            CPU_addr    => CPU_addr,
            wr_rd       => CPU_wr_rd,
            chipsel     => CPU_cs,
            cpu_RDY	   => CPU_rdy,
            SDRAM_addr  => SDRAM_addr,
            SDRAM_wrRd => SDRAM_wr_rd,
            memstrobe       => MEMSTRB,
            SRAM_addr   => SRAM_addr,
            SRAM_wEn    => SRAM_wen,
            dinSel     => data_in_sel,
            doutSel    => data_out_sel,
            currentState       => current_state,
            valid       => valid_bit,
            dirty       => dirty_bit,
            currentTag => current_tag
        );
    
    SRAM_wen_vec(0) <= SRAM_wen;
    
    cache_sram_top : cache_sram
        port map (
            clka  => clk,
				wea   => SRAM_wen_vec,
            addra => SRAM_addr,
            dina  => SRAM_din,
            douta => SRAM_dout
        );
    
    sdram_controller_top : SDRAM_Controller
        port map (
            clk   => clk,
            addr  => SDRAM_addr,
            datain   => SDRAM_din,
            wr_rd => SDRAM_wr_rd,
            Memstrobe => MEMSTRB,
            dataout  => SDRAM_dout
        );
    
	 SRAM_din  <= CPU_dout when data_in_sel = '0' else SDRAM_dout;
	 SDRAM_din <= SRAM_dout when data_out_sel = '0' else (others => '0');
	 CPU_din   <= SRAM_dout when data_out_sel = '1' else (others => '0');
    
    -- ILA data signals
    ila_data(0)  <= CPU_cs;
    ila_data(1)  <= CPU_rdy;
    ila_data(2)  <= CPU_wr_rd;
    ila_data(3)  <= MEMSTRB;
    ila_data(4)  <= SRAM_wen;
    ila_data(5)  <= data_in_sel;
    ila_data(6)  <= data_out_sel;
    ila_data(7)  <= SDRAM_wr_rd;
    ila_data(23 downto 8)  <= CPU_addr;             
    ila_data(31 downto 24) <= SRAM_dout;
    ila_data(39 downto 32) <= SDRAM_dout;
    ila_data(42 downto 40) <= current_state;
    ila_data(43) <= valid_bit;
    ila_data(44) <= dirty_bit;
    ila_data(52 downto 45) <= current_tag;
	 ila_data(68 downto 53) <= SDRAM_addr;
	 ila_data (76 downto 69) <= SRAM_addr;
	 ila_data (84 downto 77) <= CPU_din;
    ila_data(98 downto 85) <= (others => '0');

    -- ILA triggers
    trig0(0) <= CPU_cs;
    trig0(1) <= CPU_rdy;
    trig0(2) <= valid_bit;
    trig0(3) <= dirty_bit;
    trig0(7 downto 4) <= (others => '0');

end Behavioral;

