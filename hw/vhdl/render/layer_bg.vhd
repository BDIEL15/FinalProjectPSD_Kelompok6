-- layer_bg.vhd -- lantai bergulir (kombinasional). Langit dihitung di renderer
-- (perlu nilai RGB, bukan indeks palet). Aturan = tools/ref_render.py langkah 3:
--   y >= 416: y-416 < 8 -> rumput; selain itu bit 4 dari
--             (x + (SCROLL_X & 31) + (y-416)) memilih lantai A / B
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;
use work.assets_pkg.all;

entity layer_bg is
    port (
        x      : in  unsigned(11 downto 0);
        y      : in  unsigned(11 downto 0);
        scroll : in  unsigned(9 downto 0);
        hit    : out std_logic;              -- '1' = piksel lantai
        idx    : out unsigned(3 downto 0)
    );
end entity;

architecture rtl of layer_bg is
begin
    process (all)
        variable gy  : unsigned(11 downto 0);
        variable sum : unsigned(11 downto 0);
    begin
        hit <= '0';
        idx <= to_unsigned(PAL_GROUND_TOP, 4);
        if y >= GROUND_Y then
            hit <= '1';
            gy := y - GROUND_Y;
            if gy < 8 then
                idx <= to_unsigned(PAL_GROUND_TOP, 4);
            else
                sum := x + resize(scroll(4 downto 0), 12) + gy;
                if sum(4) = '1' then
                    idx <= to_unsigned(PAL_GROUND_B, 4);
                else
                    idx <= to_unsigned(PAL_GROUND_A, 4);
                end if;
            end if;
        end if;
    end process;
end architecture;
