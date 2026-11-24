# Jump-to-Flap

Final project PSD: game bergaya Flappy Bird di Zybo Z7. Kontrolnya lompatan pemain yang ditangkap webcam, dan gambarnya disusun oleh mesin grafis 2D di FPGA.

- Konsep: [docs/KONSEP-JUMP-TO-FLAP.md](docs/KONSEP-JUMP-TO-FLAP.md)
- Rencana teknis: [docs/PLAN-JUMP-TO-FLAP.md](docs/PLAN-JUMP-TO-FLAP.md)
- **Pembagian tugas 5 orang + kontrak antarmuka:** [docs/tugas/README.md](docs/tugas/README.md) ([A](docs/tugas/tugasA.md), [B](docs/tugas/tugasB.md), [C](docs/tugas/tugasC.md), [D](docs/tugas/tugasD.md), [E](docs/tugas/tugasE.md))
- Checklist minggu 1 jalur A (Linux + webcam): [docs/MINGGU-1-CHECKLIST-A.md](docs/MINGGU-1-CHECKLIST-A.md)

> **HDL final: VHDL di `hw/vhdl/`** (lulus simulasi GHDL). File Verilog di `hw/rtl/` dan `sim/*.v` adalah acuan lama dan tidak dipakai build.
>
> **Menjalankan di board:** [hw/README-VIVADO.md](hw/README-VIVADO.md): pola uji → renderer tanpa ARM → game dimainkan dengan tombol, semuanya lewat skrip.

## Struktur

| Folder | Isi |
|---|---|
| `docs/` | Konsep, plan, checklist, laporan |
| `hw/vhdl/` | VHDL final: `system/` (D, mulai dari `gfx_pkg.vhd`), `render/` (E) |
| `hw/rtl/` | Verilog acuan sementara: timing video, test pattern, top HDMI |
| `hw/constr/` | Constraint `.xdc` Zybo Z7 |
| `hw/scripts/` | Skrip build Vivado/Vitis/xsdb (hasil ke `hw/out/`, tidak di-commit) |
| `sim/` | Testbench VHDL (`sim/vhdl/`) + `run_vhdl.ps1` (output ke `sim/out/`, tidak di-commit) |
| `sw/` | Aplikasi ARM: `game/` (logika + loop game C), `platform/` (akses hardware), `config.ini` |
| `tools/` | Model game Python, `ref_render.py` (aturan gambar renderer), uji jejak/gambar, pembanding `.ppm` |
| `assets/` | Gambar sprite asli |

## Menjalankan

Kebutuhan:
- Python 3 + `pygame-ce` (`python -m pip install pygame-ce`)
- MSYS2 dengan `gcc`, `mingw32-make`, dan GHDL (`pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-make mingw-w64-ucrt-x86_64-ghdl-mcode`)
- Vivado + Vitis 2026.1 hanya untuk build ke board

Model game (spasi = flap/start, R = restart, Esc = keluar, lihat tombol lain di layar):

```powershell
python tools/game_model.py
```

```powershell
python tools/game_model.py --bpm 70 --latency 100
```

Self-test logika game (headless):

```powershell
python tools/game_model.py --selftest
```

Game versi C (`sw/game/`, nanti jalan di ARM) dan pemetaan register-nya diuji tanpa board. Butuh `gcc` + `make` (Windows: MSYS2 `mingw32-make`, Linux/WSL: `make`). Satu perintah menjalankan semua uji:

```powershell
mingw32-make -C sw/game check
```

Isinya:
- `gen_vhdl_assets.py --check`, `gen_config_c.py --check`: file hasil generate (`assets_pkg.vhd`, `config_default.c`) tidak basi.
- `game_model.py --selftest`: logika game Python.
- `game_regs --selftest`: konversi state game → register (BCD, pipa di tepi layar, hitung mundur, efek suara).
- `trace_compare.py`: game C identik dengan Python frame demi frame (`TRACE IDENTIK`).
- `render_check.py`: register dari game C, digambar oleh `tools/ref_render.py`, identik piksel demi piksel dengan tampilan game Python. Gambar tiap skenario disimpan di `sw/game/out/`.
- `board_sim`: loop board (`sw/game/main.c`) dijalankan di PC dengan platform tiruan (`sw/platform/platform_pc.c`). Pemain tiruan membaca layar dan menekan tombol, sampai skor, game over, dan main lagi.

Simulasi VHDL (GHDL), semua gambar dibandingkan dengan referensi Python:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_vhdl.ps1
```

Isinya: timing video, pola uji (3 mode), encoder TMDS (20.000 simbol), renderer (12 skenario game + kasus tepi, latensi 2 siklus), dan register AXI (commit saat vblank, tombol, efek suara). Gambar hasil ada di `sim/out/`.

## Aturan kontribusi

1. **Kerjakan di branch sendiri** (`a-platform`, `b-detector`, `c-game`, `d-system`, `e-render`), lalu minta digabung ke `main`.
2. **Folder pemilik** (lihat [docs/tugas/README.md](docs/tugas/README.md) §4): A `sw/platform/`, B `sw/detector/`, C `sw/game/` + `sw/config.ini`, D `hw/vhdl/system/` + `hw/constr/`, E `hw/vhdl/render/` + `assets/`. Mengubah folder orang lain harus seizin pemiliknya.
3. **Jalankan `mingw32-make -C sw/game check` sebelum commit**, dan `sim/run_vhdl.ps1` bila menyentuh VHDL. Semua harus PASS.
4. **Register map hanya berubah lewat koordinator.** Perubahannya harus masuk bersamaan ke empat tempat: [docs/tugas/README.md](docs/tugas/README.md) §3.1, `sw/game/regs.h`, `hw/vhdl/system/gfx_pkg.vhd`, dan `tools/ref_render.py`.
5. **Logika game diubah di dua tempat:** `tools/game_model.py` dan `sw/game/game.c`, lalu `check` harus tetap PASS.
6. **Aturan gambar** (warna tiap piksel dari register) ditulis di `tools/ref_render.py`. Renderer VHDL harus menghasilkan gambar yang identik dengannya.

Simulasi HDL (tes timing + dump frame test pattern ke `.ppm` + bandingkan dengan referensi Python):

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1
```

Sintesis untuk board: lihat [hw/README-VIVADO.md](hw/README-VIVADO.md).
