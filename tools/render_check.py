"""Uji register -> gambar, ujung ke ujung tanpa board.

  game C (sw/game) --render_regs--> register --ref_render.py--> gambar A
  model Python (game_model.py)  --draw_world (pygame)-------> gambar B

A dan B harus identik piksel demi piksel (layer teks belum termasuk).
Ini membuktikan: (1) register map cukup untuk menggambar game utuh,
(2) render_regs.c memetakan keadaan game dengan benar, dan (3) aturan
ref_render.py sama dengan tampilan yang sudah dimainkan di PC.

  python tools/render_check.py           (butuh sw/game/game_regs, `make pc`)

Gambar setiap skenario disimpan ke sw/game/out/ (PNG) untuk dilihat.
"""

import os
import subprocess
import sys
import tempfile

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import game_model as gm  # noqa: E402
import ref_render as rr  # noqa: E402

FRAMES = 4000
OUT_DIR = os.path.join(ROOT, "sw", "game", "out")


def find_exe():
    for name in ("game_regs.exe", "game_regs"):
        path = os.path.join(ROOT, "sw", "game", name)
        if os.path.exists(path):
            return path
    sys.exit("game_regs belum di-build: jalankan `mingw32-make -C sw/game pc`")


def pick_frames(py_states):
    """Pilih frame yang mewakili tiap situasi penting (dari model Python)."""
    picks = {}

    def want(name, cond):
        if name not in picks:
            for f, st in py_states.items():
                if cond(st):
                    picks[name] = f
                    return

    w = gm.load_params(gm.DEFAULT_CONFIG)["pipe_width"]
    want("menu", lambda s: s["state"] == gm.MENU and s["frame"] > 5)
    want("countdown", lambda s: s["state"] == gm.COUNTDOWN and s["state_frame"] > 30)
    want("main-pipa-di-tepi-kiri",
         lambda s: s["state"] == gm.PLAY and any(-w < x // gm.FP < 0 for x in s["pipe_x"]))
    want("main-pipa-di-tepi-kanan",
         lambda s: s["state"] == gm.PLAY and any(600 < x // gm.FP < 640 for x in s["pipe_x"]))
    want("burung-di-atap", lambda s: s["state"] == gm.PLAY and s["bird_y"] == 0)
    want("game-over", lambda s: s["state"] == gm.GAME_OVER and s["state_frame"] > 40)
    return picks


def main():
    import pygame
    pygame.init()
    pygame.display.set_mode((1, 1))
    exe = find_exe()
    params = gm.load_params(gm.DEFAULT_CONFIG)
    os.makedirs(OUT_DIR, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        presses_path = os.path.join(tmp, "presses.txt")
        gm.run_trace(params, FRAMES, os.path.join(tmp, "py.csv"), presses_path)
        with open(presses_path, encoding="utf-8") as fh:
            presses = [int(x) for x in fh.read().split()]
        out = subprocess.run(
            [exe, gm.DEFAULT_CONFIG, presses_path, str(FRAMES),
             str(gm.TRACE_LATENCY_MS), str(gm.TRACE_MIN_INTERVAL_MS)],
            capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit(f"game_regs gagal: {out.stderr.strip()}")
    c_regs = {}
    for line in out.stdout.splitlines():
        n, regs = rr.parse_regs_line(line)
        c_regs[n] = regs

    # Putar ulang model Python dengan urutan tekan yang sama; simpan salinan
    # keadaan di tiap frame (kecil) lalu gambar hanya frame terpilih.
    g = gm.Game(dict(params, input_latency_ms=gm.TRACE_LATENCY_MS,
                     min_flap_interval_ms=gm.TRACE_MIN_INTERVAL_MS))
    pending = list(presses)
    py_states, snaps = {}, {}
    import copy
    for _ in range(FRAMES):
        while pending and pending[0] == g.frame:
            g.press()
            pending.pop(0)
        g.step()
        py_states[g.frame] = {"state": g.state, "state_frame": g.state_frame,
                              "bird_y": g.bird_y, "frame": g.frame,
                              "pipe_x": [q.x for q in g.pipes]}
        snaps[g.frame] = copy.deepcopy(g)

    picks = pick_frames(py_states)
    art = gm.build_art(pygame)
    surf = pygame.Surface((rr.W, rr.H))
    ok = True
    for name, f in picks.items():
        ref = rr.render(c_regs[f])
        gm.draw_world(surf, snaps[f], art)
        py = pygame.image.tobytes(surf, "RGB")
        rr.save_png(os.path.join(OUT_DIR, f"{name}.png"), ref)
        if ref == py:
            print(f"[PASS] {name} (frame {f})")
            continue
        ok = False
        n_diff = sum(1 for i in range(0, len(ref), 3) if ref[i:i + 3] != py[i:i + 3])
        i = next(i for i in range(0, len(ref), 3) if ref[i:i + 3] != py[i:i + 3]) // 3
        print(f"[FAIL] {name} (frame {f}): {n_diff} piksel beda; pertama di "
              f"x={i % rr.W} y={i // rr.W}: ref_render={tuple(ref[3 * i:3 * i + 3])} "
              f"pygame={tuple(py[3 * i:3 * i + 3])}")
        rr.save_png(os.path.join(OUT_DIR, f"{name}-pygame.png"), py)
    missing = {"menu", "countdown", "main-pipa-di-tepi-kiri", "main-pipa-di-tepi-kanan",
               "burung-di-atap", "game-over"} - set(picks)
    if missing:
        print(f"[FAIL] skenario tidak muncul dalam {FRAMES} frame: {sorted(missing)}")
        ok = False
    print(f"RENDER CHECK {'PASS' if ok else 'FAIL'} (gambar di {os.path.relpath(OUT_DIR, ROOT)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
