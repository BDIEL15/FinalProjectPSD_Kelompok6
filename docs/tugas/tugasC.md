# Tugas C — Software Game + Koordinator

**Nama:** ______ (koordinator)
Kontrak bersama: [README.md](README.md) · Model referensi: [../../tools/game_model.py](../../tools/game_model.py)

## 1. Peran dan tujuan
Kamu punya dua peran:
1. **Programmer game:**
   - Memindahkan logika `tools/game_model.py` ke **C** yang berjalan di ARM: fisika, pipa, tabrakan, skor, dan state machine.
   - Setiap frame, game menulis posisi objek ke register akselerator grafis, lalu `commit`, dan memicu efek suara.
2. **Koordinator:**
   - Menjaga kontrak antar anggota tetap konsisten, memimpin sinkron harian, dan mengurus merge ke `main`.
   - Membantu A di bring-up Linux (termasuk mencoba PetaLinux lewat WSL2 bila image siap pakai gagal).

## 2. Tanggung jawab dan file milikmu
- **Kode game** (`sw/game/`):
  - `game.c/.h` (logika murni, tanpa I/O, bisa diuji di PC);
  - `render_regs.c` (pemetaan state game ke register, termasuk konversi skor ke BCD);
  - `main.c` (loop utama: tunggu vblank, ambil event, `game_step`, tulis register, `commit`);
  - `config.c` (baca `sw/config.ini`);
  - `Makefile` (target `pc` dan `board`).
- **Parameter:** `sw/config.ini`, isi bagian game.
- **Dokumen bersama:** [README.md](README.md) (kontrak, milestone, tabel nama), bagian keputusan, dan penggabungan laporan.
- **Bukti:** `docs/bukti/C/`.

## 3. Menerima dan menyerahkan
| Dari | Kamu terima | Kapan |
|---|---|---|
| A | `platform.h` + stub PC | H3 |
| A | `platform_linux.c` / `platform_baremetal.c` teruji | H8 |
| D | Bitstream dengan register map v1 | H8 |
| B | `detector_poll()` atau mode UART | H9 |

| Ke | Kamu serahkan | Kapan |
|---|---|---|
| Semua | Register map v1 final (rapat dengan D, E) | **H3 (M1)** |
| B | `game_flap_event(t_ms)` + antrian event aman antarthread | H6 |
| D | Kebutuhan efek suara (kapan `SFX_TRIGGER` dipicu) | H8 |
| Semua | Build game di board (**M4**) | H10 |

## 4. Jadwal
| Hari | Game | Koordinasi / bantu A |
|---|---|---|
| H1 | Pelajari `game_model.py`. Kerangka `sw/game/` + Makefile. Siapkan WSL2 + gcc | Kickoff: isi nama di [README.md](README.md), buat branch, tentukan jam sinkron |
| H2 | Port `Rng`, `Pipe`, fisika fixed-point ke `game.c` | Bring-up Linux bersama A (boot SD, serial) |
| H3 | State machine (MENU/COUNTDOWN/PLAY/PAUSE/GAME_OVER), tabrakan, skor | **Rapat register map v1 (M1)** dengan D + E, bekukan di README |
| H4 | **Uji jejak:** jalankan input yang sama di Python dan C, bandingkan `bird_y`, `score`, `state` per frame (tambahkan opsi `--trace` di `game_model.py`). Harus identik | **Gate M2** bersama A. Bila image siap pakai gagal, coba PetaLinux di WSL2 (batas H4) |
| H5 | `config.c` (baca `config.ini`), `PAUSE` saat penanda hilang | Pantau M3 (D, E) |
| H6 | `render_regs.c`: state → register (pipa `visible=0` di luar layar, skor BCD, `TEXT_ID`, `COUNTDOWN`, frame animasi). Uji dengan stub PC (cetak register) | Serahkan `game_flap_event` ke B |
| H7 | `main.c` loop vblank + input tombol (atau UART) + pemicu `SFX_TRIGGER` | Pastikan D–E sudah menggabungkan renderer |
| H8–H9 | Uji di board dengan lib A + bitstream D. Debug bersama | |
| H10 | **M4**: game dimainkan dengan tombol di board | Review progres, putuskan fitur yang dipotong |
| H11–H12 | Integrasi detektor B (**M5**). Tala ritme bersama B (gravitasi, flap, celah) | |
| H13 | Uji main 30 menit, perbaiki bug, efek suara terdengar sesuai event | Kumpulkan bukti semua anggota |
| H14–H15 | Bab laporan software + **gabungkan laporan**, slide, latihan demo | **M6** |

**Versi 2 minggu:**
- Uji jejak di H3.
- `render_regs` + `main` di H5.
- M4 di H7, M5 di H9.
- Efek suara dihapus.

## 5. Definisi selesai
- [ ] `make pc` dan uji jejak Python vs C **identik**
- [ ] Register map v1 dibekukan dan tidak berubah tanpa persetujuan
- [ ] Game jalan di board dengan tombol (video M4)
- [ ] Game jalan dengan lompatan (video M5)
- [ ] Efek suara terpicu pada flap, skor, dan tabrak (bila suara masuk cakupan)
- [ ] Laporan tergabung, semua bukti anggota terkumpul

## 6. Risiko dan jalan keluar
| Masalah | Jalan keluar |
|---|---|
| Hasil C berbeda dengan Python | Pastikan semua aritmetika integer (fixed-point ×256), urutan update sama, LCG 31-bit sama |
| Board belum siap saat game siap | Kembangkan dan uji dengan `platform_pc.c`. Game logic tidak bergantung pada board |
| Gambar sobek atau tersendat | Tulis register hanya setelah `gfx_wait_vblank`, lalu satu kali `commit` per frame |
| Anggota terhambat lebih dari 1 hari | Pindahkan bantuan (mis. E bantu D, A bantu B) dan catat di README |
| Waktu tidak cukup | Potong sesuai "versi 2 minggu" di README. Prioritas: game dengan tombol → lompatan → suara |

## 7. Referensi
- [../../tools/game_model.py](../../tools/game_model.py): logika acuan (kelas `Game`, `Rng`, `step()`)
- [../../sw/config.ini](../../sw/config.ini): parameter
- [../PLAN-JUMP-TO-FLAP.md](../PLAN-JUMP-TO-FLAP.md) §3: desain software PS
