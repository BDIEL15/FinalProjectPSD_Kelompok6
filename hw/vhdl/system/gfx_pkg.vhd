-- gfx_pkg.vhd -- tipe dan konstanta bersama akselerator grafis Jump-to-Flap.
--
-- DRAF v1 (belum dikompilasi: GHDL/Vivado belum terpasang saat ditulis).
-- Pemilik: D. Disetujui: E. Sumber kebenaran register map:
-- docs/tugas/README.md §3.1, sama dengan sw/game/regs.h dan tools/ref_render.py.
--
-- gfx_regs_t berisi register AKTIF (sudah di-latch saat vblank setelah commit),
-- sudah dipecah per field. gfx_axi_regs (D) mengisinya, renderer (E) membacanya.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gfx_pkg is
    -- Konstanta layar (sama dengan sw/game/game.h dan tools/game_model.py)
    constant SCREEN_W       : natural := 640;
    constant SCREEN_H       : natural := 480;
    constant GROUND_Y       : natural := 416;
    constant BIRD_SIZE      : natural := 32;
    constant PIPE_SLOTS     : natural := 4;
    constant PIPE_CAP_H     : natural := 20;
    constant PIPE_CAP_EXTRA : natural := 4;
    constant RENDER_LATENCY : natural := 2;   -- siklus, x/y/de -> rgb

    -- Offset register (byte)
    constant REG_CTRL        : natural := 16#00#;
    constant REG_STATUS      : natural := 16#04#;
    constant REG_BIRD_POS    : natural := 16#08#;
    constant REG_BIRD_ATTR   : natural := 16#0C#;
    constant REG_PIPE0       : natural := 16#10#;   -- PIPE(i) = REG_PIPE0 + 4*i
    constant REG_PIPE_CFG    : natural := 16#20#;
    constant REG_SCROLL_X    : natural := 16#24#;
    constant REG_SCORE       : natural := 16#28#;
    constant REG_TEXT_ID     : natural := 16#2C#;
    constant REG_COUNTDOWN   : natural := 16#30#;
    constant REG_IRQ         : natural := 16#34#;
    constant REG_SFX_TRIGGER : natural := 16#38#;
    constant REG_AUDIO_CTRL  : natural := 16#3C#;
    constant REG_PALETTE0    : natural := 16#40#;   -- PALETTE(i) = REG_PALETTE0 + 4*i

    -- Indeks palet default (lihat tools/ref_render.py)
    constant PAL_TRANSPARENT : natural := 0;
    constant PAL_SKY_BASE    : natural := 14;

    subtype rgb_t is std_logic_vector(23 downto 0);
    type palette_t is array (0 to 15) of rgb_t;

    type pipe_t is record
        x       : signed(10 downto 0);     -- tepi kiri batang, boleh negatif
        gap_y   : unsigned(8 downto 0);    -- tepi atas celah
        visible : std_logic;
    end record;
    type pipe_array_t is array (0 to PIPE_SLOTS - 1) of pipe_t;

    type gfx_regs_t is record
        enable       : std_logic;
        test_pattern : std_logic;
        bird_x       : unsigned(9 downto 0);
        bird_y       : unsigned(9 downto 0);
        bird_frame   : unsigned(1 downto 0);
        bird_visible : std_logic;
        bird_flash   : std_logic;
        pipes        : pipe_array_t;
        gap_h        : unsigned(8 downto 0);
        pipe_width   : unsigned(6 downto 0);
        scroll_x     : unsigned(9 downto 0);
        score_bcd    : std_logic_vector(15 downto 0);
        text_id      : unsigned(3 downto 0);
        countdown    : unsigned(3 downto 0);
        palette      : palette_t;
    end record;

    constant PIPE_RESET : pipe_t := (x => (others => '0'), gap_y => (others => '0'), visible => '0');

    constant GFX_REGS_RESET : gfx_regs_t := (
        enable       => '0',
        test_pattern => '1',
        bird_x       => (others => '0'),
        bird_y       => (others => '0'),
        bird_frame   => (others => '0'),
        bird_visible => '0',
        bird_flash   => '0',
        pipes        => (others => PIPE_RESET),
        gap_h        => (others => '0'),
        pipe_width   => (others => '0'),
        scroll_x     => (others => '0'),
        score_bcd    => (others => '0'),
        text_id      => (others => '0'),
        countdown    => (others => '0'),
        palette      => (others => (others => '0')));
end package;
