-- unisim_stub.vhd -- PENGGANTI library unisim Xilinx, HANYA untuk GHDL.
--
-- GHDL tidak punya primitif Xilinx (MMCME2_BASE, BUFG, OSERDESE2, OBUFDS).
-- File ini mendeklarasikan port/generic yang dipakai proyek supaya file yang
-- memakai primitif bisa dianalisis dan dielaborasi (cek sintaks + sambungan).
-- Perilakunya disederhanakan: MMCM meneruskan clock masukan, serializer
-- mengeluarkan '0'. Kebenaran fungsi primitif hanya dibuktikan di Vivado/board.
-- JANGAN dimasukkan ke proyek Vivado.
library ieee;
use ieee.std_logic_1164.all;

package vcomponents is
    component MMCME2_BASE is
        generic (
            BANDWIDTH        : string  := "OPTIMIZED";
            CLKIN1_PERIOD    : real    := 0.0;
            DIVCLK_DIVIDE    : integer := 1;
            CLKFBOUT_MULT_F  : real    := 5.0;
            CLKOUT0_DIVIDE_F : real    := 1.0;
            CLKOUT1_DIVIDE   : integer := 1;
            STARTUP_WAIT     : boolean := FALSE
        );
        port (
            CLKIN1   : in  std_logic;
            CLKFBIN  : in  std_logic;
            CLKFBOUT : out std_logic;
            CLKOUT0  : out std_logic;
            CLKOUT1  : out std_logic;
            LOCKED   : out std_logic;
            PWRDWN   : in  std_logic;
            RST      : in  std_logic
        );
    end component;

    component BUFG is
        port (I : in std_logic; O : out std_logic);
    end component;

    component OBUFDS is
        port (I : in std_logic; O : out std_logic; OB : out std_logic);
    end component;

    component OSERDESE2 is
        generic (
            DATA_RATE_OQ   : string  := "DDR";
            DATA_RATE_TQ   : string  := "DDR";
            DATA_WIDTH     : integer := 4;
            SERDES_MODE    : string  := "MASTER";
            TRISTATE_WIDTH : integer := 4
        );
        port (
            OQ, OFB, TQ, TFB, SHIFTOUT1, SHIFTOUT2, TBYTEOUT : out std_logic;
            CLK, CLKDIV : in std_logic;
            D1, D2, D3, D4, D5, D6, D7, D8 : in std_logic;
            OCE, RST, SHIFTIN1, SHIFTIN2 : in std_logic;
            T1, T2, T3, T4, TBYTEIN, TCE : in std_logic
        );
    end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
entity MMCME2_BASE is
    generic (
        BANDWIDTH        : string  := "OPTIMIZED";
        CLKIN1_PERIOD    : real    := 0.0;
        DIVCLK_DIVIDE    : integer := 1;
        CLKFBOUT_MULT_F  : real    := 5.0;
        CLKOUT0_DIVIDE_F : real    := 1.0;
        CLKOUT1_DIVIDE   : integer := 1;
        STARTUP_WAIT     : boolean := FALSE
    );
    port (
        CLKIN1   : in  std_logic;
        CLKFBIN  : in  std_logic;
        CLKFBOUT : out std_logic;
        CLKOUT0  : out std_logic;
        CLKOUT1  : out std_logic;
        LOCKED   : out std_logic;
        PWRDWN   : in  std_logic;
        RST      : in  std_logic
    );
end entity;
architecture stub of MMCME2_BASE is
begin
    CLKFBOUT <= CLKIN1;
    CLKOUT0  <= CLKIN1;
    CLKOUT1  <= CLKIN1;
    LOCKED   <= not RST;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
entity BUFG is
    port (I : in std_logic; O : out std_logic);
end entity;
architecture stub of BUFG is
begin
    O <= I;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
entity OBUFDS is
    port (I : in std_logic; O : out std_logic; OB : out std_logic);
end entity;
architecture stub of OBUFDS is
begin
    O  <= I;
    OB <= not I;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
entity OSERDESE2 is
    generic (
        DATA_RATE_OQ   : string  := "DDR";
        DATA_RATE_TQ   : string  := "DDR";
        DATA_WIDTH     : integer := 4;
        SERDES_MODE    : string  := "MASTER";
        TRISTATE_WIDTH : integer := 4
    );
    port (
        OQ, OFB, TQ, TFB, SHIFTOUT1, SHIFTOUT2, TBYTEOUT : out std_logic;
        CLK, CLKDIV : in std_logic;
        D1, D2, D3, D4, D5, D6, D7, D8 : in std_logic;
        OCE, RST, SHIFTIN1, SHIFTIN2 : in std_logic;
        T1, T2, T3, T4, TBYTEIN, TCE : in std_logic
    );
end entity;
architecture stub of OSERDESE2 is
begin
    OQ <= '0'; OFB <= '0'; TQ <= '0'; TFB <= '0';
    SHIFTOUT1 <= '0'; SHIFTOUT2 <= '0'; TBYTEOUT <= '0';
end architecture;
