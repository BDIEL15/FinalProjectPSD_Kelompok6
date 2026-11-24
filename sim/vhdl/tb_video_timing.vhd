-- tb_video_timing.vhd -- uji timing 640x480 dari video_timing.vhd
-- (port dari sim/tb_video_timing.v). Memeriksa panjang baris, baris per frame,
-- lebar & posisi pulsa sync, jumlah piksel aktif, dan vblank_start.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_video_timing is
end entity;

architecture sim of tb_video_timing is
    constant H_TOTAL   : integer := 800;
    constant V_TOTAL   : integer := 525;
    constant FRAME_CYC : integer := H_TOTAL * V_TOTAL;   -- 420000

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal x, y : unsigned(11 downto 0);
    signal de, hs, vs, vblank, vblank_start : std_logic;
    signal done : boolean := false;
begin
    clk <= not clk after 20 ns when not done;

    dut : entity work.video_timing
        port map (clk => clk, rst => rst, x => x, y => y, de => de, hsync => hs,
                  vsync => vs, vblank => vblank, vblank_start => vblank_start);

    process
        variable errors : integer := 0;
        variable cyc : integer := 0;
        variable de_count, de_line : integer := 0;
        variable max_de_line : integer := 0;
        variable min_de_line : integer := 99999;
        variable hs_low, vs_low : integer := 0;
        variable last_hs_fall, last_vs_fall, last_vbs : integer := -1;
        variable hs_fall_x, vs_fall_x, vs_fall_y : integer := -1;
        variable hs_width, vs_width, line_len, frame_len : integer := -1;
        variable vbs_count : integer := 0;
        variable hs_d, vs_d : std_logic := '1';
        variable de_d : std_logic := '0';

        procedure check(cond : boolean; msg : string) is
        begin
            if cond then
                report "[PASS] " & msg severity note;
            else
                report "[FAIL] " & msg severity error;
                errors := errors + 1;
            end if;
        end procedure;
    begin
        for i in 1 to 4 loop
            wait until rising_edge(clk);
        end loop;
        rst <= '0';
        -- siklus ke-1 = tepi pertama dengan rst = '0' (x = 0), sama seperti
        -- testbench Verilog; jendela statistik frame ke-2 mulai tepat di x = 0.
        for i in 1 to 3 * FRAME_CYC + 10 loop
            wait until rising_edge(clk);
            cyc := cyc + 1;

            if hs_d = '1' and hs = '0' then
                if last_hs_fall >= 0 then line_len := cyc - last_hs_fall; end if;
                last_hs_fall := cyc;
                hs_fall_x := to_integer(x);
                hs_low := 0;
            end if;
            if hs = '0' then hs_low := hs_low + 1; end if;
            if hs_d = '0' and hs = '1' then hs_width := hs_low; end if;

            if vs_d = '1' and vs = '0' then
                if last_vs_fall >= 0 then frame_len := cyc - last_vs_fall; end if;
                last_vs_fall := cyc;
                vs_fall_x := to_integer(x);
                vs_fall_y := to_integer(y);
                vs_low := 0;
            end if;
            if vs = '0' then vs_low := vs_low + 1; end if;
            if vs_d = '0' and vs = '1' then vs_width := vs_low; end if;

            if cyc > FRAME_CYC and cyc <= 2 * FRAME_CYC then
                if de = '1' then
                    de_count := de_count + 1;
                    de_line := de_line + 1;
                end if;
                if de_d = '1' and de = '0' then
                    if de_line > max_de_line then max_de_line := de_line; end if;
                    if de_line < min_de_line then min_de_line := de_line; end if;
                    de_line := 0;
                end if;
                if de = '1' and (x >= 640 or y >= 480) then
                    report "[FAIL] de aktif di luar area" severity error;
                    errors := errors + 1;
                end if;
                if (vblank = '1') /= (y >= 480) then
                    report "[FAIL] vblank salah" severity error;
                    errors := errors + 1;
                end if;
            end if;

            if vblank_start = '1' then
                vbs_count := vbs_count + 1;
                if x /= 0 or y /= 480 then
                    report "[FAIL] vblank_start di posisi salah" severity error;
                    errors := errors + 1;
                end if;
                if last_vbs >= 0 and cyc - last_vbs /= FRAME_CYC then
                    report "[FAIL] jarak vblank_start salah" severity error;
                    errors := errors + 1;
                end if;
                last_vbs := cyc;
            end if;

            hs_d := hs; vs_d := vs; de_d := de;
        end loop;

        check(line_len = 800,              "1 baris = 800 clock");
        check(hs_width = 96,               "lebar hsync = 96 clock");
        check(hs_fall_x = 656,             "hsync mulai di x = 640+16");
        check(frame_len = FRAME_CYC,       "1 frame = 525 baris = 420000 clock");
        check(vs_width = 2 * H_TOTAL,      "lebar vsync = 2 baris");
        check(vs_fall_x = 0 and vs_fall_y = 490, "vsync mulai di y = 480+10");
        check(de_count = 640 * 480,        "piksel aktif per frame = 307200");
        check(min_de_line = 640 and max_de_line = 640, "piksel aktif per baris = 640");
        check(vbs_count = 3,               "vblank_start 1x per frame");

        if errors = 0 then
            report "TB_VIDEO_TIMING PASS" severity note;
        else
            report "TB_VIDEO_TIMING FAIL (" & integer'image(errors) & " error)" severity error;
        end if;
        done <= true;
        finish;
    end process;
end architecture;
