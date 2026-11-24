-- top_render_test.vhd -- renderer game di monitor TANPA ARM (milestone B).
-- Register diisi oleh logika kecil di sini (bukan oleh game C), diperbarui
-- hanya saat vblank seperti aturan register asli:
--   pipa 0 bergeser ke kiri lalu muncul lagi di kanan, skor +1 tiap putaran,
--   lantai bergulir, sayap burung mengepak, burung naik-turun pelan.
--   sw(0) = flash burung, sw(1) = palet malam, sw(2) = tampilkan hitung mundur
--   btn(0) = reset; led(0) MMCM terkunci, led(1) HPD, led(2) kedip ~1 Hz
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;
use work.assets_pkg.all;

entity top_render_test is
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

architecture rtl of top_render_test is
    signal pix_clk, ser_clk, locked, rst : std_logic;
    signal sw_s1, sw_s2 : std_logic_vector(3 downto 0) := (others => '0');
    signal x, y : unsigned(11 downto 0);
    signal de, hs, vs, vblank, vblank_start : std_logic;
    signal regs : gfx_regs_t := GFX_REGS_RESET;
    signal rgb : std_logic_vector(23 downto 0);
    signal de_o, hs_o, vs_o : std_logic;

    signal frame_cnt : unsigned(15 downto 0) := (others => '0');
    signal anim_div  : unsigned(2 downto 0) := (others => '0');   -- 0..5
    signal wing      : unsigned(1 downto 0) := (others => '0');
    signal pipe_pos  : unsigned(9 downto 0) := (others => '0');   -- 0..707
    signal score     : std_logic_vector(15 downto 0) := (others => '0');

    -- tambah 1 pada angka BCD 4 digit (berhenti di 9999)
    function bcd_inc(v : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(15 downto 0) := v;
    begin
        if v = x"9999" then return v; end if;
        for i in 0 to 3 loop
            if r(4 * i + 3 downto 4 * i) = "1001" then
                r(4 * i + 3 downto 4 * i) := "0000";
            else
                r(4 * i + 3 downto 4 * i) := std_logic_vector(unsigned(r(4 * i + 3 downto 4 * i)) + 1);
                exit;
            end if;
        end loop;
        return r;
    end function;

    function pipe(xp : integer; gap : natural) return pipe_t is
    begin
        return (x => to_signed(xp, 11), gap_y => to_unsigned(gap, 9), visible => '1');
    end function;
begin
    clk_i : entity work.clocking
        port map (sysclk => sysclk, rst_in => btn(0), pix_clk => pix_clk,
                  ser_clk => ser_clk, locked => locked, pix_rst => rst);

    process (pix_clk)
    begin
        if rising_edge(pix_clk) then
            sw_s1 <= sw;
            sw_s2 <= sw_s1;
        end if;
    end process;

    timing : entity work.video_timing
        port map (clk => pix_clk, rst => rst, x => x, y => y, de => de, hsync => hs,
                  vsync => vs, vblank => vblank, vblank_start => vblank_start);

    -- "game" mini: semua register diperbarui hanya di awal vblank
    process (pix_clk)
        variable r : gfx_regs_t;
        variable bob : integer;
    begin
        if rising_edge(pix_clk) then
            if rst = '1' then
                frame_cnt <= (others => '0');
                anim_div <= (others => '0');
                wing <= (others => '0');
                pipe_pos <= (others => '0');
                score <= (others => '0');
                regs <= GFX_REGS_RESET;
            elsif vblank_start = '1' then
                frame_cnt <= frame_cnt + 1;
                if anim_div = 5 then
                    anim_div <= (others => '0');
                    wing <= wing + 1;
                else
                    anim_div <= anim_div + 1;
                end if;
                if pipe_pos = 707 then
                    pipe_pos <= (others => '0');
                    score <= bcd_inc(score);
                else
                    pipe_pos <= pipe_pos + 1;
                end if;

                r := GFX_REGS_RESET;
                r.enable := '1';
                r.test_pattern := '0';
                -- burung naik-turun pola segitiga 32 px dengan periode 128 frame
                if frame_cnt(6) = '0' then
                    bob := to_integer(frame_cnt(5 downto 1));
                else
                    bob := 31 - to_integer(frame_cnt(5 downto 1));
                end if;
                r.bird_x := to_unsigned(160, 10);
                r.bird_y := to_unsigned(170 + bob, 10);
                r.bird_frame := wing;
                r.bird_visible := '1';
                r.bird_flash := sw_s2(0);
                r.pipes(0) := pipe(639 - to_integer(pipe_pos), 120);
                r.pipes(1) := pipe(430, 80);
                r.pipes(2) := pipe(-30, 150);
                r.pipes(3) := pipe(0, 0);
                r.pipes(3).visible := '0';
                r.gap_h := to_unsigned(170, 9);
                r.pipe_width := to_unsigned(64, 7);
                r.scroll_x := frame_cnt(9 downto 0);
                r.score_bcd := score;
                r.text_id := (others => '0');
                if sw_s2(2) = '1' then
                    r.countdown := to_unsigned(3, 4);
                end if;
                r.palette := DEFAULT_PALETTE;
                if sw_s2(1) = '1' then
                    r.palette(PAL_SKY_BASE) := x"101848";
                end if;
                regs <= r;
            end if;
        end if;
    end process;

    render : entity work.renderer
        port map (clk => pix_clk, rst => rst, x => x, y => y, de => de, hsync => hs, vsync => vs,
                  regs => regs, rgb => rgb, de_o => de_o, hsync_o => hs_o, vsync_o => vs_o);

    tx : entity work.dvi_tx
        port map (pix_clk => pix_clk, ser_clk => ser_clk, rst => rst, rgb => rgb,
                  de => de_o, hsync => hs_o, vsync => vs_o,
                  tmds_clk_p => hdmi_tx_clk_p, tmds_clk_n => hdmi_tx_clk_n,
                  tmds_p => hdmi_tx_p, tmds_n => hdmi_tx_n);

    led(0) <= locked;
    led(1) <= hdmi_tx_hpd;
    led(2) <= frame_cnt(5);
    led(3) <= '0';
end architecture;
