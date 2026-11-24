-- video_timing.vhd -- generator timing video (port 1:1 dari hw/rtl/video_timing.v).
-- Default 640x480 @ 60 Hz:
--   Horizontal: 640 aktif | 16 front porch | 96 sync | 48 back porch = 800
--   Vertikal  : 480 aktif | 10 front porch |  2 sync | 33 back porch = 525
-- Untuk 1280x720 @ 60 Hz: H 1280/110/40/220, V 720/5/5/20, SYNC_POL = '1'.
--
-- x, y langsung dari counter terdaftar. Modul yang menambah pipeline wajib
-- menunda de/hsync/vsync sebanyak siklus yang sama.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity video_timing is
    generic (
        H_ACTIVE : natural := 640;
        H_FP     : natural := 16;
        H_SYNC   : natural := 96;
        H_BP     : natural := 48;
        V_ACTIVE : natural := 480;
        V_FP     : natural := 10;
        V_SYNC   : natural := 2;
        V_BP     : natural := 33;
        SYNC_POL : std_logic := '0'      -- '0' = sync aktif rendah (640x480)
    );
    port (
        clk          : in  std_logic;    -- clock piksel
        rst          : in  std_logic;    -- reset sinkron, aktif tinggi
        x            : out unsigned(11 downto 0);
        y            : out unsigned(11 downto 0);
        de           : out std_logic;    -- '1' = piksel terlihat
        hsync        : out std_logic;
        vsync        : out std_logic;
        vblank       : out std_logic;    -- '1' = baris di luar area aktif
        vblank_start : out std_logic     -- pulsa 1 siklus di x=0, y=V_ACTIVE
    );
end entity;

architecture rtl of video_timing is
    constant H_TOTAL : natural := H_ACTIVE + H_FP + H_SYNC + H_BP;
    constant V_TOTAL : natural := V_ACTIVE + V_FP + V_SYNC + V_BP;
    signal hcnt : unsigned(11 downto 0) := (others => '0');
    signal vcnt : unsigned(11 downto 0) := (others => '0');
    signal hs_active, vs_active : std_logic;
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                hcnt <= (others => '0');
                vcnt <= (others => '0');
            elsif hcnt = H_TOTAL - 1 then
                hcnt <= (others => '0');
                if vcnt = V_TOTAL - 1 then
                    vcnt <= (others => '0');
                else
                    vcnt <= vcnt + 1;
                end if;
            else
                hcnt <= hcnt + 1;
            end if;
        end if;
    end process;

    hs_active <= '1' when hcnt >= H_ACTIVE + H_FP and hcnt < H_ACTIVE + H_FP + H_SYNC else '0';
    vs_active <= '1' when vcnt >= V_ACTIVE + V_FP and vcnt < V_ACTIVE + V_FP + V_SYNC else '0';

    x            <= hcnt;
    y            <= vcnt;
    de           <= '1' when hcnt < H_ACTIVE and vcnt < V_ACTIVE else '0';
    hsync        <= hs_active when SYNC_POL = '1' else not hs_active;
    vsync        <= vs_active when SYNC_POL = '1' else not vs_active;
    vblank       <= '1' when vcnt >= V_ACTIVE else '0';
    vblank_start <= '1' when hcnt = 0 and vcnt = V_ACTIVE else '0';
end architecture;
