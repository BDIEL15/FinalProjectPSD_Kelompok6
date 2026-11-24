# Jump-to-Flap

Final project PSD: game bergaya Flappy Bird di Zybo Z7. Kontrolnya lompatan pemain yang ditangkap webcam, dan gambarnya disusun oleh mesin grafis 2D di FPGA.

- Konsep: [docs/KONSEP-JUMP-TO-FLAP.md](docs/KONSEP-JUMP-TO-FLAP.md)
- Rencana teknis: [docs/PLAN-JUMP-TO-FLAP.md](docs/PLAN-JUMP-TO-FLAP.md)
- **Pembagian tugas 5 orang + kontrak antarmuka:** [docs/tugas/README.md](docs/tugas/README.md) ([A](docs/tugas/tugasA.md), [B](docs/tugas/tugasB.md), [C](docs/tugas/tugasC.md), [D](docs/tugas/tugasD.md), [E](docs/tugas/tugasE.md))
- Checklist minggu 1 jalur A (Linux + webcam): [docs/MINGGU-1-CHECKLIST-A.md](docs/MINGGU-1-CHECKLIST-A.md)

> **HDL final wajib VHDL.** File Verilog di `hw/rtl/` dan `sim/*.v` adalah acuan sementara yang sudah lulus simulasi. Anggota D memporting-nya ke `hw/vhdl/` (lihat [tugasD.md](docs/tugas/tugasD.md)).

## Struktur

| Folder | Isi |
|---|---|
| `docs/` | Konsep, plan, checklist, laporan |
| `hw/vhdl/` | VHDL final: `system/` (D, mulai dari `gfx_pkg.vhd`), `render/` (E) |
| `hw/rtl/` | Verilog acuan sementara: timing video, test pattern, top HDMI |
| `hw/constr/` | Constraint `.xdc` Zybo Z7 |
| `sim/` | Testbench + skrip simulasi (output ke `sim/out/`, tidak di-commit) |
| `sw/` | Aplikasi PS: `game/` (logika game C) dan `config.ini` parameter game |
| `tools/` | Model game Python, `ref_render.py` (aturan gambar renderer), uji jejak/gambar, pembanding `.ppm` |
| `assets/` | Gambar sprite asli |

## Menjalankan

Kebutuhan: Python 3 + `pygame-ce` (`python -m pip install pygame-ce`) dan Icarus Verilog (`winget install -e --id Icarus.Verilog`).

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
- `game_model.py --selftest`: logika game Python.
- `game_regs --selftest`: konversi state game → register (BCD, pipa di tepi layar, hitung mundur, efek suara).
- `trace_compare.py`: game C identik dengan Python frame demi frame (`TRACE IDENTIK`).
- `render_check.py`: register dari game C, digambar oleh `tools/ref_render.py`, identik piksel demi piksel dengan tampilan game Python. Gambar tiap skenario disimpan di `sw/game/out/`.

## Aturan kontribusi

1. **Kerjakan di branch sendiri** (`a-platform`, `b-detector`, `c-game`, `d-system`, `e-render`), lalu minta digabung ke `main`.
2. **Folder pemilik** (lihat [docs/tugas/README.md](docs/tugas/README.md) §4): A `sw/platform/`, B `sw/detector/`, C `sw/game/` + `sw/config.ini`, D `hw/vhdl/system/` + `hw/constr/`, E `hw/vhdl/render/` + `assets/`. Mengubah folder orang lain harus seizin pemiliknya.
3. **Jalankan `mingw32-make -C sw/game check` sebelum commit** bila menyentuh game, register, atau gambar. Semua harus PASS.
4. **Register map hanya berubah lewat koordinator.** Perubahannya harus masuk bersamaan ke empat tempat: [docs/tugas/README.md](docs/tugas/README.md) §3.1, `sw/game/regs.h`, `hw/vhdl/system/gfx_pkg.vhd`, dan `tools/ref_render.py`.
5. **Logika game diubah di dua tempat:** `tools/game_model.py` dan `sw/game/game.c`, lalu `check` harus tetap PASS.
6. **Aturan gambar** (warna tiap piksel dari register) ditulis di `tools/ref_render.py`. Renderer VHDL harus menghasilkan gambar yang identik dengannya.

Simulasi HDL (tes timing + dump frame test pattern ke `.ppm` + bandingkan dengan referensi Python):

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1
```

Sintesis untuk board: lihat [hw/README-VIVADO.md](hw/README-VIVADO.md).
