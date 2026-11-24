-- tb_renderer.vhd -- gambar satu frame dari isi register, simpan ke .ppm.
-- REGS_FILE: satu baris "<frame> <reg0x00> ... <reg0x7C>" (hex, format
-- sw/game/game_regs / tools/render_scenarios.py). Hasil dibandingkan dengan
-- gambar tools/ref_render.py oleh sim/run_vhdl.ps1. Juga mengecek bahwa
-- de_o tertunda tepat RENDER_LATENCY siklus dari de.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;
use work.gfx_pkg.all;

entity tb_renderer is
    generic (
        REGS_FILE : string := "sim/out/scenarios/menu.regs";
        OUT_FILE  : string := "sim/out/scenarios/menu.vhdl.ppm"
    );
end entity;

architecture sim of tb_renderer is
    constant W : integer := 640;
    constant H : integer := 480;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal x, y : unsigned(11 downto 0);
    signal de, hs, vs, vblank, vblank_start : std_logic;
    signal regs : gfx_regs_t := GFX_REGS_RESET;
    signal rgb : std_logic_vector(23 downto 0);
    signal de_o, hs_o, vs_o : std_logic;
    signal de_d1, de_d2 : std_logic := '0';
    signal lat_err : boolean := false;
    signal done : boolean := false;
begin
    clk <= not clk after 20 ns when not done;

    timing : entity work.video_timing
        port map (clk => clk, rst => rst, x => x, y => y, de => de, hsync => hs,
                  vsync => vs, vblank => vblank, vblank_start => vblank_start);
    dut : entity work.renderer
        port map (clk => clk, rst => rst, x => x, y => y, de => de, hsync => hs, vsync => vs,
                  regs => regs, rgb => rgb, de_o => de_o, hsync_o => hs_o, vsync_o => vs_o);

    -- de_o harus sama dengan de yang ditunda RENDER_LATENCY (= 2) siklus.
    -- Rantai tunda ini di-reset bersama renderer (saat reset video_timing sudah
    -- mengeluarkan de = '1' di x=0, y=0, sedangkan renderer menahan de_o = '0').
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                de_d1 <= '0';
                de_d2 <= '0';
            else
                de_d1 <= de;
                de_d2 <= de_d1;
                if de_o /= de_d2 then
                    lat_err <= true;
                end if;
            end if;
        end if;
    end process;

    process
        file fr, fo : text;
        variable l : line;
        variable frame_no : integer;
        variable words : reg_words_t;
        variable n : integer := 0;
    begin
        file_open(fr, REGS_FILE, read_mode);
        readline(fr, l);
        read(l, frame_no);
        for i in 0 to 31 loop
            hread(l, words(i));
        end loop;
        file_close(fr);
        regs <= regs_decode(words);

        for i in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;
        rst <= '0';

        file_open(fo, OUT_FILE, write_mode);
        write(l, string'("P3")); writeline(fo, l);
        write(l, integer'image(W) & " " & integer'image(H)); writeline(fo, l);
        write(l, string'("255")); writeline(fo, l);
        while n < W * H loop
            wait until rising_edge(clk);
            wait for 1 ns;
            if de_o = '1' then
                write(l, integer'image(to_integer(unsigned(rgb(23 downto 16)))) & " " &
                         integer'image(to_integer(unsigned(rgb(15 downto 8)))) & " " &
                         integer'image(to_integer(unsigned(rgb(7 downto 0)))));
                writeline(fo, l);
                n := n + 1;
            end if;
        end loop;
        file_close(fo);
        if lat_err then
            report "[FAIL] de_o tidak tertunda tepat RENDER_LATENCY siklus" severity error;
        else
            report "[PASS] latensi renderer = " & integer'image(RENDER_LATENCY) & " siklus";
        end if;
        done <= true;
        finish;
    end process;
end architecture;
