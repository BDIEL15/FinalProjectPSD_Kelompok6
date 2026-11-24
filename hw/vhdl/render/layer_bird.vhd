-- layer_bird.vhd -- sprite burung 32x32 (data 16x16 di ROM, skala 2x).
-- Aturan = tools/ref_render.py langkah 2: indeks 0 transparan; flash membuat
-- semua piksel tidak transparan memakai indeks PAL_EYE (putih).
-- ROM kecil (1024 x 4 bit) disintesis sebagai LUT, dibaca kombinasional.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;
use work.assets_pkg.all;

entity layer_bird is
    port (
        x       : in  unsigned(11 downto 0);
        y       : in  unsigned(11 downto 0);
        bx      : in  unsigned(9 downto 0);
        by      : in  unsigned(9 downto 0);
        frame   : in  unsigned(1 downto 0);
        visible : in  std_logic;
        flash   : in  std_logic;
        hit     : out std_logic;
        idx     : out unsigned(3 downto 0)
    );
end entity;

architecture rtl of layer_bird is
begin
    process (all)
        variable dx, dy : unsigned(11 downto 0);
        variable addr : unsigned(9 downto 0);
        variable v : unsigned(3 downto 0);
    begin
        hit <= '0';
        idx <= (others => '0');
        if visible = '1' and x >= bx and x < resize(bx, 12) + BIRD_SIZE
                and y >= by and y < resize(by, 12) + BIRD_SIZE then
            dx := x - bx;
            dy := y - by;
            addr := frame & dy(4 downto 1) & dx(4 downto 1);   -- frame*256 + baris*16 + kolom
            v := BIRD_ROM(to_integer(addr));
            if v /= 0 then
                hit <= '1';
                if flash = '1' then
                    idx <= to_unsigned(PAL_EYE, 4);
                else
                    idx <= v;
                end if;
            end if;
        end if;
    end process;
end architecture;
