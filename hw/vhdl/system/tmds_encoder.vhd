-- tmds_encoder.vhd -- encoder TMDS 8b/10b sesuai spesifikasi DVI 1.0 §3.2.
--   Tahap 1: minimasi transisi (XOR / XNOR berantai) -> q_m(8:0)
--   Tahap 2: penyeimbangan DC memakai penghitung disparitas berjalan (cnt)
--   de = '0': kirim salah satu dari 4 kode kontrol (c = hsync/vsync di kanal 0)
-- Latensi 1 siklus. Bit 0 dikirim pertama di kabel.
-- Model referensi: tools/ref_tmds.py (diuji sim/vhdl/tb_tmds.vhd).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tmds_encoder is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        de  : in  std_logic;
        c   : in  std_logic_vector(1 downto 0);
        d   : in  std_logic_vector(7 downto 0);
        q   : out std_logic_vector(9 downto 0)
    );
end entity;

architecture rtl of tmds_encoder is
    signal cnt : signed(4 downto 0) := (others => '0');   -- disparitas berjalan, -8..+8

    function ones(v : std_logic_vector) return integer is
        variable n : integer := 0;
    begin
        for i in v'range loop
            if v(i) = '1' then n := n + 1; end if;
        end loop;
        return n;
    end function;
begin
    process (clk)
        variable qm : std_logic_vector(8 downto 0);
        variable n1d, n1q, n0q : integer;
        variable cnt_v : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                q   <= "1101010100";
                cnt <= (others => '0');
            elsif de = '0' then
                case c is
                    when "00"   => q <= "1101010100";
                    when "01"   => q <= "0010101011";
                    when "10"   => q <= "0101010100";
                    when others => q <= "1010101011";
                end case;
                cnt <= (others => '0');
            else
                -- tahap 1
                n1d := ones(d);
                qm(0) := d(0);
                if n1d > 4 or (n1d = 4 and d(0) = '0') then
                    for i in 1 to 7 loop
                        qm(i) := qm(i - 1) xnor d(i);
                    end loop;
                    qm(8) := '0';
                else
                    for i in 1 to 7 loop
                        qm(i) := qm(i - 1) xor d(i);
                    end loop;
                    qm(8) := '1';
                end if;
                -- tahap 2
                n1q := ones(qm(7 downto 0));
                n0q := 8 - n1q;
                cnt_v := to_integer(cnt);
                if cnt_v = 0 or n1q = n0q then
                    q(9) <= not qm(8);
                    q(8) <= qm(8);
                    if qm(8) = '1' then
                        q(7 downto 0) <= qm(7 downto 0);
                        cnt_v := cnt_v + n1q - n0q;
                    else
                        q(7 downto 0) <= not qm(7 downto 0);
                        cnt_v := cnt_v + n0q - n1q;
                    end if;
                elsif (cnt_v > 0 and n1q > n0q) or (cnt_v < 0 and n0q > n1q) then
                    q(9) <= '1';
                    q(8) <= qm(8);
                    q(7 downto 0) <= not qm(7 downto 0);
                    if qm(8) = '1' then
                        cnt_v := cnt_v + 2 + n0q - n1q;
                    else
                        cnt_v := cnt_v + n0q - n1q;
                    end if;
                else
                    q(9) <= '0';
                    q(8) <= qm(8);
                    q(7 downto 0) <= qm(7 downto 0);
                    if qm(8) = '1' then
                        cnt_v := cnt_v + n1q - n0q;
                    else
                        cnt_v := cnt_v - 2 + n1q - n0q;
                    end if;
                end if;
                cnt <= to_signed(cnt_v, 5);
            end if;
        end if;
    end process;
end architecture;
