-- dvi_tx.vhd -- pemancar DVI/HDMI (video saja) buatan sendiri.
--   kanal 0 = biru (+ hsync/vsync sebagai kode kontrol), 1 = hijau, 2 = merah
--   tiap kanal: tmds_encoder -> OSERDESE2 master/slave 10:1 DDR -> OBUFDS
--   kanal clock: pola 1111100000 (= pix_clk) lewat serializer yang sama,
--   sehingga fase clock dan data selalu sejajar.
-- Butuh ser_clk = 5 x pix_clk dari MMCM yang sama (lihat clocking.vhd).
-- Cadangan bila monitor menolak: ganti modul ini dengan rgb2dvi Digilent.
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity dvi_tx is
    port (
        pix_clk  : in  std_logic;
        ser_clk  : in  std_logic;
        rst      : in  std_logic;
        rgb      : in  std_logic_vector(23 downto 0);   -- R[23:16] G[15:8] B[7:0]
        de       : in  std_logic;
        hsync    : in  std_logic;
        vsync    : in  std_logic;
        tmds_clk_p : out std_logic;
        tmds_clk_n : out std_logic;
        tmds_p   : out std_logic_vector(2 downto 0);
        tmds_n   : out std_logic_vector(2 downto 0)
    );
end entity;

architecture rtl of dvi_tx is
    type word_array is array (0 to 3) of std_logic_vector(9 downto 0);
    signal words : word_array;
    signal ser   : std_logic_vector(3 downto 0);
    signal sync  : std_logic_vector(1 downto 0);
begin
    sync <= vsync & hsync;

    enc_b : entity work.tmds_encoder
        port map (clk => pix_clk, rst => rst, de => de, c => sync, d => rgb(7 downto 0), q => words(0));
    enc_g : entity work.tmds_encoder
        port map (clk => pix_clk, rst => rst, de => de, c => "00", d => rgb(15 downto 8), q => words(1));
    enc_r : entity work.tmds_encoder
        port map (clk => pix_clk, rst => rst, de => de, c => "00", d => rgb(23 downto 16), q => words(2));
    words(3) <= "0000011111";   -- clock: bit 0..4 = 1, bit 5..9 = 0

    gen_ch : for i in 0 to 3 generate
        signal shift1, shift2 : std_logic;
    begin
        master : OSERDESE2
            generic map (
                DATA_RATE_OQ   => "DDR",
                DATA_RATE_TQ   => "SDR",
                DATA_WIDTH     => 10,
                SERDES_MODE    => "MASTER",
                TRISTATE_WIDTH => 1
            )
            port map (
                OQ       => ser(i),
                OFB      => open,
                TQ       => open,
                TFB      => open,
                SHIFTOUT1 => open,
                SHIFTOUT2 => open,
                TBYTEOUT => open,
                CLK      => ser_clk,
                CLKDIV   => pix_clk,
                D1 => words(i)(0), D2 => words(i)(1), D3 => words(i)(2), D4 => words(i)(3),
                D5 => words(i)(4), D6 => words(i)(5), D7 => words(i)(6), D8 => words(i)(7),
                OCE      => '1',
                RST      => rst,
                SHIFTIN1 => shift1,
                SHIFTIN2 => shift2,
                T1 => '0', T2 => '0', T3 => '0', T4 => '0',
                TBYTEIN  => '0',
                TCE      => '0'
            );
        slave : OSERDESE2
            generic map (
                DATA_RATE_OQ   => "DDR",
                DATA_RATE_TQ   => "SDR",
                DATA_WIDTH     => 10,
                SERDES_MODE    => "SLAVE",
                TRISTATE_WIDTH => 1
            )
            port map (
                OQ       => open,
                OFB      => open,
                TQ       => open,
                TFB      => open,
                SHIFTOUT1 => shift1,
                SHIFTOUT2 => shift2,
                TBYTEOUT => open,
                CLK      => ser_clk,
                CLKDIV   => pix_clk,
                D1 => '0', D2 => '0', D3 => words(i)(8), D4 => words(i)(9),
                D5 => '0', D6 => '0', D7 => '0', D8 => '0',
                OCE      => '1',
                RST      => rst,
                SHIFTIN1 => '0',
                SHIFTIN2 => '0',
                T1 => '0', T2 => '0', T3 => '0', T4 => '0',
                TBYTEIN  => '0',
                TCE      => '0'
            );
    end generate;

    gen_data_buf : for i in 0 to 2 generate
        obuf : OBUFDS port map (I => ser(i), O => tmds_p(i), OB => tmds_n(i));
    end generate;
    obuf_clk : OBUFDS port map (I => ser(3), O => tmds_clk_p, OB => tmds_clk_n);
end architecture;
