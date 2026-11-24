-- clocking.vhd -- clock piksel + clock serial dari osilator 125 MHz Zybo Z7.
--   VCO = 125 MHz x 8 = 1000 MHz (rentang VCO MMCM 7-series: 600..1200 MHz)
--   pix_clk = 1000 / 40 = 25,0 MHz   (640x480 @ 59,5 Hz, diterima monitor umum)
--   ser_clk = 1000 /  8 = 125 MHz    (5x pix_clk, untuk OSERDESE2 10:1 DDR)
-- Primitif Xilinx langsung (tanpa IP Clocking Wizard), jadi tidak bergantung
-- versi IP. rst keluar '1' sampai MMCM terkunci + 4 siklus.
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clocking is
    port (
        sysclk  : in  std_logic;    -- 125 MHz dari pin K17
        rst_in  : in  std_logic;    -- reset asinkron, aktif tinggi (mis. tombol)
        pix_clk : out std_logic;
        ser_clk : out std_logic;
        locked  : out std_logic;
        pix_rst : out std_logic     -- reset sinkron domain pix_clk
    );
end entity;

architecture rtl of clocking is
    signal clkfb, clk0_u, clk1_u, pix_i : std_logic;
    signal locked_i : std_logic;
    signal rst_sr : std_logic_vector(3 downto 0) := (others => '1');
begin
    mmcm : MMCME2_BASE
        generic map (
            BANDWIDTH        => "OPTIMIZED",
            CLKIN1_PERIOD    => 8.0,
            DIVCLK_DIVIDE    => 1,
            CLKFBOUT_MULT_F  => 8.0,
            CLKOUT0_DIVIDE_F => 40.0,
            CLKOUT1_DIVIDE   => 8,
            STARTUP_WAIT     => FALSE
        )
        port map (
            CLKIN1   => sysclk,
            CLKFBIN  => clkfb,
            CLKFBOUT => clkfb,
            CLKOUT0  => clk0_u,
            CLKOUT1  => clk1_u,
            LOCKED   => locked_i,
            PWRDWN   => '0',
            RST      => rst_in
        );

    bufg_pix : BUFG port map (I => clk0_u, O => pix_i);
    bufg_ser : BUFG port map (I => clk1_u, O => ser_clk);
    pix_clk <= pix_i;
    locked  <= locked_i;

    process (pix_i, locked_i)
    begin
        if locked_i = '0' then
            rst_sr <= (others => '1');
        elsif rising_edge(pix_i) then
            rst_sr <= rst_sr(2 downto 0) & '0';
        end if;
    end process;
    pix_rst <= rst_sr(3);
end architecture;
