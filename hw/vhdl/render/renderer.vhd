-- renderer.vhd -- inti penggambar 2D: warna tiap piksel dihitung dari register
-- saat layar dipindai (tanpa framebuffer). Spesifikasi: tools/ref_render.py.
--
-- Pipeline tetap RENDER_LATENCY = 2 siklus (x/y/de masuk -> rgb keluar):
--   tahap 1: keempat layer (kombinasional) + mux prioritas -> indeks / langit
--            prioritas: teks > burung > lantai > pipa > langit
--   tahap 2: palet (indeks -> RGB) atau gradien langit
--            langit = PALETTE[14] + (2b, b + b/4, b/2), b = y/8, jenuh di 255
-- de/hsync/vsync ikut ditunda 2 siklus. rgb = 0 saat de = '0' atau enable = '0'.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;

entity renderer is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        x     : in  unsigned(11 downto 0);
        y     : in  unsigned(11 downto 0);
        de    : in  std_logic;
        hsync : in  std_logic;
        vsync : in  std_logic;
        regs  : in  gfx_regs_t;     -- register aktif, hanya berubah saat vblank
        rgb   : out std_logic_vector(23 downto 0);
        de_o    : out std_logic;
        hsync_o : out std_logic;
        vsync_o : out std_logic
    );
end entity;

architecture rtl of renderer is
    signal bg_hit, pipe_hit, bird_hit, text_hit : std_logic;
    signal bg_idx, pipe_idx, bird_idx, text_idx : unsigned(3 downto 0);
    -- tahap 1
    signal s1_idx  : unsigned(3 downto 0) := (others => '0');
    signal s1_sky  : std_logic := '0';
    signal s1_band : unsigned(5 downto 0) := (others => '0');
    signal s1_on   : std_logic := '0';
    signal s1_de, s1_hs, s1_vs : std_logic := '0';

    function sat_add(base : std_logic_vector(7 downto 0); add : natural) return std_logic_vector is
        variable s : natural;
    begin
        s := to_integer(unsigned(base)) + add;
        if s > 255 then s := 255; end if;
        return std_logic_vector(to_unsigned(s, 8));
    end function;
begin
    bg : entity work.layer_bg
        port map (x => x, y => y, scroll => regs.scroll_x, hit => bg_hit, idx => bg_idx);
    pipe : entity work.layer_pipe
        port map (x => x, y => y, pipes => regs.pipes, gap_h => regs.gap_h,
                  width => regs.pipe_width, hit => pipe_hit, idx => pipe_idx);
    bird : entity work.layer_bird
        port map (x => x, y => y, bx => regs.bird_x, by => regs.bird_y, frame => regs.bird_frame,
                  visible => regs.bird_visible, flash => regs.bird_flash,
                  hit => bird_hit, idx => bird_idx);
    text : entity work.layer_text
        port map (x => x, y => y, score_bcd => regs.score_bcd, text_id => regs.text_id,
                  countdown => regs.countdown, hit => text_hit, idx => text_idx);

    process (clk)
        variable band : natural;
        variable base : std_logic_vector(23 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                s1_de <= '0'; s1_hs <= '1'; s1_vs <= '1';
                de_o <= '0'; hsync_o <= '1'; vsync_o <= '1';
                rgb <= (others => '0');
                s1_on <= '0';
            else
                -- tahap 1: mux prioritas
                s1_sky <= '0';
                if text_hit = '1' then
                    s1_idx <= text_idx;
                elsif bird_hit = '1' then
                    s1_idx <= bird_idx;
                elsif bg_hit = '1' then
                    s1_idx <= bg_idx;
                elsif pipe_hit = '1' then
                    s1_idx <= pipe_idx;
                else
                    s1_idx <= (others => '0');
                    s1_sky <= '1';
                end if;
                s1_band <= y(8 downto 3);
                s1_on <= de and regs.enable;
                s1_de <= de; s1_hs <= hsync; s1_vs <= vsync;

                -- tahap 2: palet atau langit
                if s1_on = '0' then
                    rgb <= (others => '0');
                elsif s1_sky = '1' then
                    band := to_integer(s1_band);
                    base := regs.palette(PAL_SKY_BASE);
                    rgb <= sat_add(base(23 downto 16), 2 * band)
                         & sat_add(base(15 downto 8), band + band / 4)
                         & sat_add(base(7 downto 0), band / 2);
                else
                    rgb <= regs.palette(to_integer(s1_idx));
                end if;
                de_o <= s1_de; hsync_o <= s1_hs; vsync_o <= s1_vs;
            end if;
        end if;
    end process;
end architecture;
