-- tb_axi_regs.vhd -- uji gfx_axi_regs seperti ARM menulis lewat AXI4-Lite.
-- Yang dibuktikan:
--   1. tulis shadow TIDAK mengubah register aktif sebelum commit + vblank
--   2. commit di luar vblank -> STATUS.commit_pending = 1, aktif masih lama
--   3. awal vblank berikutnya -> aktif = shadow, commit_pending = 0
--   4. frame_count di STATUS naik tiap awal vblank
--   5. SFX_TRIGGER -> pulsa 1 siklus, dibaca 0; CTRL.commit dibaca 0
--   6. STATUS memuat tombol dan switch
--   7. tulis sebagian (wstrb) hanya mengubah byte terpilih
--   8. AW dan W datang di siklus berbeda tetap diterima
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.gfx_pkg.all;

entity tb_axi_regs is
end entity;

architecture sim of tb_axi_regs is
    signal clk : std_logic := '0';
    signal resetn : std_logic := '0';
    signal awaddr, araddr : std_logic_vector(6 downto 0) := (others => '0');
    signal awvalid, wvalid, bready, arvalid, rready : std_logic := '0';
    signal awready, wready, bvalid, arready, rvalid : std_logic;
    signal wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal wstrb : std_logic_vector(3 downto 0) := (others => '0');
    signal bresp, rresp : std_logic_vector(1 downto 0);
    signal rdata : std_logic_vector(31 downto 0);
    signal vblank_start, in_vblank : std_logic := '0';
    signal btn : std_logic_vector(3 downto 0) := "0101";
    signal sw  : std_logic_vector(3 downto 0) := "1010";
    signal regs : gfx_regs_t;
    signal sfx : std_logic_vector(2 downto 0);
    signal audio : std_logic_vector(7 downto 0);
    signal commit_done : std_logic;
    signal sfx_seen : std_logic_vector(2 downto 0) := "000";
    signal sfx_cycles : integer := 0;
    signal done : boolean := false;
