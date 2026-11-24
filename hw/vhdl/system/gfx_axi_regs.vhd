-- gfx_axi_regs.vhd -- slave AXI4-Lite register akselerator grafis (32 x 32-bit).
-- Register map: docs/tugas/README.md §3.1 = sw/game/regs.h.
--
--   * Register shadow ditulis ARM kapan saja. Pada awal vblank SETELAH
--     CTRL.commit ditulis, seluruh shadow disalin ke register aktif sekaligus,
--     jadi renderer tidak pernah melihat frame setengah jadi (tanpa tearing).
--   * CTRL.commit dan SFX_TRIGGER self-clear (dibaca 0).
--   * STATUS (baca saja): [0] in_vblank [1] commit_pending [7:4] btn
--     [11:8] sw [31:16] frame_count (naik tiap awal vblank).
--   * Satu clock untuk AXI dan video (clock piksel), jadi tidak ada CDC.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;
use work.assets_pkg.all;

entity gfx_axi_regs is
    port (
        clk          : in  std_logic;
        resetn       : in  std_logic;
        -- AXI4-Lite slave
        awaddr  : in  std_logic_vector(6 downto 0);
        awvalid : in  std_logic;
        awready : out std_logic;
        wdata   : in  std_logic_vector(31 downto 0);
        wstrb   : in  std_logic_vector(3 downto 0);
        wvalid  : in  std_logic;
        wready  : out std_logic;
        bresp   : out std_logic_vector(1 downto 0);
        bvalid  : out std_logic;
        bready  : in  std_logic;
        araddr  : in  std_logic_vector(6 downto 0);
        arvalid : in  std_logic;
        arready : out std_logic;
        rdata   : out std_logic_vector(31 downto 0);
        rresp   : out std_logic_vector(1 downto 0);
        rvalid  : out std_logic;
        rready  : in  std_logic;
        -- dari video / board
        vblank_start : in  std_logic;
        in_vblank    : in  std_logic;
        btn          : in  std_logic_vector(3 downto 0);   -- sudah disinkronkan
        sw           : in  std_logic_vector(3 downto 0);
        -- ke renderer / suara
        regs         : out gfx_regs_t;
        sfx_trigger  : out std_logic_vector(2 downto 0);   -- pulsa 1 siklus
        audio_ctrl   : out std_logic_vector(7 downto 0);
        commit_done  : out std_logic                       -- pulsa saat shadow -> aktif
    );
end entity;

architecture rtl of gfx_axi_regs is
    constant IDX_CTRL   : natural := REG_CTRL / 4;
    constant IDX_STATUS : natural := REG_STATUS / 4;
    constant IDX_SFX    : natural := REG_SFX_TRIGGER / 4;
    constant IDX_AUDIO  : natural := REG_AUDIO_CTRL / 4;

    function reset_words return reg_words_t is
        variable w : reg_words_t := (others => (others => '0'));
    begin
        for i in 0 to 15 loop
            w(REG_PALETTE0 / 4 + i) := x"00" & DEFAULT_PALETTE(i);
        end loop;
        return w;
    end function;
    constant WORDS_RESET : reg_words_t := reset_words;

    signal shadow, active : reg_words_t := WORDS_RESET;
    signal commit_pending : std_logic := '0';
    signal frame_count    : unsigned(15 downto 0) := (others => '0');
    signal aw_ok, w_ok    : std_logic := '0';     -- alamat / data sudah diterima
    signal aw_addr        : std_logic_vector(6 downto 0) := (others => '0');
    signal w_data         : std_logic_vector(31 downto 0) := (others => '0');
    signal w_strb         : std_logic_vector(3 downto 0) := (others => '0');
    signal bvalid_i, rvalid_i : std_logic := '0';
    signal sfx_i : std_logic_vector(2 downto 0) := (others => '0');
    signal commit_done_i : std_logic := '0';
