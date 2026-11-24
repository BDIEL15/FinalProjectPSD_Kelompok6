"""Tulis hw/vhdl/render/assets_pkg.vhd dari tools/assets.py.

  python tools/gen_vhdl_assets.py           tulis ulang file VHDL
  python tools/gen_vhdl_assets.py --check   gagal (kode 1) bila file VHDL basi

File VHDL hasilnya JANGAN diedit tangan: ubah tools/assets.py lalu jalankan ini.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import assets as A  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "hw", "vhdl", "render", "assets_pkg.vhd")


def wrap(items, per_line, indent="        "):
    lines = []
    for i in range(0, len(items), per_line):
        lines.append(indent + ", ".join(items[i:i + per_line]))
    return ",\n".join(lines)


def generate():
    bird = [f'x"{v:X}"' for f in A.BIRD_IDX for row in f for v in row]
    font = [f'x"{m:02X}"' for g in A.FONT for m in g]
    pal = [f'x"{r:02X}{g:02X}{b:02X}"' for r, g, b in A.PALETTE]
    return f"""-- assets_pkg.vhd -- DIHASILKAN OTOMATIS oleh tools/gen_vhdl_assets.py dari
-- tools/assets.py. JANGAN DIEDIT TANGAN: ubah assets.py lalu jalankan ulang.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gfx_pkg.all;

package assets_pkg is
    -- Sprite burung: indeks = frame*256 + baris*16 + kolom (16x16, skala 2x di layar)
    type bird_rom_t is array (0 to 1023) of unsigned(3 downto 0);
    constant BIRD_ROM : bird_rom_t := (
{wrap(bird, 16)});

    -- Font angka 8x16: indeks = digit*16 + baris; bit c = kolom c (0 = kiri)
    type font_rom_t is array (0 to 159) of std_logic_vector(7 downto 0);
    constant FONT_ROM : font_rom_t := (
{wrap(font, 16)});

    -- Palet default (nilai awal register PALETTE0..15)
    constant DEFAULT_PALETTE : palette_t := (
{wrap(pal, 4)});

    -- Indeks palet dan tata letak teks (sama dengan tools/assets.py)
    constant PAL_EYE         : natural := {A.PAL_EYE};
    constant PAL_PIPE        : natural := {A.PAL_PIPE};
    constant PAL_PIPE_LIGHT  : natural := {A.PAL_PIPE_LIGHT};
    constant PAL_PIPE_DARK   : natural := {A.PAL_PIPE_DARK};
    constant PAL_GROUND_TOP  : natural := {A.PAL_GROUND_TOP};
    constant PAL_GROUND_A    : natural := {A.PAL_GROUND_A};
    constant PAL_GROUND_B    : natural := {A.PAL_GROUND_B};
    constant PAL_TEXT_SHADOW : natural := {A.PAL_TEXT_SHADOW};
    constant PAL_TEXT        : natural := {A.PAL_TEXT};
    constant SCORE_Y         : natural := {A.SCORE_Y};
    constant COUNT_X         : natural := {A.COUNT_X};
    constant COUNT_Y         : natural := {A.COUNT_Y};
    constant TEXT_SHADOW     : natural := {A.SHADOW};
end package;
"""


def main():
    text = generate()
    if sys.argv[1:] == ["--check"]:
        try:
            with open(OUT, encoding="utf-8") as f:
                cur = f.read()
        except FileNotFoundError:
            cur = ""
        if cur.replace("\r\n", "\n") != text:
            print("[FAIL] hw/vhdl/render/assets_pkg.vhd basi: jalankan python tools/gen_vhdl_assets.py")
            return 1
        print("[PASS] assets_pkg.vhd sesuai tools/assets.py")
        return 0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"ditulis {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
