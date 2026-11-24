"""Uji jejak: model Python (tools/game_model.py) vs game C (sw/game/).

Kedua versi dijalankan dengan config dan urutan tekan yang sama, lalu
keadaan game dibandingkan baris per baris (satu baris = satu frame).

  python tools/trace_compare.py               (12.000 frame)
  python tools/trace_compare.py --frames 30000

Butuh sw/game/game_trace(.exe): build dulu dengan `mingw32-make -C sw/game pc`
(Windows) atau `make -C sw/game pc` (Linux/WSL).
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import game_model as gm  # noqa: E402

COLS = ["frame", "state", "state_frame", "bird_y", "bird_vy", "score", "scroll"] + [
    f"p{i}_{c}" for i in range(gm.PIPE_SLOTS) for c in ("x", "gap", "scored")]


def find_exe():
    for name in ("game_trace.exe", "game_trace"):
        path = os.path.join(ROOT, "sw", "game", name)
        if os.path.exists(path):
            return path
    sys.exit("game_trace belum di-build: jalankan `mingw32-make -C sw/game pc`")


# Variasi parameter "ganjil": posisi pipa tidak jatuh di piksel bulat, jadi
# pembagian negatif (floor vs truncate) dan pembulatan fixed-point ikut teruji.
ALT_OVERRIDES = {"pipe_speed": "1.37", "gravity": "0.137", "pipe_spacing": "277",
                 "gap_h": "163", "seed": "987"}


def write_alt_config(src, dst):
    with open(src, encoding="utf-8") as f:
        text = f.read()
    for key, val in ALT_OVERRIDES.items():
        text = re.sub(rf"(?m)^({re.escape(key)}\s*=\s*).*$", rf"\g<1>{val}", text)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)


def compare(exe, config, frames, tmp, label):
    py_csv = os.path.join(tmp, "py.csv")
    presses = os.path.join(tmp, "presses.txt")
    print(f"[{label}] ", end="")
    gm.run_trace(gm.load_params(config), frames, py_csv, presses)
    c_out = subprocess.run(
        [exe, config, presses, str(frames),
         str(gm.TRACE_LATENCY_MS), str(gm.TRACE_MIN_INTERVAL_MS)],
        capture_output=True, text=True)
    if c_out.returncode != 0:
        sys.exit(f"game_trace gagal: {c_out.stderr.strip()}")
    with open(py_csv, encoding="utf-8") as f:
        py_rows = f.read().splitlines()
    c_rows = c_out.stdout.splitlines()

    if len(py_rows) != len(c_rows):
        print(f"[{label}] TRACE BEDA: jumlah baris Python {len(py_rows)} vs C {len(c_rows)}")
        return False
    for py, c in zip(py_rows, c_rows):
        if py != c:
            pv, cv = py.split(","), c.split(",")
            print(f"[{label}] TRACE BEDA di frame {pv[0]}:")
            for i, (a, b) in enumerate(zip(pv, cv)):
                if a != b:
                    print(f"   {COLS[i]}: py={a} c={b}")
            return False
    print(f"[{label}] TRACE IDENTIK ({len(py_rows)} frame)")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=12000)
    ap.add_argument("--config", default=gm.DEFAULT_CONFIG)
    args = ap.parse_args()

    exe = find_exe()
    config = os.path.abspath(args.config)
    with tempfile.TemporaryDirectory() as tmp:
        alt = os.path.join(tmp, "alt.ini")
        write_alt_config(config, alt)
        ok = compare(exe, config, args.frames, tmp, "config.ini")
        ok &= compare(exe, alt, args.frames, tmp, "variasi")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
