"""Model referensi encoder TMDS (DVI 1.0 §3.2) untuk hw/vhdl/system/tmds_encoder.vhd.

  python tools/ref_tmds.py --selftest              cek model: decode(encode(x)) == x,
                                                    disparitas berjalan terbatas
  python tools/ref_tmds.py --gen N stim.txt exp.txt  buat stimulus acak + keluaran
                                                    yang diharapkan untuk tb_tmds.vhd

Format stim.txt per baris: "<de> <c 0..3> <d 0..255>"
Format exp.txt per baris : "<q 0..1023>"   (keluaran encoder untuk baris yang sama)
"""

import random
import sys

CTRL = {0: 0b1101010100, 1: 0b0010101011, 2: 0b0101010100, 3: 0b1010101011}


class Encoder:
    def __init__(self):
        self.cnt = 0

    def step(self, de, c, d):
        if not de:
            self.cnt = 0
            return CTRL[c]
        bits = [(d >> i) & 1 for i in range(8)]
        n1d = sum(bits)
        qm = [bits[0]]
        if n1d > 4 or (n1d == 4 and bits[0] == 0):
            for i in range(1, 8):
                qm.append(1 - (qm[i - 1] ^ bits[i]))
            qm.append(0)
        else:
            for i in range(1, 8):
                qm.append(qm[i - 1] ^ bits[i])
            qm.append(1)
        n1q = sum(qm[:8])
        n0q = 8 - n1q
        low = sum(b << i for i, b in enumerate(qm[:8]))
        inv = (~low) & 0xFF
        if self.cnt == 0 or n1q == n0q:
            q9, q8 = 1 - qm[8], qm[8]
            if qm[8]:
                q7_0 = low
                self.cnt += n1q - n0q
            else:
                q7_0 = inv
                self.cnt += n0q - n1q
        elif (self.cnt > 0 and n1q > n0q) or (self.cnt < 0 and n0q > n1q):
            q9, q8, q7_0 = 1, qm[8], inv
            self.cnt += 2 * qm[8] + n0q - n1q
        else:
            q9, q8, q7_0 = 0, qm[8], low
            self.cnt += -2 * (1 - qm[8]) + n1q - n0q
        return (q9 << 9) | (q8 << 8) | q7_0


def decode(q):
    """Decoder TMDS (sisi monitor), dipakai untuk membuktikan encoder benar."""
    for c, code in CTRL.items():
        if q == code:
            return ("ctrl", c)
    low = q & 0xFF
    if q >> 9 & 1:
        low = ~low & 0xFF
    bits = [(low >> i) & 1 for i in range(8)]
    d = [bits[0]]
    for i in range(1, 8):
        if q >> 8 & 1:
            d.append(bits[i] ^ bits[i - 1])
        else:
            d.append(1 - (bits[i] ^ bits[i - 1]))
    return ("data", sum(b << i for i, b in enumerate(d)))


def stimulus(n, seed=1):
    rng = random.Random(seed)
    out = []
    for i in range(n):
        # blok data panjang (seperti satu baris video) diselingi blanking
        de = 0 if (i % 100) >= 80 else 1
        out.append((de, rng.randrange(4), rng.randrange(256)))
    for v in range(256):            # semua nilai byte, berurutan
        out.append((1, 0, v))
    return out


def selftest():
    enc = Encoder()
    worst, ok = 0, True
    for de, c, d in stimulus(20000):
        q = enc.step(de, c, d)
        kind, val = decode(q)
        if de and (kind != "data" or val != d):
            print(f"[FAIL] decode salah: d={d} q={q:010b} -> {kind} {val}")
            ok = False
            break
        if not de and (kind != "ctrl" or val != c):
            print(f"[FAIL] kode kontrol salah: c={c} q={q:010b}")
            ok = False
            break
        worst = max(worst, abs(enc.cnt))
    if worst > 8:
        print(f"[FAIL] disparitas berjalan {worst} > 8")
        ok = False
    print(f"[{'PASS' if ok else 'FAIL'}] TMDS encode->decode identik, disparitas maks {worst}")
    return 0 if ok else 1


def gen(n, stim_path, exp_path):
    enc = Encoder()
    with open(stim_path, "w", newline="\n") as fs, open(exp_path, "w", newline="\n") as fe:
        for de, c, d in stimulus(n):
            fs.write(f"{de} {c} {d}\n")
            fe.write(f"{enc.step(de, c, d)}\n")
    return 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--selftest"]:
        sys.exit(selftest())
    if len(a) == 4 and a[0] == "--gen":
        sys.exit(gen(int(a[1]), a[2], a[3]))
    raise SystemExit(__doc__)
