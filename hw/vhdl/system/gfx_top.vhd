-- gfx_top.vhd -- akselerator grafis lengkap untuk block design (module reference).
--   clocking -> video_timing -> renderer (atau test pattern) -> dvi_tx -> HDMI TX
--   ARM menulis register lewat s_axi (AXI4-Lite) ke gfx_axi_regs.
--
-- Clock: MMCM di sini membuat clock piksel 25 MHz dari sysclk 125 MHz dan
-- mengeluarkannya di pix_clk_o. Block design menyambungkan pix_clk_o ke
-- s_axi_aclk, M_AXI_GP0_ACLK PS7, interconnect, dan proc_sys_reset. Jadi bus
-- AXI dan video memakai SATU clock (tanpa CDC). locked_o -> dcm_locked.
--
-- Sebelum ARM menyalakan renderer (CTRL.enable = 0) layar menampilkan pola
-- uji sesuai sw(1:0): bukti HDMI hidup walau program C belum jalan.
--   led(0) MMCM terkunci   led(1) HPD monitor
--   led(2) kedip ~1 Hz     led(3) kedip ~1 Hz selama ARM rutin commit tiap frame
--
-- Ditulis dengan sintaks VHDL-93 (tanpa fitur 2008) karena file top module
-- reference di Vivado secara historis dibatasi ke VHDL-93/Verilog.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;

