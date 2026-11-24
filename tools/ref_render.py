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
  1. teks/skor                           -> BELUM (v1 tanpa layer teks)
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
import game_model as gm  # noqa: E402

W, H = gm.SCREEN_W, gm.SCREEN_H
GROUND_Y = gm.GROUND_Y
REG_COUNT = 32

# Indeks palet (sama dengan PAL_* di sw/game/regs.h)
PAL_OUTLINE, PAL_BIRD, PAL_BEAK, PAL_EYE, PAL_WING = 1, 2, 3, 4, 5
PAL_PIPE, PAL_PIPE_LIGHT, PAL_PIPE_DARK = 6, 7, 8
PAL_GROUND_TOP, PAL_GROUND_A, PAL_GROUND_B = 9, 10, 11
PAL_SKY_BASE = 14
ART_INDEX = {"k": PAL_OUTLINE, "y": PAL_BIRD, "o": PAL_BEAK, "w": PAL_EYE, "l": PAL_WING}

# 4 frame x 16 baris x 16 kolom indeks palet (dasar bird.mem untuk BRAM)
BIRD_IDX = [[[ART_INDEX.get(ch, 0) for ch in row] for row in gm.bird_art_frame(f)]
            for f in range(4)]


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


def pixel(f, x, y):
    pal = f["palette"]
    if not f["enable"]:
        return (0, 0, 0)
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


def render(regs):
    """Kembalikan bytes RGB 640x480 (baris demi baris)."""
    f = decode(regs)
    out = bytearray()
    for y in range(H):
        for x in range(W):
            out += bytes(pixel(f, x, y))
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
