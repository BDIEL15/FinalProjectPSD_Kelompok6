"""Sumber tunggal aset grafis renderer: palet, sprite burung, font angka.

Dipakai oleh tools/ref_render.py (model referensi) dan
tools/gen_vhdl_assets.py (menulis hw/vhdl/render/assets_pkg.vhd).
Ubah aset HANYA di sini, lalu jalankan `python tools/gen_vhdl_assets.py`.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import game_model as gm  # noqa: E402

# --- palet default 16 warna; indeks sama dengan PAL_* di sw/game/regs.h ---------
PALETTE = [
    (0, 0, 0),          # 0  transparan (untuk sprite)
    gm.ART_COLORS["k"],  # 1  garis burung
    gm.ART_COLORS["y"],  # 2  badan burung
    gm.ART_COLORS["o"],  # 3  paruh
    gm.ART_COLORS["w"],  # 4  mata (juga warna flash)
    gm.ART_COLORS["l"],  # 5  sayap
    gm.PIPE_BODY,        # 6  pipa
    gm.PIPE_LIGHT,       # 7  pipa terang
    gm.PIPE_DARK,        # 8  pipa gelap / tepi
    gm.GROUND_TOP,       # 9  rumput
    gm.GROUND_A,         # 10 lantai A
    gm.GROUND_B,         # 11 lantai B
    (0, 0, 0),           # 12 bayangan teks
    (230, 60, 60),       # 13 cadangan
    gm.SKY_BASE,         # 14 dasar langit
    (255, 255, 255),     # 15 teks
]

PAL_OUTLINE, PAL_EYE = 1, 4
PAL_PIPE, PAL_PIPE_LIGHT, PAL_PIPE_DARK = 6, 7, 8
PAL_GROUND_TOP, PAL_GROUND_A, PAL_GROUND_B = 9, 10, 11
PAL_TEXT_SHADOW, PAL_SKY_BASE, PAL_TEXT = 12, 14, 15

# --- sprite burung: 4 frame x 16 baris x 16 kolom indeks palet (skala 2x di layar)
_ART_INDEX = {"k": 1, "y": 2, "o": 3, "w": 4, "l": 5}
BIRD_IDX = [[[_ART_INDEX.get(ch, 0) for ch in row] for row in gm.bird_art_frame(f)]
            for f in range(4)]

# --- font angka 8x16 (kolom 7 kosong = jarak antar digit). Baris 0-1 dan 13-15 kosong.
_DIGITS = {
    0: [".XXXXX..", "XX...XX.", "XX..XXX.", "XX.X.XX.", "XX.X.XX.", "XXX..XX.",
        "XX...XX.", "XX...XX.", "XX...XX.", "XX...XX.", ".XXXXX.."],
    1: ["...XX...", "..XXX...", ".XXXX...", "...XX...", "...XX...", "...XX...",
        "...XX...", "...XX...", "...XX...", "...XX...", ".XXXXXX."],
    2: [".XXXXX..", "XX...XX.", ".....XX.", ".....XX.", "....XX..", "...XX...",
        "..XX....", ".XX.....", "XX......", "XX......", "XXXXXXX."],
    3: [".XXXXX..", "XX...XX.", ".....XX.", ".....XX.", "..XXXX..", ".....XX.",
        ".....XX.", ".....XX.", ".....XX.", "XX...XX.", ".XXXXX.."],
    4: ["....XX..", "...XXX..", "..XXXX..", ".XX.XX..", "XX..XX..", "XX..XX..",
        "XXXXXXX.", "....XX..", "....XX..", "....XX..", "....XX.."],
    5: ["XXXXXXX.", "XX......", "XX......", "XX......", "XXXXXX..", ".....XX.",
        ".....XX.", ".....XX.", ".....XX.", "XX...XX.", ".XXXXX.."],
    6: ["..XXXX..", ".XX.....", "XX......", "XX......", "XXXXXX..", "XX...XX.",
        "XX...XX.", "XX...XX.", "XX...XX.", "XX...XX.", ".XXXXX.."],
    7: ["XXXXXXX.", ".....XX.", ".....XX.", "....XX..", "....XX..", "...XX...",
        "...XX...", "..XX....", "..XX....", "..XX....", "..XX...."],
    8: [".XXXXX..", "XX...XX.", "XX...XX.", "XX...XX.", ".XXXXX..", "XX...XX.",
        "XX...XX.", "XX...XX.", "XX...XX.", "XX...XX.", ".XXXXX.."],
    9: [".XXXXX..", "XX...XX.", "XX...XX.", "XX...XX.", "XX...XX.", ".XXXXXX.",
        ".....XX.", ".....XX.", ".....XX.", "....XX..", ".XXXX..."],
}
FONT_W, FONT_H = 8, 16


def _glyph(rows):
    assert len(rows) == 11 and all(len(r) == FONT_W for r in rows)
    full = ["." * FONT_W] * 2 + rows + ["." * FONT_W] * 3
    # bit c dari tiap baris = kolom c (kolom 0 = kiri)
    return [sum(1 << c for c, ch in enumerate(r) if ch == "X") for r in full]


FONT = [_glyph(_DIGITS[d]) for d in range(10)]   # FONT[digit][row] -> 8-bit mask


def font_bit(digit, col, row):
    return (FONT[digit][row] >> col) & 1


# --- tata letak teks (aturan renderer, lihat ref_render.py) ---------------------
SCORE_Y = 30            # skor: skala 2x (16x32 per digit), rata tengah
SCORE_SCALE = 2
COUNT_X, COUNT_Y = 304, 160   # hitung mundur: skala 4x (32x64), satu digit
COUNT_SCALE = 4
SHADOW = 2              # bayangan digeser 2 px ke kanan-bawah
