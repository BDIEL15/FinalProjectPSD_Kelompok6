"""Bandingkan dua file PPM (P3) piksel per piksel.

Pemakaian:
  python tools/compare_ppm.py hasil_sim.ppm referensi.ppm [--png hasil_sim.png]

Keluar dengan kode 0 jika identik. --png menyimpan gambar pertama sebagai PNG
(butuh pygame/pygame-ce) agar mudah dilihat atau ditempel di laporan.
"""

import sys


def read_ppm(path):
    with open(path) as f:
        tokens = f.read().split()
    if tokens[0] != "P3":
        raise ValueError(f"{path}: bukan PPM P3")
    w, h, maxv = int(tokens[1]), int(tokens[2]), int(tokens[3])
    vals = list(map(int, tokens[4:]))
    if len(vals) != w * h * 3:
        raise ValueError(f"{path}: jumlah piksel {len(vals) // 3}, seharusnya {w * h}")
    px = [tuple(vals[i:i + 3]) for i in range(0, len(vals), 3)]
    return w, h, px


def save_png(path, w, h, px):
    import os
    os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
    import pygame
    surf = pygame.Surface((w, h))
    for i, c in enumerate(px):
        surf.set_at((i % w, i // w), c)
    pygame.image.save(surf, path)


def main():
    args = sys.argv[1:]
    png = None
    if "--png" in args:
        i = args.index("--png")
        png = args[i + 1]
        del args[i:i + 2]
    if len(args) != 2:
        raise SystemExit(__doc__)

    wa, ha, a = read_ppm(args[0])
    wb, hb, b = read_ppm(args[1])
    if (wa, ha) != (wb, hb):
        print(f"[FAIL] ukuran beda: {wa}x{ha} vs {wb}x{hb}")
        sys.exit(1)

    diff = [i for i in range(len(a)) if a[i] != b[i]]
    if png:
        save_png(png, wa, ha, a)
    if diff:
        i = diff[0]
        print(f"[FAIL] {args[0]}: {len(diff)} piksel beda; pertama di "
              f"x={i % wa} y={i // wa}: sim={a[i]} ref={b[i]}")
        sys.exit(1)
    print(f"[PASS] {args[0]} identik dengan referensi ({wa}x{ha})")


if __name__ == "__main__":
    main()
