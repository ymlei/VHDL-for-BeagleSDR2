library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
--use work.spiDataTx;
--use work.adf4350_calc;

entity pq208 is
port(
--	indata : in std_logic_vector(13 downto 0);
	clk : in std_logic;
--	rst : in std_logic;
	osc125_clk: in std_logic;
	wave : out std_logic_vector(0 to 13);
	DAC_CLK : out std_logic;
	DAC_SLEEP : out std_logic;
	DAC_MODE : out std_logic;
	
	LO_REFIN	:	out 	std_logic;
	LO_SCLK	:	out 	std_logic;
	LO_SI		:	inout 	std_logic;
	LO_LE		:	inout	std_logic;
--	LO_MUXOUT:	in	std_logic;
	LO_SW 	:	out	std_logic;
	LO_ENABLE :	out	std_logic
	);
end pq208;

architecture rtl of pq208 is
	

type sin_table is array(0 to 31) of integer range 0 to 16383;
signal count : std_logic_vector(4 downto 0);
signal clk_dac: std_logic;
signal f1,f2,f3 :std_logic;

--ADF4350
	-- adf4350 config
	signal config_freq: unsigned(15 downto 0);				-- configured sgen frequency (100kHz increments)
	signal lo_freq: unsigned(15 downto 0);
	signal lo_vco_freq, sgen_vco_freq: unsigned(15 downto 0);
	signal odiv: unsigned(5 downto 0);						-- rf divide factor
	
	signal pll1_R		: std_logic_vector(9 downto 0);
	signal pll1_mod	: std_logic_vector(11 downto 0);
	signal pll1_N		: std_logic_vector(15 downto 0);
	signal pll1_frac	: std_logic_vector(11 downto 0);
	signal pll1_O		: std_logic_vector(2 downto 0);
	--signal adf4350_clk,adf4350_le,adf4350_data: std_logic;
	signal pll_update_usbclk, pll_update1, pll_update2, pll_update3, pll_do_update: std_logic;

constant C_SIN_TABLE : sin_table :=(
	1280, 1530, 1770, 2000, 2190, 2350, 2470, 2540, 2550, 2540, 2470, 2350, 2190, 2000, 1770, 1530,
	1280, 1030, 790, 560, 370, 210, 90, 20, 00, 20, 90, 210, 370, 560, 790, 1030);
--	1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 
--	1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512, 1024, 512);
begin

	clk_dac <= osc125_clk ;		
	DAC_CLK <= clk_dac ; -- this clock commands the DAC
	DAC_SLEEP <= '0';
	DAC_MODE <= '0';

--ADF4350 map
	LO_REFIN	<= osc125_clk;
--	LO_SCLK <= osc125_clk;
--	LO_SI <= '1';
--	LO_LE <= '1';
--	LO_MUXOUT <= ;
	LO_SW <= '1';
	LO_ENABLE <= '1';


-- adf4350 spi
--	config_freq <= unsigned(cfg(0)) & unsigned(cfg(1));
--	lo_freq <= config_freq+7;
	lo_freq <= to_unsigned(22001, 16);
	
	
	calc1: entity adf4350_calc generic map(192) port map(clk_dac, lo_freq, pll1_N, pll1_frac, pll1_O);
	
	
--	pll1_O <= "000";
	pll1_R <= std_logic_vector(to_unsigned(1,10));
	pll1_mod <= std_logic_vector(to_unsigned(192,12));
	pll1_N <= std_logic_vector(to_unsigned(190,16));
	--pll1_N <= cfg(0) & cfg(1);
	pll1_frac <= std_logic_vector(to_unsigned(0,12));

--create pll_update for spiDataTx
	pll_update_usbclk <= not pll_update_usbclk when rising_edge(osc125_clk);
	pll_update1 <= pll_update_usbclk when rising_edge(osc125_clk);
	pll_update2 <= pll_update1 when rising_edge(osc125_clk);
	pll_update3 <= pll_update2 when rising_edge(osc125_clk);
	pll_do_update <= pll_update2 xor pll_update3 when rising_edge(osc125_clk);


--create serial data for LO_CLK, LO_LE, LO_SI

--	spi1: entity spiDataTx generic map(words=>6,wordsize=>32) port map(
--		"00000000010000000000000000000101" &
	--	 XXXXXXXXF    OOO   BBBBBBBBVMAAAAROO100
--		"000000001"&pll1_O&"11111111000111111100" &
--		"00000000000000000" & std_logic_vector(to_unsigned(80,12)) & "011" &
--		"01100100" & pll1_R & "01111101000010" &
--		"00001000000000001" & pll1_mod & "001" &
--		"0" & pll1_N & pll1_frac & "000",
--	osc125_clk,  pll_do_update, LO_SCLK, LO_LE, LO_SI);


---create simplified serial data for LO_CLK, LO_LE, LO_SI
	spi1: entity spiDataTx generic map(words=>6,wordsize=>32) port map(
		"00000000010000000000000000000101" &
		"00000000010000000000000000000101" &
		"00000000010000000000000000000101" &
		"00000000010000000000000000000101" &
		"00000000010000000000000000000101" &
		"00000000010000000000000000000101",
		osc125_clk,  clk, LO_SCLK, LO_LE, LO_SI);

--Use this for test error pack1107 : pin site type
--error still

--	LO_SCLK <= osc125_clk;
--	LO_LE <= clk;
--	LO_SI <= clk;


--sin data to wave 14 bits output.
	process(osc125_clk)
	begin
		if rising_edge(osc125_clk) then
			wave <= std_logic_vector(to_unsigned(C_SIN_TABLE(to_integer(unsigned(count))),14));
		end if;
	end process;

--address for sin table
	process(osc125_clk, count)
	begin
		if rising_edge(osc125_clk) then
			if count = "11111" then
				count <= "00000";
			else
			count <= std_logic_vector(to_unsigned(to_integer(unsigned(count)) + 1, 5));
			end if;
		end if;
	end process;

end rtl;
