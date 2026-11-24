"""Model referensi renderer PL: warna setiap piksel HANYA dari nilai register.

Ini spesifikasi gambar untuk renderer VHDL (anggota E). Aturannya ditulis
per piksel, tanpa framebuffer, persis seperti yang harus dilakukan hardware.
Simulasi VHDL harus menghasilkan .ppm yang identik dengan file dari sini
(bandingkan dengan tools/compare_ppm.py).

Pemakaian:
  python tools/ref_render.py regs.txt out.ppm [--frame N] [--png out.png]

regs.txt = keluaran sw/game/game_regs (satu baris per frame:
"<frame> <reg0x00> ... <reg0x7C>" dalam hex). Tanpa --frame dipakai baris
terakhir.

Aturan per piksel (x, y), prioritas depan -> belakang:
  0. CTRL.enable = 0                     -> hitam
  1. teks (font angka 8x16 di tools/assets.py; "lit(c, r)" = bit font menyala):
       skor   : tampil bila TEXT_ID = 0 (main) atau 5 (game over).
                n = jumlah digit bermakna SCORE (1..4, nol di depan tidak tampil)
                kotak x0 = 320 - 8n, y0 = 30, lebar 16n, tinggi 32 (skala 2x)
                digit ke-k dari kiri = nibble BCD (n-1-k); kolom (cx mod 16)>>1, baris cy>>1
       hitung : tampil bila COUNTDOWN != 0. Satu digit di x0 = 304, y0 = 160,
                32x64 (skala 4x); kolom cx>>2, baris cy>>2
       teks lit di (x, y)           -> PAL 15
       tidak lit, tapi lit di (x-2, y-2) -> PAL 12 (bayangan)
  2. burung: BIRD_ATTR.visible, bx <= x < bx+32, by <= y < by+32
       idx = BIRD_ART[frame][(y-by)>>1][(x-bx)>>1]; idx 0 = transparan
       BIRD_ATTR.flash -> semua piksel tidak transparan memakai indeks 4
  3. lantai: y >= 416
       y-416 < 8 -> PAL 9; selain itu bit 4 dari (x + (SCROLL_X & 31) + (y-416))
       0 -> PAL 10, 1 -> PAL 11
  4. pipa (PIPE3 dulu, lalu 2, 1, 0; yang pertama kena menang), bila visible:
       tutup: px-4 <= x < px+w+4 dan (gap-20 <= y < gap atau gap+gh <= y < gap+gh+20)
              tepi 2 px kotak tutup -> PAL 8, dalam -> PAL 6
       batang: px <= x < px+w dan (y < gap atau gap+gh <= y < 416)
              tepi 2 px kotak batang (atas [0,gap) / bawah [gap+gh,416)) -> PAL 8
              px+6 <= x < px+14 -> PAL 7, lainnya -> PAL 6
  5. langit: pita b = y >> 3, warna = PALETTE[14] + (2b, b + (b>>2), b>>1)
       per kanal, dijenuhkan ke 255
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import assets as A  # noqa: E402
import game_model as gm  # noqa: E402

W, H = gm.SCREEN_W, gm.SCREEN_H
GROUND_Y = gm.GROUND_Y
REG_COUNT = 32

# Indeks palet (sama dengan PAL_* di sw/game/regs.h)
PAL_EYE = A.PAL_EYE
PAL_PIPE, PAL_PIPE_LIGHT, PAL_PIPE_DARK = A.PAL_PIPE, A.PAL_PIPE_LIGHT, A.PAL_PIPE_DARK
PAL_GROUND_TOP, PAL_GROUND_A, PAL_GROUND_B = A.PAL_GROUND_TOP, A.PAL_GROUND_A, A.PAL_GROUND_B
PAL_SKY_BASE = A.PAL_SKY_BASE
BIRD_IDX = A.BIRD_IDX


def decode(regs):
    """Pecah 32 word register menjadi field (sama dengan gfx_regs_t)."""
    def r(off):
        return regs[off // 4]

    def signed11(v):
        v &= 0x7FF
        return v - 0x800 if v & 0x400 else v

    pipes = []
    for i in range(4):
        v = r(0x10 + 4 * i)
        pipes.append({"x": signed11(v), "gap": (v >> 12) & 0x1FF, "visible": bool(v >> 31)})
    cfg = r(0x20)
    attr = r(0x0C)
    pos = r(0x08)
    return {
        "enable": bool(r(0x00) & 1),
        "bird_x": pos & 0x3FF, "bird_y": (pos >> 16) & 0x3FF,
        "bird_frame": attr & 3, "bird_visible": bool(attr & 4), "bird_flash": bool(attr & 8),
        "pipes": pipes, "gap_h": cfg & 0x1FF, "pipe_w": (cfg >> 9) & 0x7F,
        "scroll": r(0x24) & 0x3FF,
        "score": r(0x28) & 0xFFFF, "text_id": r(0x2C) & 0xF, "countdown": r(0x30) & 0xF,
        "palette": [((v >> 16) & 255, (v >> 8) & 255, v & 255)
                    for v in (r(0x40 + 4 * i) for i in range(16))],
    }


def sky_rgb(y, base):
    b = y >> 3
    return (min(255, base[0] + 2 * b), min(255, base[1] + b + (b >> 2)), min(255, base[2] + (b >> 1)))


def in_border(x, y, x0, y0, x1, y1):
    """(x, y) di tepi 2 px kotak [x0, x1) x [y0, y1)."""
    return x < x0 + 2 or x >= x1 - 2 or y < y0 + 2 or y >= y1 - 2


def pipe_index(f, x, y):
    w, gh = f["pipe_w"], f["gap_h"]
    for p in reversed(f["pipes"]):
        if not p["visible"]:
            continue
        px, gap = p["x"], p["gap"]
        # tutup
        if px - 4 <= x < px + w + 4:
            for cy in (gap - 20, gap + gh):
                if cy <= y < cy + 20:
                    return PAL_PIPE_DARK if in_border(x, y, px - 4, cy, px + w + 4, cy + 20) else PAL_PIPE
        # batang
        if px <= x < px + w:
            for top, bot in ((0, gap), (gap + gh, GROUND_Y)):
                if top <= y < bot:
                    if in_border(x, y, px, top, px + w, bot):
                        return PAL_PIPE_DARK
                    return PAL_PIPE_LIGHT if px + 6 <= x < px + 14 else PAL_PIPE
    return None


def text_lit(f, x, y):
    """Apakah piksel (x, y) termasuk goresan teks (tanpa bayangan)."""
    if f["text_id"] in (0, 5):
        bcd = f["score"]
        n = 4 if bcd >> 12 else 3 if bcd >> 8 else 2 if bcd >> 4 else 1
        x0, y0 = 320 - 8 * n, A.SCORE_Y
        cx, cy = x - x0, y - y0
        if 0 <= cx < 16 * n and 0 <= cy < 32:
            k = cx >> 4
            digit = (bcd >> (4 * (n - 1 - k))) & 0xF
            if digit <= 9 and A.font_bit(digit, (cx & 15) >> 1, cy >> 1):
                return True
    cd = f["countdown"]
    if cd:
        cx, cy = x - A.COUNT_X, y - A.COUNT_Y
        if 0 <= cx < 32 and 0 <= cy < 64 and cd <= 9 and A.font_bit(cd, cx >> 2, cy >> 2):
            return True
    return False


def pixel(f, x, y, text=True):
    pal = f["palette"]
    if not f["enable"]:
        return (0, 0, 0)
    if text:
        if text_lit(f, x, y):
            return pal[A.PAL_TEXT]
        if text_lit(f, x - A.SHADOW, y - A.SHADOW):
            return pal[A.PAL_TEXT_SHADOW]
    bx, by = f["bird_x"], f["bird_y"]
    if f["bird_visible"] and bx <= x < bx + 32 and by <= y < by + 32:
        idx = BIRD_IDX[f["bird_frame"]][(y - by) >> 1][(x - bx) >> 1]
        if idx:
            return pal[PAL_EYE if f["bird_flash"] else idx]
    if y >= GROUND_Y:
        gy = y - GROUND_Y
        if gy < 8:
            return pal[PAL_GROUND_TOP]
        return pal[PAL_GROUND_B if ((x + (f["scroll"] & 31) + gy) >> 4) & 1 else PAL_GROUND_A]
    idx = pipe_index(f, x, y)
    if idx is not None:
        return pal[idx]
    return sky_rgb(y, pal[PAL_SKY_BASE])


def render(regs, text=True):
    """Kembalikan bytes RGB 640x480 (baris demi baris). text=False melewati
    layer teks (untuk dibandingkan dengan draw_world pygame yang tanpa teks)."""
    f = decode(regs)
    out = bytearray()
    for y in range(H):
        for x in range(W):
            out += bytes(pixel(f, x, y, text))
    return bytes(out)


def write_ppm(path, rgb):
    with open(path, "w", newline="\n") as fh:
        fh.write(f"P3\n{W} {H}\n255\n")
        for i in range(0, len(rgb), 3):
            fh.write(f"{rgb[i]} {rgb[i + 1]} {rgb[i + 2]}\n")


def save_png(path, rgb):
    os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
    import pygame
    pygame.image.save(pygame.image.frombytes(rgb, (W, H), "RGB"), path)


def parse_regs_line(line):
    tok = line.split()
    if len(tok) != 1 + REG_COUNT:
        raise ValueError(f"baris register harus {1 + REG_COUNT} kolom, dapat {len(tok)}")
    return int(tok[0]), [int(t, 16) for t in tok[1:]]


def main():
    args = sys.argv[1:]
    frame, png = None, None
    if "--frame" in args:
        i = args.index("--frame")
        frame = int(args[i + 1])
        del args[i:i + 2]
    if "--png" in args:
        i = args.index("--png")
        png = args[i + 1]
        del args[i:i + 2]
    if len(args) != 2:
        raise SystemExit(__doc__)
    chosen = None
    with open(args[0], encoding="utf-8") as fh:
        for line in fh:
            if line.strip():
                n, regs = parse_regs_line(line)
                chosen = (n, regs)
                if frame is not None and n == frame:
                    break
    if chosen is None or (frame is not None and chosen[0] != frame):
        raise SystemExit(f"frame {frame} tidak ada di {args[0]}")
    rgb = render(chosen[1])
    write_ppm(args[1], rgb)
    if png:
        save_png(png, rgb)
    print(f"frame {chosen[0]} -> {args[1]}")


if __name__ == "__main__":
    main()
