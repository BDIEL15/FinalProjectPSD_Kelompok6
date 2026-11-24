-- tb_tmds.vhd -- bandingkan tmds_encoder.vhd dengan tools/ref_tmds.py.
-- stim.txt: "<de> <c> <d>" per baris; exp.txt: "<q>" per baris (dari Python).
-- Encoder berlatensi 1 siklus: keluaran dibaca setelah tepi clock berikutnya.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_tmds is
    generic (STIM : string := "sim/out/tmds_stim.txt"; EXPECT : string := "sim/out/tmds_exp.txt");
end entity;

architecture sim of tb_tmds is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal de  : std_logic := '0';
    signal c   : std_logic_vector(1 downto 0) := "00";
    signal d   : std_logic_vector(7 downto 0) := (others => '0');
    signal q   : std_logic_vector(9 downto 0);
    signal done : boolean := false;
begin
    clk <= not clk after 5 ns when not done;

    dut : entity work.tmds_encoder
        port map (clk => clk, rst => rst, de => de, c => c, d => d, q => q);

    process
        file fs, fe : text;
        variable ls, le : line;
        variable v_de, v_c, v_d, v_q : integer;
        variable n, errors : integer := 0;
    begin
        file_open(fs, STIM, read_mode);
        file_open(fe, EXPECT, read_mode);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        while not endfile(fs) loop
            readline(fs, ls);
            read(ls, v_de); read(ls, v_c); read(ls, v_d);
            readline(fe, le);
            read(le, v_q);
            de <= '1' when v_de = 1 else '0';
            c  <= std_logic_vector(to_unsigned(v_c, 2));
            d  <= std_logic_vector(to_unsigned(v_d, 8));
            wait until rising_edge(clk);
            wait for 1 ns;
            if to_integer(unsigned(q)) /= v_q then
                if errors < 5 then
                    report "[FAIL] baris " & integer'image(n + 1) & ": q=" &
                           integer'image(to_integer(unsigned(q))) & " seharusnya " &
                           integer'image(v_q) severity error;
                end if;
                errors := errors + 1;
            end if;
            n := n + 1;
        end loop;
        if errors = 0 then
            report "TB_TMDS PASS (" & integer'image(n) & " simbol identik dengan ref_tmds.py)";
        else
            report "TB_TMDS FAIL (" & integer'image(errors) & " dari " & integer'image(n) & " beda)"
                severity error;
        end if;
        done <= true;
        finish;
    end process;
end architecture;
