-- test_pattern.vhd -- pola uji jalur HDMI (port 1:1 dari hw/rtl/test_pattern.v).
--   mode 0: 8 bar warna (putih, kuning, cyan, hijau, magenta, merah, biru, hitam)
--   mode 1: grid 32 px putih di atas biru tua + bingkai merah 1 px di tepi layar
--   mode 2: kotak kuning 32x32 memantul di atas gradien abu-abu, posisi
--           diperbarui SAAT VBLANK (pola yang sama dipakai renderer game)
-- Latensi pipeline 1 siklus; de/hsync/vsync ikut ditunda 1 siklus.
-- Rumus harus sama persis dengan tools/ref_test_pattern.py.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_pattern is
    generic (
        H_ACTIVE : natural := 640;
        V_ACTIVE : natural := 480;
        BOX      : natural := 32;
        BOX_X0   : natural := 100;
        BOX_Y0   : natural := 50;
        BOX_DX   : natural := 3;
        BOX_DY   : natural := 2
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        mode         : in  std_logic_vector(1 downto 0);
        x            : in  unsigned(11 downto 0);
        y            : in  unsigned(11 downto 0);
        de           : in  std_logic;
        hsync        : in  std_logic;
        vsync        : in  std_logic;
        vblank_start : in  std_logic;
        rgb          : out std_logic_vector(23 downto 0);   -- R[23:16] G[15:8] B[7:0]
        de_o         : out std_logic;
        hsync_o      : out std_logic;
        vsync_o      : out std_logic
    );
end entity;

architecture rtl of test_pattern is
    constant BOX_XMAX : natural := H_ACTIVE - BOX;
    constant BOX_YMAX : natural := V_ACTIVE - BOX;
    signal box_x : unsigned(11 downto 0) := to_unsigned(BOX_X0, 12);
    signal box_y : unsigned(11 downto 0) := to_unsigned(BOX_Y0, 12);
    signal dir_x, dir_y : std_logic := '0';      -- '0' = kanan/bawah
    signal pix : std_logic_vector(23 downto 0);
begin
    -- posisi kotak, diperbarui sekali per frame
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                box_x <= to_unsigned(BOX_X0, 12);
                box_y <= to_unsigned(BOX_Y0, 12);
                dir_x <= '0';
                dir_y <= '0';
            elsif vblank_start = '1' then
                if dir_x = '0' then
                    if box_x + BOX_DX >= BOX_XMAX then
                        box_x <= to_unsigned(BOX_XMAX, 12); dir_x <= '1';
                    else
                        box_x <= box_x + BOX_DX;
                    end if;
                else
                    if box_x <= BOX_DX then
                        box_x <= (others => '0'); dir_x <= '0';
                    else
                        box_x <= box_x - BOX_DX;
                    end if;
                end if;
                if dir_y = '0' then
                    if box_y + BOX_DY >= BOX_YMAX then
                        box_y <= to_unsigned(BOX_YMAX, 12); dir_y <= '1';
                    else
                        box_y <= box_y + BOX_DY;
                    end if;
                else
                    if box_y <= BOX_DY then
                        box_y <= (others => '0'); dir_y <= '0';
                    else
                        box_y <= box_y - BOX_DY;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- warna per piksel (kombinasional)
    process (all)
        variable border, grid, in_box : boolean;
        variable grey : std_logic_vector(7 downto 0);
    begin
        border := x = 0 or x = H_ACTIVE - 1 or y = 0 or y = V_ACTIVE - 1;
        grid   := x(4 downto 0) = 0 or y(4 downto 0) = 0;
        in_box := x >= box_x and x < box_x + BOX and y >= box_y and y < box_y + BOX;
        grey   := std_logic_vector(x(9 downto 2));
        case mode is
            when "00" =>
                if    x <  80 then pix <= x"FFFFFF";
                elsif x < 160 then pix <= x"FFFF00";
                elsif x < 240 then pix <= x"00FFFF";
                elsif x < 320 then pix <= x"00FF00";
                elsif x < 400 then pix <= x"FF00FF";
                elsif x < 480 then pix <= x"FF0000";
                elsif x < 560 then pix <= x"0000FF";
                else               pix <= x"000000";
                end if;
            when "01" =>
                if border then    pix <= x"FF0000";
                elsif grid then   pix <= x"FFFFFF";
                else              pix <= x"101850";
                end if;
            when "10" =>
                if in_box then    pix <= x"FFD020";
                else              pix <= grey & grey & grey;
                end if;
            when others =>        pix <= x"000000";
        end case;
    end process;

    -- register keluaran (pipeline 1 siklus)
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rgb     <= (others => '0');
                de_o    <= '0';
                hsync_o <= '1';
                vsync_o <= '1';
            else
                if de = '1' then rgb <= pix; else rgb <= (others => '0'); end if;
                de_o    <= de;
                hsync_o <= hsync;
                vsync_o <= vsync;
            end if;
        end if;
    end process;
end architecture;
