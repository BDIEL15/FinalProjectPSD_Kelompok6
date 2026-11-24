# Tugas E — Inti Penggambar Grafis (VHDL)

**Nama:** ______  **Partner hardware:** D
Kontrak bersama: [README.md](README.md) · Desain layer: [../PLAN-JUMP-TO-FLAP.md](../PLAN-JUMP-TO-FLAP.md) §2.3–2.4

## 1. Peran dan tujuan
Kamu membuat **inti penggambar** akselerator grafis 2D dalam **VHDL**. Untuk setiap piksel `(x, y)` yang diminta monitor, renderer menjawab warnanya dengan menyusun layer dari belakang ke depan:
1. background langit;
2. lantai bergulir;
3. pipa;
4. burung;
5. teks/skor.

Semua posisi objek diambil dari register yang ditulis ARM. Renderer **tidak menyimpan gambar satu layar penuh** (framebuffer). Gambarnya dihitung langsung saat dipindai. Inilah bagian yang menunjukkan "mesin grafis buatan kelompok".

## 2. Tanggung jawab dan file milikmu
- **VHDL renderer** (`hw/vhdl/render/`):
  - `renderer.vhd` (top + mux prioritas + palet);
  - `layer_bg.vhd` (langit gradien per pita 8 baris + lantai bergaris diagonal dengan `SCROLL_X`);
  - `layer_pipe.vhd` (4 pipa procedural: batang + tutup + garis tepi);
  - `layer_bird.vhd` (sprite 32×32 dari BRAM, 4 frame, indeks 0 transparan);
  - `layer_text.vhd` (font ROM 8×16 skala 2×: angka skor BCD, hitung mundur, teks status `TEXT_ID`).
- **Aset dan alat bantu:**
  - `assets/` (sprite, font, palet);
  - `tools/img2mem.py` (PNG / `BIRD_ART` di `tools/game_model.py` → `.mem` untuk inisialisasi BRAM);
  - `tools/ref_render.py`: model referensi Python dengan **aturan yang sama persis** dengan VHDL. Tampilan `game_model.py` hanya panduan gaya.
- **Testbench:** `sim/vhdl/tb_renderer.vhd`, yang mengisi `gfx_regs_t` dengan beberapa skenario lalu dump frame `.ppm`, dibandingkan dengan `tools/compare_ppm.py`.
- **Dokumen:** `docs/bukti/E/`, ditambah bab laporan "Renderer 2D".

## 3. Menerima dan menyerahkan
| Dari | Kamu terima | Kapan |
|---|---|---|
| D | `gfx_pkg.vhd` (record `gfx_regs_t`) | H2 |
| C | Register map v1 final | H3 |

| Ke | Kamu serahkan | Kapan |
|---|---|---|
| D | `renderer` versi awal (background + pipa + burung) | **H7** |
| D | `renderer` final (+ teks, palet, mux lengkap) | H9 |
| D | Generator nada `sfx_gen.vhd` (bantuan suara) | H12 |

Antarmuka (README 3.2): `renderer(clk, rst, x, y, de, regs) → rgb(23:0), de_o`, latensi tetap `RENDER_LATENCY = 2` siklus.

## 4. Jadwal
| Hari | Pekerjaan | Hasil |
|---|---|---|
| H1 | Pelajari `hw/rtl/test_pattern.v` (pola "warna dihitung per piksel") dan `tools/game_model.py` (layout, `BIRD_ART`). Pasang Vivado. Tentukan palet 16 warna | Palet + sketsa layer |
| H2 | `tools/img2mem.py`: `BIRD_ART` 16×16 → sprite 32×32 ×4 frame, 4 bpp → `bird.mem`. Terima `gfx_pkg.vhd` | `bird.mem` |
| H3 | `layer_bg.vhd` + `tools/ref_render.py` versi awal. Ikut rapat register map (M1) | Background di simulasi |
| H4 | `layer_pipe.vhd` (rumus persegi + tutup, `x` signed, `visible`) | Pipa di simulasi |
| H5 | `layer_bird.vhd` (BRAM inisialisasi dari `.mem`, frame animasi, transparan). `tb_renderer.vhd` dump `.ppm` → **identik** dengan `ref_render.py` | **M3** (gambar simulasi) |
| H6 | Mux prioritas + palet dari register, pipeline tepat 2 siklus. Uji tepi: pipa sebagian di luar layar, burung di y=0 | Simulasi PASS |
| H7 | **Serahkan versi awal ke D.** Bantu D menyintesis dan mengecek timing | Renderer di bitstream |
| H8 | `layer_text.vhd`: font ROM angka 0–9 + huruf yang dibutuhkan (MENU, SIAP, PAUSE, GAME OVER, KAMERA) | Teks di simulasi |
| H9 | Skor 4 digit BCD di tengah atas, hitung mundur besar. **Renderer final ke D** | Renderer final |
| H10 | Debug di board bersama C/D sampai **M4** | M4 |
| H11–H12 | Bantu D: `sfx_gen.vhd`. Flap = sapuan nada naik ±80 ms, skor = dua nada, tabrak = derau LFSR yang meluruh | Generator nada |
| H13 | Polish grafis (flash saat tabrak, rotasi/kemiringan opsional), screenshot simulasi untuk laporan | Gambar laporan |
| H14–H15 | Bab laporan renderer (diagram layer, pipeline, pemakaian BRAM), slide | M6 |

**Versi 2 minggu:**
- Background + pipa + burung selesai H4, diserahkan ke D di H5.
- Teks hanya angka skor + 3 ikon status (siap, pause, game over), selesai H6.
- Bantuan suara dihapus.

## 5. Definisi selesai
- [ ] `bird.mem` dan palet di `assets/`, dibuat dari `img2mem.py`
- [ ] Minimal 3 skenario frame simulasi identik dengan `ref_render.py` (menu, main dengan 2–3 pipa, game over)
- [ ] Pipeline tepat `RENDER_LATENCY` siklus (dibuktikan testbench)
- [ ] Renderer di bitstream, tampil benar di monitor (foto)
- [ ] Pemakaian BRAM dan LUT renderer tercatat
- [ ] Generator nada (bila suara masuk cakupan)

## 6. Risiko dan jalan keluar
| Masalah | Jalan keluar |
|---|---|
| Sprite bergeser 1–2 piksel | BRAM punya latensi baca. Hitung alamat lebih awal dan samakan dengan `RENDER_LATENCY` |
| Pipa di tepi kiri menghilang atau rusak | `x` pipa **signed**. Bandingkan dengan tipe `signed`, bukan `unsigned` |
| Timing gagal (perbandingan terlalu banyak dalam satu siklus) | Pecah menjadi 2 tahap pipeline, hitung flag per layer di tahap 1 |
| Hasil VHDL ≠ referensi Python | Samakan rumus per baris (pita gradien, periode garis lantai) dan cetak piksel pertama yang berbeda |
| Font terlalu banyak memakan waktu | Mulai dari angka saja. Teks status bisa berupa ikon sederhana |

## 7. Referensi
- `hw/rtl/test_pattern.v`: contoh pola penggambaran per piksel + register keluaran
- `tools/game_model.py`: konstanta layar (lantai y=416, burung x=160, tutup pipa 20 px), `BIRD_ART`, `WING`
- `tools/compare_ppm.py`: pembanding gambar
- Project F, "Hardware Sprites" (dari referensi konsep): contoh sprite hardware
