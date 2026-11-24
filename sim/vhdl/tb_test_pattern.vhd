-- tb_test_pattern.vhd -- simulasikan video_timing + test_pattern, simpan satu
-- frame penuh tiap mode ke .ppm (port dari sim/tb_frame_dump.v).
-- Urutan: reset -> vblank #1 -> dump mode 0 -> vblank #2 -> dump mode 1
--         -> sampai vblank #5 -> dump mode 2 (kotak sudah bergerak 5 kali)
-- Generic OUT_DIR = folder keluaran (diisi skrip sim/run_vhdl.ps1).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_test_pattern is
    generic (OUT_DIR : string := "sim/out");
end entity;

architecture sim of tb_test_pattern is
    constant W : integer := 640;
    constant H : integer := 480;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal mode : std_logic_vector(1 downto 0) := "00";
    signal x, y : unsigned(11 downto 0);
    signal de, hs, vs, vblank, vblank_start : std_logic;
    signal rgb : std_logic_vector(23 downto 0);
    signal de_o, hs_o, vs_o : std_logic;
    signal vbs : integer := 0;
    signal done : boolean := false;
begin
    clk <= not clk after 20 ns when not done;

    timing : entity work.video_timing
        port map (clk => clk, rst => rst, x => x, y => y, de => de, hsync => hs,
                  vsync => vs, vblank => vblank, vblank_start => vblank_start);
    pattern : entity work.test_pattern
        port map (clk => clk, rst => rst, mode => mode, x => x, y => y, de => de,
                  hsync => hs, vsync => vs, vblank_start => vblank_start,
                  rgb => rgb, de_o => de_o, hsync_o => hs_o, vsync_o => vs_o);

    process (clk)
    begin
        if rising_edge(clk) and rst = '0' and vblank_start = '1' then
            vbs <= vbs + 1;
        end if;
    end process;

    process
        procedure dump_frame(name : string) is
            file f : text;
            variable l : line;
            variable n : integer := 0;
        begin
            file_open(f, OUT_DIR & "/" & name, write_mode);
            write(l, string'("P3")); writeline(f, l);
            write(l, integer'image(W) & " " & integer'image(H)); writeline(f, l);
            write(l, string'("255")); writeline(f, l);
            while n < W * H loop
                wait until rising_edge(clk);
                wait for 1 ns;     -- baca keluaran register setelah tepi clock
                if de_o = '1' then
                    write(l, integer'image(to_integer(unsigned(rgb(23 downto 16)))) & " " &
                             integer'image(to_integer(unsigned(rgb(15 downto 8)))) & " " &
                             integer'image(to_integer(unsigned(rgb(7 downto 0)))));
                    writeline(f, l);
                    n := n + 1;
                end if;
            end loop;
            file_close(f);
            report "ditulis " & name & " setelah vblank ke-" & integer'image(vbs);
        end procedure;

        procedure wait_vblank_count(k : integer) is
        begin
            while vbs < k loop
                wait until rising_edge(clk);
            end loop;
        end procedure;
    begin
        for i in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;
        rst <= '0';
        mode <= "00"; wait_vblank_count(1); dump_frame("vhdl_mode0.ppm");
        mode <= "01"; wait_vblank_count(2); dump_frame("vhdl_mode1.ppm");
        mode <= "10"; wait_vblank_count(5); dump_frame("vhdl_mode2.ppm");
        report "TB_TEST_PATTERN DONE";
        done <= true;
        finish;
    end process;
end architecture;