entity gfx_top is
    port (
        sysclk        : in  std_logic;
        btn           : in  std_logic_vector(3 downto 0);
        sw            : in  std_logic_vector(3 downto 0);
        led           : out std_logic_vector(3 downto 0);
        hdmi_tx_hpd   : in  std_logic;
        hdmi_tx_clk_p : out std_logic;
        hdmi_tx_clk_n : out std_logic;
        hdmi_tx_p     : out std_logic_vector(2 downto 0);
        hdmi_tx_n     : out std_logic_vector(2 downto 0);
        pix_clk_o     : out std_logic;
        locked_o      : out std_logic;
        -- AXI4-Lite slave (clock = pix_clk_o, disambung di block design)
        s_axi_aclk    : in  std_logic;
        s_axi_aresetn : in  std_logic;
        s_axi_awaddr  : in  std_logic_vector(6 downto 0);
        s_axi_awprot  : in  std_logic_vector(2 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wstrb   : in  std_logic_vector(3 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(6 downto 0);
        s_axi_arprot  : in  std_logic_vector(2 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic
    );
    -- Atribut antarmuka Vivado (inferensi AXI4-Lite, clock, reset di block design).
    -- Menurut standar VHDL atribut port dideklarasikan di entity.
    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER : string;
    attribute X_INTERFACE_INFO of pix_clk_o : signal is "xilinx.com:signal:clock:1.0 pix_clk_o CLK";
    attribute X_INTERFACE_PARAMETER of pix_clk_o : signal is "FREQ_HZ 25000000";
    attribute X_INTERFACE_INFO of s_axi_aclk : signal is "xilinx.com:signal:clock:1.0 s_axi_aclk CLK";
    attribute X_INTERFACE_PARAMETER of s_axi_aclk : signal is
        "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 25000000";
    attribute X_INTERFACE_INFO of s_axi_aresetn : signal is "xilinx.com:signal:reset:1.0 s_axi_aresetn RST";
    attribute X_INTERFACE_PARAMETER of s_axi_aresetn : signal is "POLARITY ACTIVE_LOW";
    attribute X_INTERFACE_INFO of s_axi_awaddr  : signal is "xilinx.com:interface:aximm:1.0 s_axi AWADDR";
    attribute X_INTERFACE_PARAMETER of s_axi_awaddr : signal is
        "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 7, FREQ_HZ 25000000";
    attribute X_INTERFACE_INFO of s_axi_awprot  : signal is "xilinx.com:interface:aximm:1.0 s_axi AWPROT";
    attribute X_INTERFACE_INFO of s_axi_awvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi AWVALID";
    attribute X_INTERFACE_INFO of s_axi_awready : signal is "xilinx.com:interface:aximm:1.0 s_axi AWREADY";
    attribute X_INTERFACE_INFO of s_axi_wdata   : signal is "xilinx.com:interface:aximm:1.0 s_axi WDATA";
    attribute X_INTERFACE_INFO of s_axi_wstrb   : signal is "xilinx.com:interface:aximm:1.0 s_axi WSTRB";
    attribute X_INTERFACE_INFO of s_axi_wvalid  : signal is "xilinx.com:interface:aximm:1.0 s_axi WVALID";
    attribute X_INTERFACE_INFO of s_axi_wready  : signal is "xilinx.com:interface:aximm:1.0 s_axi WREADY";
    attribute X_INTERFACE_INFO of s_axi_bresp   : signal is "xilinx.com:interface:aximm:1.0 s_axi BRESP";
    attribute X_INTERFACE_INFO of s_axi_bvalid  : signal is "xilinx.com:interface:aximm:1.0 s_axi BVALID";
    attribute X_INTERFACE_INFO of s_axi_bready  : signal is "xilinx.com:interface:aximm:1.0 s_axi BREADY";
    attribute X_INTERFACE_INFO of s_axi_araddr  : signal is "xilinx.com:interface:aximm:1.0 s_axi ARADDR";
    attribute X_INTERFACE_INFO of s_axi_arprot  : signal is "xilinx.com:interface:aximm:1.0 s_axi ARPROT";
    attribute X_INTERFACE_INFO of s_axi_arvalid : signal is "xilinx.com:interface:aximm:1.0 s_axi ARVALID";
    attribute X_INTERFACE_INFO of s_axi_arready : signal is "xilinx.com:interface:aximm:1.0 s_axi ARREADY";
    attribute X_INTERFACE_INFO of s_axi_rdata   : signal is "xilinx.com:interface:aximm:1.0 s_axi RDATA";
    attribute X_INTERFACE_INFO of s_axi_rresp   : signal is "xilinx.com:interface:aximm:1.0 s_axi RRESP";
    attribute X_INTERFACE_INFO of s_axi_rvalid  : signal is "xilinx.com:interface:aximm:1.0 s_axi RVALID";
    attribute X_INTERFACE_INFO of s_axi_rready  : signal is "xilinx.com:interface:aximm:1.0 s_axi RREADY";
end entity;

architecture rtl of gfx_top is
    signal pix_clk, ser_clk, locked, mmcm_rst : std_logic;
    signal clk : std_logic;           -- = s_axi_aclk = pix_clk (lewat block design)
    signal rst : std_logic := '1';
    signal btn_s1, btn_s2, sw_s1, sw_s2 : std_logic_vector(3 downto 0) := (others => '0');
    signal x, y : unsigned(11 downto 0);
    signal de, hs, vs, vblank, vblank_start : std_logic;
    signal regs : gfx_regs_t;
    signal r_rgb, t_rgb, t_rgb_d, rgb : std_logic_vector(23 downto 0);
    signal r_de, r_hs, r_vs, t_de, t_hs, t_vs : std_logic;
    signal t_de_d, t_hs_d, t_vs_d : std_logic := '0';
    signal de_o, hs_o, vs_o : std_logic;
    signal sfx_trigger : std_logic_vector(2 downto 0);
    signal audio_ctrl : std_logic_vector(7 downto 0);
    signal commit_done : std_logic;
    signal commit_cnt : unsigned(5 downto 0) := (others => '0');
    signal frame_cnt : unsigned(5 downto 0) := (others => '0');
begin
    clk_i : entity work.clocking
        port map (sysclk => sysclk, rst_in => '0', pix_clk => pix_clk,
                  ser_clk => ser_clk, locked => locked, pix_rst => mmcm_rst);
    pix_clk_o <= pix_clk;
    locked_o  <= locked;
    clk       <= s_axi_aclk;

    process (clk)
    begin
        if rising_edge(clk) then
            if s_axi_aresetn = '0' or mmcm_rst = '1' then
                rst <= '1';
            else
                rst <= '0';
            end if;
            btn_s1 <= btn;  btn_s2 <= btn_s1;
            sw_s1  <= sw;   sw_s2  <= sw_s1;
        end if;
    end process;

    timing : entity work.video_timing
        port map (clk => clk, rst => rst, x => x, y => y, de => de, hsync => hs,
                  vsync => vs, vblank => vblank, vblank_start => vblank_start);

    regs_i : entity work.gfx_axi_regs
        port map (
            clk => clk, resetn => s_axi_aresetn,
            awaddr => s_axi_awaddr, awvalid => s_axi_awvalid, awready => s_axi_awready,
            wdata => s_axi_wdata, wstrb => s_axi_wstrb, wvalid => s_axi_wvalid, wready => s_axi_wready,
            bresp => s_axi_bresp, bvalid => s_axi_bvalid, bready => s_axi_bready,
            araddr => s_axi_araddr, arvalid => s_axi_arvalid, arready => s_axi_arready,
            rdata => s_axi_rdata, rresp => s_axi_rresp, rvalid => s_axi_rvalid, rready => s_axi_rready,
            vblank_start => vblank_start, in_vblank => vblank, btn => btn_s2, sw => sw_s2,
            regs => regs, sfx_trigger => sfx_trigger, audio_ctrl => audio_ctrl,
            commit_done => commit_done);

    render : entity work.renderer
        port map (clk => clk, rst => rst, x => x, y => y, de => de, hsync => hs, vsync => vs,
                  regs => regs, rgb => r_rgb, de_o => r_de, hsync_o => r_hs, vsync_o => r_vs);

    pattern : entity work.test_pattern
        port map (clk => clk, rst => rst, mode => sw_s2(1 downto 0), x => x, y => y, de => de,
                  hsync => hs, vsync => vs, vblank_start => vblank_start,
                  rgb => t_rgb, de_o => t_de, hsync_o => t_hs, vsync_o => t_vs);

    -- test_pattern berlatensi 1, renderer 2: samakan dengan satu register tambahan
    process (clk)
    begin
        if rising_edge(clk) then
            t_rgb_d <= t_rgb;
            t_de_d <= t_de;
            t_hs_d <= t_hs;
            t_vs_d <= t_vs;
        end if;
    end process;

    rgb  <= r_rgb when regs.enable = '1' else t_rgb_d;
    de_o <= r_de  when regs.enable = '1' else t_de_d;
    hs_o <= r_hs  when regs.enable = '1' else t_hs_d;
    vs_o <= r_vs  when regs.enable = '1' else t_vs_d;

    tx : entity work.dvi_tx
        port map (pix_clk => clk, ser_clk => ser_clk, rst => rst, rgb => rgb,
                  de => de_o, hsync => hs_o, vsync => vs_o,
                  tmds_clk_p => hdmi_tx_clk_p, tmds_clk_n => hdmi_tx_clk_n,
                  tmds_p => hdmi_tx_p, tmds_n => hdmi_tx_n);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                frame_cnt <= (others => '0');
                commit_cnt <= (others => '0');
            else
                if vblank_start = '1' then
                    frame_cnt <= frame_cnt + 1;
                end if;
                if commit_done = '1' then
                    commit_cnt <= commit_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    led(0) <= locked;
    led(1) <= hdmi_tx_hpd;
    led(2) <= frame_cnt(5);
    led(3) <= commit_cnt(5);
end architecture;
