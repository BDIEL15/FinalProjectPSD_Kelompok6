-- layer_text.vhd -- skor 4 digit BCD + angka hitung mundur, dengan bayangan.
-- Aturan = tools/ref_render.py langkah 1:
--   skor   : tampil bila TEXT_ID = 0 atau 5; n digit bermakna, rata tengah,
--            x0 = 320 - 8n, y0 = SCORE_Y, skala 2x (16x32 per digit)
--   hitung : COUNTDOWN /= 0, satu digit di (COUNT_X, COUNT_Y), skala 4x
--   lit di (x, y) -> PAL_TEXT; tidak lit tapi lit di (x-2, y-2) -> bayangan
-- Teks status berupa huruf (TEXT_ID 1..6) belum ada (tahap 5).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;
use work.assets_pkg.all;

entity layer_text is
    port (
        x         : in  unsigned(11 downto 0);
        y         : in  unsigned(11 downto 0);
        score_bcd : in  std_logic_vector(15 downto 0);
        text_id   : in  unsigned(3 downto 0);
        countdown : in  unsigned(3 downto 0);
        hit       : out std_logic;
        idx       : out unsigned(3 downto 0)
    );
end entity;

architecture rtl of layer_text is
    function font_bit(digit, col, row : natural) return boolean is
    begin
        return FONT_ROM(digit * 16 + row)(col) = '1';
    end function;

    function lit(xi, yi : integer; bcd : std_logic_vector(15 downto 0);
                 tid, cd : unsigned(3 downto 0)) return boolean is
        variable n, x0, cx, cy, k, digit : integer;
    begin
        if tid = 0 or tid = 5 then
            if bcd(15 downto 12) /= "0000" then n := 4;
            elsif bcd(11 downto 8) /= "0000" then n := 3;
            elsif bcd(7 downto 4) /= "0000" then n := 2;
            else n := 1;
            end if;
            x0 := 320 - 8 * n;
            cx := xi - x0;
            cy := yi - SCORE_Y;
            if cx >= 0 and cx < 16 * n and cy >= 0 and cy < 32 then
                k := cx / 16;
                case n - 1 - k is      -- pilih nibble tanpa slice berindeks variabel
                    when 3      => digit := to_integer(unsigned(bcd(15 downto 12)));
                    when 2      => digit := to_integer(unsigned(bcd(11 downto 8)));
                    when 1      => digit := to_integer(unsigned(bcd(7 downto 4)));
                    when others => digit := to_integer(unsigned(bcd(3 downto 0)));
                end case;
                if digit <= 9 and font_bit(digit, (cx mod 16) / 2, cy / 2) then
                    return true;
                end if;
            end if;
        end if;
        if cd /= 0 and cd <= 9 then
            cx := xi - COUNT_X;
            cy := yi - COUNT_Y;
            if cx >= 0 and cx < 32 and cy >= 0 and cy < 64 then
                if font_bit(to_integer(cd), cx / 4, cy / 4) then
                    return true;
                end if;
            end if;
        end if;
        return false;
    end function;
begin
    process (all)
        variable xi, yi : integer;
    begin
        xi := to_integer(x);
        yi := to_integer(y);
        hit <= '0';
        idx <= to_unsigned(PAL_TEXT, 4);
        if lit(xi, yi, score_bcd, text_id, countdown) then
            hit <= '1';
        elsif lit(xi - TEXT_SHADOW, yi - TEXT_SHADOW, score_bcd, text_id, countdown) then
            hit <= '1';
            idx <= to_unsigned(PAL_TEXT_SHADOW, 4);
        end if;
    end process;
end architecture;
