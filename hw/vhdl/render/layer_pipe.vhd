-- layer_pipe.vhd -- 4 pipa procedural (kombinasional), tanpa memori gambar.
-- Aturan = tools/ref_render.py langkah 4. PIPE3 diperiksa dulu (yang pertama
-- kena menang), sama dengan urutan gambar model Python.
--   tutup : px-4 <= x < px+w+4, gap-20 <= y < gap atau gap+gh <= y < gap+gh+20
--   batang: px <= x < px+w, y < gap atau gap+gh <= y < 416
--   tepi 2 px tiap kotak -> gelap; px+6 <= x < px+14 -> terang; lainnya badan
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;
use work.assets_pkg.all;

entity layer_pipe is
    port (
        x     : in  unsigned(11 downto 0);
        y     : in  unsigned(11 downto 0);
        pipes : in  pipe_array_t;
        gap_h : in  unsigned(8 downto 0);
        width : in  unsigned(6 downto 0);
        hit   : out std_logic;
        idx   : out unsigned(3 downto 0)
    );
end entity;

architecture rtl of layer_pipe is
    -- (xi, yi) di tepi 2 px kotak [x0, x1) x [y0, y1)
    function in_border(xi, yi, x0, y0, x1, y1 : integer) return boolean is
    begin
        return xi < x0 + 2 or xi >= x1 - 2 or yi < y0 + 2 or yi >= y1 - 2;
    end function;
begin
    process (all)
        variable xi, yi, px, gap, gh, w, cy : integer;
        variable found : boolean;
        variable res : natural range 0 to 15;
    begin
        xi := to_integer(x);
        yi := to_integer(y);
        gh := to_integer(gap_h);
        w  := to_integer(width);
        found := false;
        res := PAL_PIPE;
        for i in PIPE_SLOTS - 1 downto 0 loop
            px  := to_integer(pipes(i).x);
            gap := to_integer(pipes(i).gap_y);
            if not found and pipes(i).visible = '1' then
                -- tutup atas lalu bawah
                if xi >= px - 4 and xi < px + w + 4 then
                    for k in 0 to 1 loop
                        if k = 0 then cy := gap - 20; else cy := gap + gh; end if;
                        if not found and yi >= cy and yi < cy + 20 then
                            found := true;
                            if in_border(xi, yi, px - 4, cy, px + w + 4, cy + 20) then
                                res := PAL_PIPE_DARK;
                            else
                                res := PAL_PIPE;
                            end if;
                        end if;
                    end loop;
                end if;
                -- batang atas [0, gap) dan bawah [gap+gh, 416)
                if not found and xi >= px and xi < px + w then
                    if yi < gap then
                        found := true;
                        if in_border(xi, yi, px, 0, px + w, gap) then
                            res := PAL_PIPE_DARK;
                        elsif xi >= px + 6 and xi < px + 14 then
                            res := PAL_PIPE_LIGHT;
                        else
                            res := PAL_PIPE;
                        end if;
                    elsif yi >= gap + gh and yi < GROUND_Y then
                        found := true;
                        if in_border(xi, yi, px, gap + gh, px + w, GROUND_Y) then
                            res := PAL_PIPE_DARK;
                        elsif xi >= px + 6 and xi < px + 14 then
                            res := PAL_PIPE_LIGHT;
                        else
                            res := PAL_PIPE;
                        end if;
                    end if;
                end if;
            end if;
        end loop;
        hit <= '1' when found else '0';
        idx <= to_unsigned(res, 4);
    end process;
end architecture;
