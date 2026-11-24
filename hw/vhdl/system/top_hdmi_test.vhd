-- top_hdmi_test.vhd -- uji HDMI Zybo Z7 tanpa PS (milestone A).
--   sysclk 125 MHz -> clocking -> video_timing -> test_pattern -> dvi_tx -> HDMI TX
--   sw(1:0)  pilih pola (0 bar warna, 1 grid, 2 kotak memantul)
--   btn(0)   reset
--   led(0)   MMCM terkunci
--   led(1)   HPD: monitor terdeteksi
--   led(2)   berkedip ~1 Hz (bukti frame berjalan)
-- Tidak butuh IP apa pun: cukup file VHDL ini + hw/constr/zybo_z7_hdmi.xdc.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_hdmi_test is
    port (
        sysclk        : in  std_logic;
        sw            : in  std_logic_vector(3 downto 0);
        btn           : in  std_logic_vector(3 downto 0);
        led           : out std_logic_vector(3 downto 0);
        hdmi_tx_hpd   : in  std_logic;
        hdmi_tx_clk_p : out std_logic;
        hdmi_tx_clk_n : out std_logic;
        hdmi_tx_p     : out std_logic_vector(2 downto 0);
        hdmi_tx_n     : out std_logic_vector(2 downto 0)
    );
end entity;

architecture rtl of top_hdmi_test is
    signal pix_clk, ser_clk, locked, rst : std_logic;
    signal mode_s1, mode_s2 : std_logic_vector(1 downto 0) := "00";
    signal x, y : unsigned(11 downto 0);
    signal de, hs, vs, vblank, vblank_start : std_logic;
    signal rgb : std_logic_vector(23 downto 0);
    signal de_o, hs_o, vs_o : std_logic;
    signal frame_cnt : unsigned(5 downto 0) := (others => '0');
begin
    clk_i : entity work.clocking
        port map (sysclk => sysclk, rst_in => btn(0), pix_clk => pix_clk,
                  ser_clk => ser_clk, locked => locked, pix_rst => rst);

    -- sinkronisasi switch ke domain piksel
    process (pix_clk)
    begin
        if rising_edge(pix_clk) then
            mode_s1 <= sw(1 downto 0);
            mode_s2 <= mode_s1;
        end if;
    end process;

    timing : entity work.video_timing
        port map (clk => pix_clk, rst => rst, x => x, y => y, de => de, hsync => hs,
                  vsync => vs, vblank => vblank, vblank_start => vblank_start);

    pattern : entity work.test_pattern
        port map (clk => pix_clk, rst => rst, mode => mode_s2, x => x, y => y, de => de,
                  hsync => hs, vsync => vs, vblank_start => vblank_start,
                  rgb => rgb, de_o => de_o, hsync_o => hs_o, vsync_o => vs_o);

    tx : entity work.dvi_tx
        port map (pix_clk => pix_clk, ser_clk => ser_clk, rst => rst, rgb => rgb,
                  de => de_o, hsync => hs_o, vsync => vs_o,
                  tmds_clk_p => hdmi_tx_clk_p, tmds_clk_n => hdmi_tx_clk_n,
                  tmds_p => hdmi_tx_p, tmds_n => hdmi_tx_n);

    process (pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst = '1' then
                frame_cnt <= (others => '0');
            elsif vblank_start = '1' then
                frame_cnt <= frame_cnt + 1;
            end if;
        end if;
    end process;

    led(0) <= locked;
    led(1) <= hdmi_tx_hpd;
    led(2) <= frame_cnt(5);      -- 59,5 frame/s / 64 -> ~0,93 Hz
    led(3) <= '0';
end architecture;
