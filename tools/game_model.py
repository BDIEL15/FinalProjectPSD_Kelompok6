"""Model PC game Jump-to-Flap.

Tujuan:
  1. Menala parameter (gravitasi, flap, kecepatan pipa, celah) agar cocok
     dengan ritme LOMPATAN manusia, sebelum ada board/kamera.
  2. Menjadi referensi logika yang nanti dipindah ke C di PS: update tetap
     60 Hz, fixed-point integer, RNG deterministik, maks 4 slot pipa
     (sesuai register map PIPE0..3).
  3. Menjadi referensi visual renderer PL: 640x480, langit gradien per pita
     baris, lantai bergulir, pipa procedural, burung 32x32 (16x16 skala 2x).

Pemakaian:
  python tools/game_model.py                 main (spasi = flap)
  python tools/game_model.py --bpm 70        metronom ritme lompatan
  python tools/game_model.py --latency 100   tunda flap 100 ms (latensi kamera)
  python tools/game_model.py --selftest      uji logika tanpa jendela
  python tools/trace_compare.py              uji jejak Python vs C (sw/game/)
"""

import argparse
import configparser
import math
import os
import re
import sys

# ---------------------------------------------------------------------------
# Konstanta layar (harus sama dengan renderer PL)
# ---------------------------------------------------------------------------
SCREEN_W, SCREEN_H = 640, 480
GROUND_Y = 416          # baris pertama lantai
BIRD_SIZE = 32
PIPE_SLOTS = 4          # = jumlah register PIPE0..3
PIPE_CAP_H = 20         # tinggi tutup pipa
PIPE_CAP_EXTRA = 4      # tutup lebih lebar 4 px tiap sisi
GAP_MARGIN = 40         # celah tidak boleh terlalu dekat atas/lantai
FPS = 60
FP = 256                # fixed-point: 1 piksel = 256 unit

DEFAULT_CONFIG = os.path.join(os.path.dirname(__file__), "..", "sw", "config.ini")

# key config -> (section, tipe)
PARAM_SPEC = {
    "gravity": ("physics", float),
    "flap_velocity": ("physics", float),
    "max_fall_speed": ("physics", float),
    "pipe_speed": ("pipes", float),
    "pipe_spacing": ("pipes", int),
    "gap_h": ("pipes", int),
    "pipe_width": ("pipes", int),
    "max_gap_delta": ("pipes", int),
    "seed": ("pipes", int),
    "bird_x": ("bird", int),
    "hitbox_margin": ("bird", int),
    "ceiling_kills": ("bird", int),
    "input_latency_ms": ("input", int),
    "min_flap_interval_ms": ("input", int),
}


def load_params(path):
    cp = configparser.ConfigParser(inline_comment_prefixes=(";", "#"))
    if not cp.read(path, encoding="utf-8"):
        raise SystemExit(f"config tidak ditemukan: {path}")
    params = {}
    for key, (section, typ) in PARAM_SPEC.items():
        params[key] = typ(cp[section][key])
    return params


