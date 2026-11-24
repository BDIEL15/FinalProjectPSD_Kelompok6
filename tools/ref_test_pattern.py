"""Model referensi test_pattern.v (harus sama persis dengan rumus di HDL).

Pemakaian:
  python tools/ref_test_pattern.py <mode> <jumlah_update_kotak> <out.ppm>
"""

import sys

W, H = 640, 480
BOX, BOX_X0, BOX_Y0, BOX_DX, BOX_DY = 32, 100, 50, 3, 2

BARS = [(255, 255, 255), (255, 255, 0), (0, 255, 255), (0, 255, 0),
        (255, 0, 255), (255, 0, 0), (0, 0, 255), (0, 0, 0)]


def box_pos(updates):
    """Posisi kotak setelah n kali update (sekali per vblank)."""
    x, y, dx, dy = BOX_X0, BOX_Y0, 0, 0   # dir 0 = kanan/bawah
    xmax, ymax = W - BOX, H - BOX
    for _ in range(updates):
        if dx == 0:
            x, dx = (xmax, 1) if x + BOX_DX >= xmax else (x + BOX_DX, 0)
        else:
            x, dx = (0, 0) if x <= BOX_DX else (x - BOX_DX, 1)
        if dy == 0:
            y, dy = (ymax, 1) if y + BOX_DY >= ymax else (y + BOX_DY, 0)
        else:
            y, dy = (0, 0) if y <= BOX_DY else (y - BOX_DY, 1)
    return x, y


def pixel(mode, x, y, box):
    if mode == 0:
        return BARS[x // 80]
    if mode == 1:
        if x in (0, W - 1) or y in (0, H - 1):
            return (255, 0, 0)
        if x % 32 == 0 or y % 32 == 0:
            return (255, 255, 255)
        return (0x10, 0x18, 0x50)
    if mode == 2:
        bx, by = box
        if bx <= x < bx + BOX and by <= y < by + BOX:
            return (0xFF, 0xD0, 0x20)
        grey = (x >> 2) & 0xFF
        return (grey, grey, grey)
    return (0, 0, 0)


def write_ppm(path, mode, updates):
    box = box_pos(updates)
    with open(path, "w", newline="\n") as f:
        f.write(f"P3\n{W} {H}\n255\n")
        for y in range(H):
            f.write("".join("%d %d %d\n" % pixel(mode, x, y, box) for x in range(W)))
    return box


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    box = write_ppm(sys.argv[3], int(sys.argv[1]), int(sys.argv[2]))
    print(f"referensi mode {sys.argv[1]} ditulis ke {sys.argv[3]} (kotak di {box})")
