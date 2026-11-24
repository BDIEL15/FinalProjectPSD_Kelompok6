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
| `hw/rtl/` | Verilog: timing video, test pattern, top HDMI (nanti: renderer) |
| `hw/constr/` | Constraint `.xdc` Zybo Z7 |
| `sim/` | Testbench + skrip simulasi (output ke `sim/out/`, tidak di-commit) |
| `sw/` | Aplikasi PS (nanti) dan `config.ini` parameter game |
| `tools/` | Model game Python, referensi gambar, pembanding `.ppm` |
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

Simulasi HDL (tes timing + dump frame test pattern ke `.ppm` + bandingkan dengan referensi Python):

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1
```

Sintesis untuk board: lihat [hw/README-VIVADO.md](hw/README-VIVADO.md).