def save_params(path, params):
    """Tulis nilai kembali ke config.ini tanpa menghapus komentar."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    for key, val in params.items():
        if isinstance(val, float):
            val = f"{val:.3f}".rstrip("0").rstrip(".")
        text = re.sub(rf"(?m)^({re.escape(key)}\s*=\s*).*$", rf"\g<1>{val}", text)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


# ---------------------------------------------------------------------------
# Logika game (tanpa pygame) -> nanti dipindah ke C di PS
# ---------------------------------------------------------------------------
MENU, COUNTDOWN, PLAY, GAME_OVER = "MENU", "COUNTDOWN", "PLAY", "GAME_OVER"
COUNTDOWN_FRAMES = 3 * FPS
GAME_OVER_LOCK_FRAMES = FPS // 2


class Rng:
    """LCG 31-bit; mudah ditulis ulang identik di C."""

    def __init__(self, seed):
        self.s = seed & 0x7FFFFFFF

    def next(self):
        self.s = (self.s * 1103515245 + 12345) & 0x7FFFFFFF
        return self.s >> 16


class Pipe:
    __slots__ = ("x", "gap_y", "scored")

    def __init__(self, x, gap_y):
        self.x = x            # fixed-point, tepi kiri batang
        self.gap_y = gap_y    # piksel, tepi atas celah
        self.scored = False


class Game:
    def __init__(self, params):
        self.p = params
        self.frame = 0            # penghitung frame global (animasi, lantai)
        self.scroll = 0           # fixed-point, untuk lantai (SCROLL_X = scroll // FP)
        self.events = []          # flap tertunda: frame jatuh tempo
        self.last_flap_frame = -10**9
        self.reset_to_menu()

    # -- turunan parameter ke fixed-point (dihitung ulang tiap frame agar
    #    penalaan live langsung berlaku)
    def _fp(self, key):
        return int(round(self.p[key] * FP))

    def reset_to_menu(self):
        self.state = MENU
        self.state_frame = 0
        self.score = 0
        self.bird_y = (GROUND_Y // 2 - BIRD_SIZE // 2) * FP
        self.bird_vy = 0
        self.rng = Rng(self.p["seed"])
        self.events.clear()
        self.pipes = []
        prev = (GROUND_Y - self.p["gap_h"]) // 2
        for i in range(PIPE_SLOTS):
            gap = self._next_gap(prev)
            self.pipes.append(Pipe((SCREEN_W + 100 + i * self.p["pipe_spacing"]) * FP, gap))
            prev = gap

    def _gap_limits(self):
        lo = GAP_MARGIN
        hi = GROUND_Y - GAP_MARGIN - self.p["gap_h"]
        return lo, max(lo, hi)

    def _next_gap(self, prev):
        lo, hi = self._gap_limits()
        d = self.p["max_gap_delta"]
        g = prev + (self.rng.next() % (2 * d + 1)) - d
        return max(lo, min(hi, g))

    def _set_state(self, s):
        self.state = s
        self.state_frame = 0

    # -- input: dipanggil saat tombol/lompatan terdeteksi
    def press(self):
        min_frames = self.p["min_flap_interval_ms"] * FPS // 1000
        if self.frame - self.last_flap_frame < min_frames:
            return False
        self.last_flap_frame = self.frame
        delay = self.p["input_latency_ms"] * FPS // 1000
        self.events.append(self.frame + delay)
        return True

    def _take_flap(self):
        due = [e for e in self.events if e <= self.frame]
        if due:
            self.events = [e for e in self.events if e > self.frame]
            return True
        return False

    def bird_hitbox(self):
        m = self.p["hitbox_margin"]
        bx = self.p["bird_x"]
        by = self.bird_y // FP
        return bx + m, by + m, bx + BIRD_SIZE - m, by + BIRD_SIZE - m

    def _collides(self):
        l, t, r, b = self.bird_hitbox()
        if b >= GROUND_Y:
            return True
        if self.p["ceiling_kills"] and t <= 0:
            return True
        w = self.p["pipe_width"]
        gh = self.p["gap_h"]
        for pipe in self.pipes:
            px = pipe.x // FP
            if px < r and px + w > l:
                if t < pipe.gap_y or b > pipe.gap_y + gh:
                    return True
        return False

    def step(self):
        """Satu langkah 1/60 detik. Dipanggil sekali per vsync."""
        flap = self._take_flap()
        self.frame += 1
        self.state_frame += 1

        if self.state != GAME_OVER:
            self.scroll = (self.scroll + self._fp("pipe_speed")) % (10_000 * FP)

        if self.state == MENU:
            # burung mengambang naik-turun
            self.bird_y = (GROUND_Y // 2 - BIRD_SIZE // 2) * FP + int(
                6 * FP * math.sin(self.frame / 20))
            if flap:
                # snap ke tengah: nilai sin bisa beda 1 unit antar-libm,
                # jadi tidak boleh terbawa ke PLAY (uji jejak Python vs C)
                self.bird_y = (GROUND_Y // 2 - BIRD_SIZE // 2) * FP
                self._set_state(COUNTDOWN)
            return

        if self.state == COUNTDOWN:
            if self.state_frame >= COUNTDOWN_FRAMES:
                self._set_state(PLAY)
                self.bird_vy = -self._fp("flap_velocity")
            return

        if self.state == GAME_OVER:
            # burung jatuh ke lantai, lalu menunggu tombol
            if self.bird_y // FP + BIRD_SIZE < GROUND_Y:
                self.bird_vy = min(self.bird_vy + self._fp("gravity"), self._fp("max_fall_speed"))
                self.bird_y = min(self.bird_y + self.bird_vy, (GROUND_Y - BIRD_SIZE) * FP)
            if flap and self.state_frame >= GAME_OVER_LOCK_FRAMES:
                self.reset_to_menu()
                self._set_state(COUNTDOWN)
            return

        # ---- PLAY ----
        if flap:
            self.bird_vy = -self._fp("flap_velocity")
        self.bird_vy = min(self.bird_vy + self._fp("gravity"), self._fp("max_fall_speed"))
        self.bird_y += self.bird_vy
        if self.bird_y < 0:
            self.bird_y = 0
            self.bird_vy = 0

        speed = self._fp("pipe_speed")
        w = self.p["pipe_width"]
        bird_center = self.p["bird_x"] + BIRD_SIZE // 2
        for pipe in self.pipes:
            pipe.x -= speed
        for pipe in self.pipes:
            if (pipe.x // FP) + w <= -PIPE_CAP_EXTRA:
                rightmost = max(self.pipes, key=lambda q: q.x)
                pipe.x = rightmost.x + self.p["pipe_spacing"] * FP
                pipe.gap_y = self._next_gap(rightmost.gap_y)
                pipe.scored = False
            if not pipe.scored and (pipe.x // FP) + w // 2 < bird_center:
                pipe.scored = True
                self.score += 1

        if self._collides():
            self._set_state(GAME_OVER)

    def next_pipe(self):
        """Pipa terdekat yang belum dilewati burung."""
        l = self.p["bird_x"]
        ahead = [q for q in self.pipes if (q.x // FP) + self.p["pipe_width"] > l]
        return min(ahead, key=lambda q: q.x) if ahead else None


# ---------------------------------------------------------------------------
# Self-test (headless, tanpa pygame)
# ---------------------------------------------------------------------------
def autopilot(game):
    """Menekan flap seperti pemain sederhana: flap bila burung di bawah
    tengah celah dan sedang turun."""
    pipe = game.next_pipe()
    if pipe is None:
        return False
    target = pipe.gap_y + game.p["gap_h"] // 2 + 10
    center = game.bird_y // FP + BIRD_SIZE // 2
    return center > target and game.bird_vy >= 0


def run_until_over(game, max_frames, policy):
    game.press()                       # MENU -> COUNTDOWN
    for _ in range(max_frames):
        if game.state == PLAY and policy(game):
            game.press()
        game.step()
        if game.state == GAME_OVER:
            break
    return game.score, game.state


def selftest(params):
    ok = True

    def check(name, cond, info=""):
        nonlocal ok
        print(f"[{'PASS' if cond else 'FAIL'}] {name} {info}")
        ok &= cond

    # 1. Tanpa flap: burung jatuh ke lantai, skor 0
    g = Game(dict(params, input_latency_ms=0, min_flap_interval_ms=0))
    score, state = run_until_over(g, 20 * FPS, lambda _: False)
    check("tanpa flap -> game over di lantai", state == GAME_OVER and score == 0,
          f"(skor={score}, frame={g.frame})")

    # 2. Flap terus-menerus: burung tertahan di atas; dengan ceiling_kills=0
    #    burung hidup sampai menabrak pipa pertama (bagian atas)
    g = Game(dict(params, input_latency_ms=0, min_flap_interval_ms=0, ceiling_kills=0))
    score, state = run_until_over(g, 30 * FPS, lambda _: True)
    check("flap terus -> menabrak pipa", state == GAME_OVER, f"(skor={score})")

    # 3. Autopilot dengan ritme LOMPATAN manusia (jeda minimal 600 ms)
    human = dict(params, input_latency_ms=0, min_flap_interval_ms=600)
    g = Game(human)
    score, state = run_until_over(g, 120 * FPS, autopilot)
    check("autopilot ritme lompat 0,6 s -> skor >= 10", score >= 10,
          f"(skor={score}, state={state})")

    # 4. Autopilot + latensi kamera 100 ms tetap bisa dimainkan
    g = Game(dict(human, input_latency_ms=100))
    score_lat, state = run_until_over(g, 120 * FPS, autopilot)
    check("autopilot + latensi 100 ms -> skor >= 5", score_lat >= 5,
          f"(skor={score_lat}, state={state})")

    # 5. Deterministik: seed sama -> hasil sama
    a = Game(human)
    b = Game(human)
    ra = run_until_over(a, 60 * FPS, autopilot)
    rb = run_until_over(b, 60 * FPS, autopilot)
    check("deterministik (seed sama)", ra == rb and a.frame == b.frame, f"({ra} vs {rb})")

    # 6. Posisi celah selalu di dalam batas dan perubahan <= max_gap_delta
    g = Game(params)
    lo, hi = g._gap_limits()
    gaps, prev = [], g.pipes[-1].gap_y
    for _ in range(1000):
        prev = g._next_gap(prev)
        gaps.append(prev)
    deltas = [abs(x - y) for x, y in zip(gaps, gaps[1:])]
    check("celah dalam batas & delta terbatas",
          all(lo <= x <= hi for x in gaps) and max(deltas) <= params["max_gap_delta"],
          f"(range {min(gaps)}..{max(gaps)}, delta maks {max(deltas)})")

    # 7. Tidak lebih dari 4 pipa (sesuai register PIPE0..3)
    check("jumlah slot pipa = 4", len(g.pipes) == PIPE_SLOTS)

    print("SELFTEST", "PASS" if ok else "FAIL")
    return 0 if ok else 1


# ---------------------------------------------------------------------------
# Uji jejak (trace): acuan untuk versi C di sw/game/
# ---------------------------------------------------------------------------
STATE_ID = {MENU: 0, COUNTDOWN: 1, PLAY: 2, GAME_OVER: 3}
TRACE_LATENCY_MS = 100
TRACE_MIN_INTERVAL_MS = 600


def trace_row(g):
    """Satu baris CSV; format harus sama persis dengan sw/game/trace_main.c."""
    # bird_y saat MENU memakai sin (bisa beda antar-libm), jadi tidak dicatat
    by = "-" if g.state == MENU else str(g.bird_y)
    cols = [g.frame, STATE_ID[g.state], g.state_frame, by, g.bird_vy, g.score, g.scroll]
    for q in g.pipes:
        cols += [q.x, q.gap_y, int(q.scored)]
    return ",".join(str(c) for c in cols)


def trace_policy(g, game_index):
    """Skenario uji: menu -> main -> game over -> ulang, bergantian
    autopilot (lolos banyak pipa) dan flap rapat (menabrak atap/pipa)."""
    if g.state == MENU:
        return g.state_frame == 30
    if g.state == GAME_OVER:
        return g.state_frame == 60
    if g.state == PLAY:
        if game_index % 2 == 0:
            # lolos 8 pipa lalu berhenti flap -> jatuh ke lantai
            return g.score < 8 and autopilot(g)
        return g.frame % 9 == 0
    return False


def run_trace(params, frames, trace_path, presses_path):
    g = Game(dict(params, input_latency_ms=TRACE_LATENCY_MS,
                  min_flap_interval_ms=TRACE_MIN_INTERVAL_MS))
    presses, rows, games = [], [], 0
    for _ in range(frames):
        if trace_policy(g, games):
            presses.append(g.frame)
            g.press()
        prev = g.state
        g.step()
        if prev != GAME_OVER and g.state == GAME_OVER:
            games += 1
        rows.append(trace_row(g))
    with open(presses_path, "w", encoding="utf-8") as f:
        f.write("\n".join(str(x) for x in presses) + "\n")
    with open(trace_path, "w", encoding="utf-8") as f:
        f.write("\n".join(rows) + "\n")
    print(f"trace: {frames} frame, {len(presses)} tekan, {games} game over")
    return 0


# ---------------------------------------------------------------------------
# Tampilan (pygame) -- meniru layer engine PL
# ---------------------------------------------------------------------------
BIRD_ART = [
    "................",
    ".....kkkkkk.....",
    "...kkyyyykwwk...",
    "..kyyyyyykwwwk..",
    ".kyyyyyyykwwkwk.",
    ".kyyyyyyykwwkwk.",
    "kyyyyyyyyykwwwk.",
    "kyyyyyyyyyykkkkk",
    "kyyyyyyyyykooook",
    "kyyyyyyyyyykkkk.",
    ".kyyyyyyyykoook.",
    ".kyyyyyyyyykkk..",
    "..kyyyyyyyyyk...",
    "...kkyyyyyykk...",
    ".....kkkkkk.....",
    "................",
]
WING = [".kkkk.", "kllllk", "kllllk", ".kkkk."]
WING_ROWS = [3, 6, 9, 6]          # 4 frame animasi: atas, tengah, bawah, tengah
ART_COLORS = {
    "k": (40, 40, 40), "y": (250, 210, 60), "o": (240, 120, 40),
    "w": (255, 255, 255), "l": (255, 240, 170),
}
PIPE_BODY = (90, 190, 70)
PIPE_LIGHT = (150, 230, 110)
PIPE_DARK = (30, 80, 30)
GROUND_TOP = (90, 180, 60)
GROUND_A = (222, 200, 120)
GROUND_B = (204, 180, 100)


def bird_art_frame(i):
    rows = [list(r) for r in BIRD_ART]
    top = WING_ROWS[i]
    for dy, wr in enumerate(WING):
        for dx, ch in enumerate(wr):
            if ch != ".":
                rows[top + dy][1 + dx] = ch
    return ["".join(r) for r in rows]


def run_game(params, config_path, bpm, show_overlay):
    import pygame

    pygame.init()
    screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
    pygame.display.set_caption("Jump-to-Flap - model PC")
    clock = pygame.time.Clock()
    font_big = pygame.font.Font(None, 96)
    font_mid = pygame.font.Font(None, 40)
    font_small = pygame.font.Font(None, 22)

    # Sprite burung: 4 frame, 16x16 -> 32x32
    bird_frames = []
    for i in range(4):
        s = pygame.Surface((16, 16), pygame.SRCALPHA)
        for y, row in enumerate(bird_art_frame(i)):
            for x, ch in enumerate(row):
                if ch in ART_COLORS:
                    s.set_at((x, y), ART_COLORS[ch])
        bird_frames.append(pygame.transform.scale(s, (BIRD_SIZE, BIRD_SIZE)))

    # Langit: gradien per pita 8 baris (PL cukup ganti warna per pita)
    sky = pygame.Surface((SCREEN_W, GROUND_Y))
    for y in range(0, GROUND_Y, 8):
        t = y / GROUND_Y
        c = (int(90 + 100 * t), int(160 + 65 * t), int(230 + 20 * t))
        sky.fill(c, (0, y, SCREEN_W, 8))

    # Lantai: garis diagonal periode 32 px, digeser oleh scroll
    ground = pygame.Surface((SCREEN_W + 32, SCREEN_H - GROUND_Y))
    for y in range(ground.get_height()):
        for x in range(ground.get_width()):
            if y < 8:
                c = GROUND_TOP
            else:
                c = GROUND_A if ((x + y) // 16) % 2 == 0 else GROUND_B
            ground.set_at((x, y), c)

    beep = None
    try:
        import array
        pygame.mixer.init(frequency=22050, size=-16, channels=1)
        n = int(22050 * 0.05)
        buf = array.array("h", (int(6000 * math.sin(2 * math.pi * 880 * i / 22050)) for i in range(n)))
        beep = pygame.mixer.Sound(buffer=buf.tobytes())
    except Exception:
        beep = None
    beat_period = int(round(FPS * 60 / bpm)) if bpm else 0

    game = Game(params)
    tune_keys = {
        pygame.K_1: ("gravity", -0.01), pygame.K_2: ("gravity", 0.01),
        pygame.K_3: ("flap_velocity", -0.1), pygame.K_4: ("flap_velocity", 0.1),
        pygame.K_5: ("pipe_speed", -0.1), pygame.K_6: ("pipe_speed", 0.1),
        pygame.K_7: ("gap_h", -10), pygame.K_8: ("gap_h", 10),
        pygame.K_9: ("input_latency_ms", -20), pygame.K_0: ("input_latency_ms", 20),
    }
    saved_msg = 0
    best = 0
    running = True
    while running:
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                running = False
            elif ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    running = False
                elif ev.key in (pygame.K_SPACE, pygame.K_UP):
                    game.press()
                elif ev.key == pygame.K_r:
                    game.reset_to_menu()
                elif ev.key == pygame.K_TAB:
                    show_overlay = not show_overlay
                elif ev.key == pygame.K_s:
                    save_params(config_path, game.p)
                    saved_msg = 2 * FPS
                elif ev.key in tune_keys:
                    k, d = tune_keys[ev.key]
                    v = game.p[k] + d
                    v = max(0, round(v, 3)) if isinstance(d, float) else max(0, v)
                    game.p[k] = v
            elif ev.type == pygame.MOUSEBUTTONDOWN:
                game.press()

        prev_state = game.state
        game.step()
        if prev_state == PLAY and game.state == GAME_OVER:
            best = max(best, game.score)
            print(f"game over: skor={game.score} terbaik={best}")

        # ---- render, urutan layer = prioritas engine PL (belakang -> depan)
        screen.blit(sky, (0, 0))
        w = game.p["pipe_width"]
        gh = game.p["gap_h"]
        for pipe in game.pipes:
            px = pipe.x // FP
            if px > SCREEN_W or px + w < -PIPE_CAP_EXTRA:
                continue
            for top, bot in ((0, pipe.gap_y), (pipe.gap_y + gh, GROUND_Y)):
                if bot <= top:
                    continue
                pygame.draw.rect(screen, PIPE_BODY, (px, top, w, bot - top))
                pygame.draw.rect(screen, PIPE_LIGHT, (px + 6, top, 8, bot - top))
                pygame.draw.rect(screen, PIPE_DARK, (px, top, w, bot - top), 2)
            for cy in (pipe.gap_y - PIPE_CAP_H, pipe.gap_y + gh):
                cap = (px - PIPE_CAP_EXTRA, cy, w + 2 * PIPE_CAP_EXTRA, PIPE_CAP_H)
                pygame.draw.rect(screen, PIPE_BODY, cap)
                pygame.draw.rect(screen, PIPE_DARK, cap, 2)
        screen.blit(ground, (-((game.scroll // FP) % 32), GROUND_Y))

        anim = (game.frame // 6) % 4 if game.state != GAME_OVER else 1
        screen.blit(bird_frames[anim], (game.p["bird_x"], game.bird_y // FP))

        def center_text(font, text, y, color=(255, 255, 255)):
            shadow = font.render(text, True, (0, 0, 0))
            surf = font.render(text, True, color)
            x = SCREEN_W // 2 - surf.get_width() // 2
            screen.blit(shadow, (x + 3, y + 3))
            screen.blit(surf, (x, y))

        if game.state in (PLAY, GAME_OVER):
            center_text(font_big, str(game.score), 30)
        if game.state == MENU:
            center_text(font_mid, "JUMP-TO-FLAP", 120)
            center_text(font_small, "SPASI / klik = flap (nanti: lompatan)", 300)
        elif game.state == COUNTDOWN:
            n = 3 - game.state_frame // FPS
            center_text(font_big, str(max(1, n)), 160)
        elif game.state == GAME_OVER:
            center_text(font_mid, "GAME OVER", 150)
            center_text(font_small, f"terbaik {best}  -  SPASI untuk ulang", 200)

        if beat_period:
            on = game.frame % beat_period < 6
            pygame.draw.circle(screen, (255, 80, 80) if on else (80, 30, 30), (SCREEN_W - 20, 20), 10)
            if beep and game.frame % beat_period == 0:
                beep.play()

        if show_overlay:
            lines = [
                f"gravity {game.p['gravity']:.2f}   [1/2]",
                f"flap_velocity {game.p['flap_velocity']:.1f}   [3/4]",
                f"pipe_speed {game.p['pipe_speed']:.1f}   [5/6]",
                f"gap_h {game.p['gap_h']}   [7/8]",
                f"input_latency_ms {game.p['input_latency_ms']}   [9/0]",
                f"min_flap_interval_ms {game.p['min_flap_interval_ms']}",
                "S simpan ke config.ini   Tab sembunyikan   R menu",
            ]
            panel = pygame.Surface((380, 20 * len(lines) + 10), pygame.SRCALPHA)
            panel.fill((0, 0, 0, 150))
            screen.blit(panel, (6, SCREEN_H - panel.get_height() - 6))
            for i, line in enumerate(lines):
                screen.blit(font_small.render(line, True, (255, 255, 255)),
                            (12, SCREEN_H - panel.get_height() + 2 + 20 * i))
        if saved_msg:
            saved_msg -= 1
            center_text(font_small, "parameter disimpan ke config.ini", 240, (255, 255, 120))

        pygame.display.flip()
        clock.tick(FPS)

    pygame.quit()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=DEFAULT_CONFIG)
    ap.add_argument("--selftest", action="store_true", help="uji logika tanpa jendela")
    ap.add_argument("--bpm", type=float, default=0, help="metronom ritme lompatan (0 = mati)")
    ap.add_argument("--latency", type=int, default=None, help="override input_latency_ms")
    ap.add_argument("--min-interval", type=int, default=None, help="override min_flap_interval_ms")
    ap.add_argument("--no-overlay", action="store_true")
    ap.add_argument("--trace", metavar="CSV", help="tulis jejak per frame (uji vs C), tanpa jendela")
    ap.add_argument("--presses", metavar="TXT", help="file frame tekan untuk --trace")
    ap.add_argument("--frames", type=int, default=12000, help="jumlah frame untuk --trace")
    args = ap.parse_args()

    config_path = os.path.abspath(args.config)
    params = load_params(config_path)
    if args.latency is not None:
        params["input_latency_ms"] = args.latency
    if args.min_interval is not None:
        params["min_flap_interval_ms"] = args.min_interval

    if args.selftest:
        sys.exit(selftest(params))
    if args.trace:
        if not args.presses:
            ap.error("--trace butuh --presses")
        sys.exit(run_trace(params, args.frames, args.trace, args.presses))
    run_game(params, config_path, args.bpm, not args.no_overlay)


if __name__ == "__main__":
    main()
