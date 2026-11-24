"""Buat skenario uji renderer VHDL: isi register + gambar referensi.

  python tools/render_scenarios.py <folder>

Untuk tiap skenario menulis <nama>.regs (satu baris register, format
sw/game/game_regs) dan <nama>.ref.ppm (tools/ref_render.py, dengan teks).
sim/vhdl/tb_renderer.vhd membaca .regs, menggambar satu frame, lalu
sim/run_vhdl.ps1 membandingkannya dengan .ref.ppm.

Skenario = 6 frame dari permainan sungguhan (render_check.py) + beberapa
register yang diubah tangan untuk kasus tepi yang jarang muncul saat main.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import ref_render as rr  # noqa: E402
import render_check as rc  # noqa: E402

REG_CTRL, REG_BIRD_ATTR, REG_PIPE0, REG_SCORE, REG_TEXT_ID, REG_COUNTDOWN = 0, 3, 4, 10, 11, 12
REG_PAL_SKY = 16 + 14


def pipe_word(x, gap, visible=True):
    return (x & 0x7FF) | ((gap & 0x1FF) << 12) | (int(visible) << 31)


def synthetic(base_play, base_count):
    """Kasus tepi dari register frame main / hitung mundur."""
    out = {}

    r = list(base_play)
    r[REG_SCORE], r[REG_TEXT_ID] = 0x1234, 0
    out["skor-1234"] = r

    r = list(base_play)
    r[REG_SCORE], r[REG_TEXT_ID] = 0x0090, 5          # nol di tengah/akhir, game over
    out["skor-90-game-over"] = r

    r = list(base_play)
    r[REG_BIRD_ATTR] |= 0x8                            # flash
    r[REG_PAL_SKY] = 0x101848                          # langit malam
    out["flash-malam"] = r

    r = list(base_play)                                # pipa di batas visible
    r[REG_PIPE0 + 0] = pipe_word(-67, 40)
    r[REG_PIPE0 + 1] = pipe_word(643, 206)
    r[REG_PIPE0 + 2] = pipe_word(300, 120)
    r[REG_PIPE0 + 3] = pipe_word(200, 100, visible=False)
    out["pipa-batas"] = r

    r = list(base_count)
    r[REG_COUNTDOWN] = 1
    out["countdown-1"] = r

    r = list(base_play)
    r[REG_CTRL] = 0                                    # enable = 0 -> hitam
    out["disable"] = r
    return out


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    folder = sys.argv[1]
    os.makedirs(folder, exist_ok=True)
    c_regs, picks, _ = rc.collect()
    missing = set(rc.SCENARIOS) - set(picks)
    if missing:
        sys.exit(f"skenario tidak muncul: {sorted(missing)}")
    scen = {name: c_regs[f] for name, f in picks.items()}
    scen.update(synthetic(scen["main-pipa-di-tepi-kiri"], scen["countdown"]))
    for name, regs in scen.items():
        with open(os.path.join(folder, f"{name}.regs"), "w", newline="\n") as fh:
            fh.write("0 " + " ".join(f"{v:08X}" for v in regs) + "\n")
        rr.write_ppm(os.path.join(folder, f"{name}.ref.ppm"), rr.render(regs))
    print(f"{len(scen)} skenario ditulis ke {folder}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