begin
    sfx_trigger <= sfx_i;
    commit_done <= commit_done_i;
    -- kanal tulis: terima AW dan W (boleh datang terpisah), lalu satu respons B
    awready <= '1' when aw_ok = '0' and bvalid_i = '0' and resetn = '1' else '0';
    wready  <= '1' when w_ok = '0' and bvalid_i = '0' and resetn = '1' else '0';
    bresp   <= "00";
    bvalid  <= bvalid_i;
    -- kanal baca
    arready <= '1' when rvalid_i = '0' and resetn = '1' else '0';
    rresp   <= "00";
    rvalid  <= rvalid_i;

    process (clk)
        variable idx : natural range 0 to 31;
        variable aw_now, w_now : std_logic;
        variable a : std_logic_vector(6 downto 0);
        variable d : std_logic_vector(31 downto 0);
        variable s : std_logic_vector(3 downto 0);
        variable merged : std_logic_vector(31 downto 0);
        variable st : std_logic_vector(31 downto 0);
        variable pending_next : std_logic;
    begin
        if rising_edge(clk) then
            sfx_i <= (others => '0');
            commit_done_i <= '0';
            if resetn = '0' then
                shadow <= WORDS_RESET;
                active <= WORDS_RESET;
                commit_pending <= '0';
                frame_count <= (others => '0');
                aw_ok <= '0';
                w_ok <= '0';
                bvalid_i <= '0';
                rvalid_i <= '0';
                rdata <= (others => '0');
            else
                pending_next := commit_pending;

                -- awal vblank: terapkan commit (sebelum tulis baru di siklus yang sama)
                if vblank_start = '1' then
                    frame_count <= frame_count + 1;
                    if commit_pending = '1' then
                        active <= shadow;
                        pending_next := '0';
                        commit_done_i <= '1';
                    end if;
                end if;

                -- tangkap alamat dan data tulis
                aw_now := aw_ok;
                w_now := w_ok;
                a := aw_addr;
                d := w_data;
                s := w_strb;
                if aw_ok = '0' and bvalid_i = '0' and awvalid = '1' then
                    aw_now := '1';
                    a := awaddr;
                end if;
                if w_ok = '0' and bvalid_i = '0' and wvalid = '1' then
                    w_now := '1';
                    d := wdata;
                    s := wstrb;
                end if;

                if aw_now = '1' and w_now = '1' then
                    idx := to_integer(unsigned(a(6 downto 2)));
                    merged := shadow(idx);
                    for b in 0 to 3 loop
                        if s(b) = '1' then
                            merged(8 * b + 7 downto 8 * b) := d(8 * b + 7 downto 8 * b);
                        end if;
                    end loop;
                    if idx = IDX_CTRL then
                        if s(0) = '1' and d(2) = '1' then
                            pending_next := '1';        -- commit; berlaku di vblank berikut
                        end if;
                        merged(2) := '0';               -- self-clear
                        shadow(idx) <= merged;
                    elsif idx = IDX_SFX then
                        if s(0) = '1' then
                            sfx_i <= d(2 downto 0);
                        end if;
                    elsif idx = IDX_AUDIO then
                        shadow(idx) <= merged;          -- langsung berlaku (lihat audio_ctrl)
                    elsif idx /= IDX_STATUS then
                        shadow(idx) <= merged;
                    end if;
                    aw_ok <= '0';
                    w_ok <= '0';
                    bvalid_i <= '1';
                else
                    aw_ok <= aw_now;
                    w_ok <= w_now;
                    aw_addr <= a;
                    w_data <= d;
                    w_strb <= s;
                end if;
                if bvalid_i = '1' and bready = '1' then
                    bvalid_i <= '0';
                end if;
                commit_pending <= pending_next;

                -- baca
                if rvalid_i = '0' and arvalid = '1' then
                    idx := to_integer(unsigned(araddr(6 downto 2)));
                    if idx = IDX_STATUS then
                        st := (others => '0');
                        st(0) := in_vblank;
                        st(1) := commit_pending;
                        st(7 downto 4) := btn;
                        st(11 downto 8) := sw;
                        st(31 downto 16) := std_logic_vector(frame_count);
                        rdata <= st;
                    elsif idx = IDX_SFX then
                        rdata <= (others => '0');
                    else
                        rdata <= shadow(idx);
                    end if;
                    rvalid_i <= '1';
                elsif rvalid_i = '1' and rready = '1' then
                    rvalid_i <= '0';
                end if;
            end if;
        end if;
    end process;

    regs <= regs_decode(active);
    audio_ctrl <= shadow(IDX_AUDIO)(7 downto 0);
end architecture;