begin
    clk <= not clk after 20 ns when not done;

    dut : entity work.gfx_axi_regs
        port map (clk => clk, resetn => resetn,
                  awaddr => awaddr, awvalid => awvalid, awready => awready,
                  wdata => wdata, wstrb => wstrb, wvalid => wvalid, wready => wready,
                  bresp => bresp, bvalid => bvalid, bready => bready,
                  araddr => araddr, arvalid => arvalid, arready => arready,
                  rdata => rdata, rresp => rresp, rvalid => rvalid, rready => rready,
                  vblank_start => vblank_start, in_vblank => in_vblank, btn => btn, sw => sw,
                  regs => regs, sfx_trigger => sfx, audio_ctrl => audio, commit_done => commit_done);

    -- catat pulsa SFX
    process (clk)
    begin
        if rising_edge(clk) then
            if sfx /= "000" then
                sfx_seen <= sfx_seen or sfx;
                sfx_cycles <= sfx_cycles + 1;
            end if;
        end if;
    end process;

    process
        variable errors : integer := 0;
        variable v : std_logic_vector(31 downto 0);
        variable fc0 : unsigned(15 downto 0);

        procedure check(cond : boolean; msg : string) is
        begin
            if cond then
                report "[PASS] " & msg;
            else
                report "[FAIL] " & msg severity error;
                errors := errors + 1;
            end if;
        end procedure;

        procedure tick(n : natural := 1) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure axi_write(addr : natural; data : std_logic_vector(31 downto 0);
                            strb : std_logic_vector(3 downto 0) := "1111";
                            w_delay : natural := 0) is
        begin
            awaddr <= std_logic_vector(to_unsigned(addr, 7));
            awvalid <= '1';
            if w_delay = 0 then
                wdata <= data; wstrb <= strb; wvalid <= '1';
            end if;
            bready <= '1';
            for i in 1 to w_delay loop
                wait until rising_edge(clk);
                if awready = '1' then awvalid <= '0'; end if;
            end loop;
            if w_delay > 0 then
                wdata <= data; wstrb <= strb; wvalid <= '1';
            end if;
            loop
                wait until rising_edge(clk);
                if awready = '1' then awvalid <= '0'; end if;
                if wready = '1' then wvalid <= '0'; end if;
                exit when bvalid = '1';
            end loop;
            awvalid <= '0'; wvalid <= '0';
            wait until rising_edge(clk);
            bready <= '0';
        end procedure;

        procedure axi_read(addr : natural; data : out std_logic_vector(31 downto 0)) is
        begin
            araddr <= std_logic_vector(to_unsigned(addr, 7));
            arvalid <= '1';
            rready <= '1';
            loop
                wait until rising_edge(clk);
                if arready = '1' then arvalid <= '0'; end if;
                exit when rvalid = '1';
            end loop;
            data := rdata;
            arvalid <= '0';
            wait until rising_edge(clk);
            rready <= '0';
        end procedure;

        procedure pulse_vblank is
        begin
            vblank_start <= '1';
            in_vblank <= '1';
            wait until rising_edge(clk);
            vblank_start <= '0';
            tick(3);
            in_vblank <= '0';
        end procedure;
    begin
        tick(3);
        resetn <= '1';
        tick(2);

        -- 1. shadow tidak langsung aktif
        axi_write(REG_BIRD_POS, x"00C8_00A0");          -- x=160, y=200
        axi_read(REG_BIRD_POS, v);
        check(v = x"00C8_00A0", "shadow BIRD_POS terbaca kembali");
        check(regs.bird_x = 0 and regs.bird_y = 0, "aktif belum berubah sebelum commit");
        pulse_vblank;
        check(regs.bird_x = 0, "vblank tanpa commit tidak menyalin shadow");

        -- 2. commit di luar vblank
        axi_write(REG_CTRL, x"0000_0005");              -- enable + commit
        axi_read(REG_STATUS, v);
        check(v(1) = '1', "STATUS.commit_pending = 1 setelah commit");
        check(regs.bird_x = 0 and regs.enable = '0', "aktif masih lama sebelum vblank");
        axi_read(REG_CTRL, v);
        check(v(2) = '0' and v(0) = '1', "CTRL.commit self-clear, enable tersimpan");

        -- 3. vblank berikutnya menerapkan commit
        fc0 := unsigned(v(31 downto 16));
        axi_read(REG_STATUS, v);
        fc0 := unsigned(v(31 downto 16));
        pulse_vblank;
        check(regs.bird_x = 160 and regs.bird_y = 200 and regs.enable = '1',
              "aktif = shadow setelah vblank");
        axi_read(REG_STATUS, v);
        check(v(1) = '0', "commit_pending kembali 0");
        -- 4. frame_count
        check(unsigned(v(31 downto 16)) = fc0 + 1, "frame_count naik 1 tiap vblank");

        -- shadow yang ditulis setelah commit tidak bocor ke aktif
        axi_write(REG_BIRD_POS, x"0010_0020");
        pulse_vblank;
        check(regs.bird_x = 160, "tulis tanpa commit baru tidak bocor ke aktif");

        -- 5. SFX
        axi_write(REG_SFX_TRIGGER, x"0000_0005");
        tick(2);
        check(sfx_seen = "101" and sfx_cycles = 1, "SFX_TRIGGER = pulsa 1 siklus (flap + tabrak)");
        axi_read(REG_SFX_TRIGGER, v);
        check(v = x"0000_0000", "SFX_TRIGGER dibaca 0");

        -- 6. tombol dan switch
        axi_read(REG_STATUS, v);
        check(v(7 downto 4) = "0101" and v(11 downto 8) = "1010", "STATUS memuat btn dan sw");

        -- 7. wstrb: hanya byte 0 skor
        axi_write(REG_SCORE, x"0000_1234");
        axi_write(REG_SCORE, x"0000_FF99", "0001");
        axi_read(REG_SCORE, v);
        check(v = x"0000_1299", "tulis sebagian (wstrb) hanya byte terpilih");

        -- 8. AW dulu, W 3 siklus kemudian
        axi_write(REG_PIPE0 + 4, x"8007_8064", "1111", 3);
        axi_read(REG_PIPE0 + 4, v);
        check(v = x"8007_8064", "AW dan W di siklus berbeda diterima");

        -- palet default terisi saat reset
        axi_read(REG_PALETTE0 + 4 * 14, v);
        check(v = x"005A_A0E6", "palet default (langit) terisi saat reset");

        check(bresp = "00" and rresp = "00", "respons OKAY");
        if errors = 0 then
            report "TB_AXI_REGS PASS";
        else
            report "TB_AXI_REGS FAIL (" & integer'image(errors) & " error)" severity error;
        end if;
        done <= true;
        finish;
    end process;
end architecture;
