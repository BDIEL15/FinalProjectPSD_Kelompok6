# Jump-to-Flap — Rencana Teknis
## Pelengkap `KONSEP-JUMP-TO-FLAP.md`

**Kondisi (diperbarui):** 5 anggota, waktu pengerjaan 2–3 minggu, board **Zybo Z7-10**, HDL **wajib VHDL** di Vivado, cakupan ditambah **efek suara hardware**. Pembagian tugas per orang dan jadwal harian ada di [tugas/README.md](tugas/README.md). Kode Verilog di `hw/rtl/` adalah acuan sementara yang akan diporting ke VHDL oleh anggota D.
**Status:** Rencana kerja. Semua angka performa dan resource adalah **target** yang harus dibuktikan dengan pengujian, sejalan dengan sikap file konsep.

Nomor bagian konsep dirujuk sebagai "Konsep §n".

---

## 0. Ringkasan analisis konsep

### Yang sudah kuat
- **Pembagian PS/PL tepat.** Port USB Host Zybo Z7 tersambung ke PS, sedangkan HDMI TX tersambung ke PL. Jadi webcam di PS dan grafis di PL mengikuti arsitektur fisik board (Konsep §3–4).
- **Renderer tanpa framebuffer adalah pilihan yang benar.** Framebuffer 640×480 dengan 8 bit per piksel butuh ≈ 2,46 Mb, sedangkan total BRAM Z7-10 ≈ 2,1 Mb. Membentuk piksel langsung dari atribut objek (*racing the beam*) menghemat memori dan lebih "hardware" (Konsep §6).
- **Ada tombol flap sebagai alat uji.** Game dan grafis bisa diuji tanpa kamera (Konsep §7).
- **Klaim realistis.** Konsep tidak menjanjikan akurasi atau latensi sebelum diukur.

### Celah yang ditutup oleh dokumen ini
| # | Celah | Dijawab di |
|---|---|---|
| 1 | Waktu 4–6 minggu sempit. Linux + webcam adalah risiko terbesar, tetapi belum ada batas kapan harus pindah ke cadangan | §1, §6 |
| 2 | Belum ada register map, format sprite/palet, clock, dan anggaran resource | §2 |
| 3 | Belum ada strategi verifikasi HDL sebelum masuk board | §4 |
| 4 | Cara aplikasi Linux mengakses register PL belum ditentukan | §1.3, §3 |
| 5 | Risiko monitor/TV menolak 640×480 belum dibahas | §2.2, §7 |
| 6 | Daya webcam dari USB Host belum diperhitungkan | §7 |
| 7 | Belum ada anggaran latensi, metode uji deteksi, dan rencana demo | §3.5, §4.3, §8 |

---

## 1. Linux di Zynq: berjalan di mana?

### 1.1 Linux berjalan di prosesor ARM, bukan di logika FPGA
Chip Zynq-7000 pada Zybo berisi dua bagian dalam satu chip:

```text
┌──────────────────────── Chip Zynq XC7Z010 ────────────────────────┐
│  PS (Processing System)            PL (Programmable Logic)         │
│  - 2× ARM Cortex-A9 (~667 MHz)     - LUT, FF, BRAM, DSP            │
│  - Kontroler DDR, USB, SD, UART    - Diisi bitstream dari Vivado   │
│  - LINUX + aplikasi game di sini   - MESIN GRAFIS + HDMI di sini   │
│              └──────── AXI (register) ────────┘                    │
└────────────────────────────────────────────────────────────────────┘
```

ARM adalah prosesor sungguhan yang sudah tercetak di silikon, sama seperti prosesor di HP. Linux **tidak** disintesis menjadi rangkaian di FPGA. Linux berjalan di ARM seperti di komputer biasa. Yang kita rancang dengan HDL hanya bagian PL.

### 1.2 Boot dari microSD
Ya, Linux dijalankan dari microSD. Isi kartu biasanya:

| Partisi | Isi | Fungsi |
|---|---|---|
| FAT32 (BOOT) | `BOOT.BIN` = FSBL + bitstream PL + U-Boot | Menginisialisasi PS, **mengisi PL dengan desain grafis kita**, lalu memuat Linux |
| FAT32 (BOOT) | `image.ub` atau `uImage` + `devicetree.dtb` | Kernel Linux dan deskripsi hardware, termasuk alamat register grafis kita |
| ext4 (rootfs) | Sistem file Linux + aplikasi game + service autostart | Aplikasi langsung berjalan setelah boot |

Jumper boot Zybo diset ke **SD**. Saat board dinyalakan, bitstream dimuat ke PL, Linux berjalan di ARM, lalu aplikasi game langsung start. Laptop tidak diperlukan saat demo.

### 1.3 Dua jalur menyiapkan image Linux
| Jalur | Kelebihan | Kekurangan |
|---|---|---|
| **(a) PetaLinux** dari file `.xsa` hasil Vivado | Resmi, device tree otomatis sesuai desain kita | Butuh host Linux/WSL dan versi PetaLinux yang **sama persis** dengan Vivado; build pertama bisa makan berjam-jam |
| **(b) Image siap pakai** (port PYNQ untuk Zybo Z7, atau image Digilent) | Cepat jalan; PYNQ sudah punya Python, OpenCV, dan *overlay* untuk memuat bitstream sendiri | Perlu dicek kecocokan versi; ketergantungan pada image pihak lain harus didokumentasikan |

**Rekomendasi:** coba jalur (b) dulu. Jalur (a) dicoba paralel lewat WSL2 bila (b) bermasalah. Jika keduanya belum berhasil sampai **hari kerja ke-4 (gate M2)**, jalankan **Cadangan A** (§6).

Akses register PL dari aplikasi:
- **`/dev/mem` + `mmap`**: paling sederhana. Alamat dasar AXI-Lite (mis. `0x43C0_0000`) diambil dari Address Editor Vivado. Cukup untuk demo.
- **UIO** (`/dev/uioX`): lebih rapi dan bisa menerima interrupt vsync dari PL. Dipakai bila waktu memungkinkan.

---

## 2. Arsitektur hardware (PL) detail

### 2.1 Diagram blok

```text
              FCLK0 100 MHz                     Clocking Wizard
PS (ARM) ──AXI-Lite──► [Register Grafis]        ├─ pix_clk  25,175 MHz
                         shadow ──(latch saat ──┤
                         vblank)──► aktif        └─ ser_clk  125,875 MHz (5×)
                                    │
               [Timing 640×480] ──► x, y, de, hsync, vsync
                                    │
     ┌──────────────┬───────────────┼──────────────┬──────────────┐
     ▼              ▼               ▼              ▼              │
 [Background]   [Pipa]          [Burung]       [Teks/Skor]        │
 procedural     procedural      sprite BRAM    font ROM           │
     └──────────────┴───── idx 4-bit + valid ────┘                │
                           ▼                                       │
                [Penggabung layer / prioritas] ──► [Palet 16×RGB888]
                           ▼
                  [rgb2dvi (IP Digilent)] ──► HDMI TX ──► Monitor
```

### 2.2 Clock dan timing video
- **Mode utama:** 640×480 @ 60 Hz, pixel clock standar 25,175 MHz (25,0 MHz biasanya juga diterima monitor). Serializer TMDS memakai 5× pixel clock.
- **Mode cadangan:** sebagian TV menolak 640×480. Siapkan parameter generator timing untuk **1280×720 @ 60 Hz** (74,25 MHz, serial 371,25 MHz). Gambar logis tetap 640×360 lalu setiap piksel digandakan 2×, sehingga engine tidak perlu diubah. Mode ini dipakai hanya bila diperlukan, karena timing 371 MHz lebih sulit dicapai.
- **Domain clock:** AXI di 100 MHz dan renderer di pixel clock. Data berpindah domain hanya saat **vblank** lewat register shadow, ditambah sinkronisasi 2-FF untuk sinyal kontrol `commit` dan `vblank`.

### 2.3 Layer dan teknik penggambaran
| Layer | Prioritas | Teknik | Memori |
|---|---|---|---|
| Teks/skor | 1 (paling depan) | Font ROM 8×16, opsi scale 2×/4×; string status dari ROM pesan berindeks `TEXT_ID` | ~1 BRAM |
| Burung | 2 | Sprite 32×32, 4 frame animasi, 4 bpp, indeks 0 = transparan | 32×32×4×4 = 16 Kb (1 BRAM36) |
| Pipa | 3 | **Procedural**: persegi panjang batang + tutup sedikit lebih lebar, warna dari palet, garis tepi; tanpa gambar | 0 |
| Lantai | 4 | Pola garis diagonal bergulir memakai `SCROLL_X` | 0 |
| Background | 5 | Gradien langit per baris + awan sederhana (opsional dari BRAM kecil) | 0–1 BRAM |

Pipa dibuat procedural sehingga ukuran celah dan posisinya bebas tanpa menambah memori. Ini juga menunjukkan bahwa engine *menghitung* gambar, bukan sekadar menyalin bitmap.

Pipeline: alamat sprite dihitung satu siklus sebelum piksel (BRAM punya latensi baca 1–2 siklus), sehingga `hsync/vsync/de` harus ditunda dengan jumlah siklus yang sama.

### 2.4 Format grafis dan alat bantu
- 4 bpp, palet 16 warna RGB888 di register (bisa diubah PS → efek tema/siang–malam gratis).
- Skrip `tools/img2mem.py`: PNG → kuantisasi ke palet → `.mem` / `.coe` untuk inisialisasi BRAM.

### 2.5 Register map AXI-Lite (draft v0)
Offset dalam byte, semua 32-bit. Register bertanda **S** adalah shadow yang baru aktif pada vblank setelah `commit`.

| Offset | Nama | Bit | Keterangan |
|---|---|---|---|
| 0x00 | `CTRL` | [0] enable, [1] test_pattern, [2] commit (self-clear) | PS menulis 1 ke `commit` setelah semua atribut frame selesai ditulis |
| 0x04 | `STATUS` | [0] in_vblank, [1] commit_pending, [31:16] frame_count | Dibaca PS untuk sinkronisasi |
| 0x08 | `BIRD_POS` **S** | [9:0] x, [25:16] y | Koordinat kiri-atas, boleh negatif bila memakai format signed |
| 0x0C | `BIRD_ATTR` **S** | [1:0] frame, [2] visible, [3] flip/hit-flash | |
| 0x10–0x1C | `PIPE0..3` **S** | [10:0] x (signed), [20:12] gap_y, [31] visible | Maksimal 4 pasang pipa aktif |
| 0x20 | `PIPE_CFG` **S** | [8:0] gap_h, [15:9] width | Lebar celah dan lebar pipa |
| 0x24 | `SCROLL_X` **S** | [9:0] | Pergeseran lantai |
| 0x28 | `SCORE` **S** | [15:0] BCD, 4 digit | PS mengonversi skor biner ke BCD |
| 0x2C | `TEXT_ID` **S** | [3:0] | 0 kosong, 1 MENU, 2 KALIBRASI, 3 SIAP/3-2-1, 4 PAUSE, 5 GAME OVER, 6 KAMERA HILANG |
| 0x30 | `COUNTDOWN` **S** | [3:0] | Angka hitung mundur |
| 0x34 | `IRQ` | [0] en_vblank, [1] ack | Opsional (UIO) |
| 0x38 | `SFX_TRIGGER` | [0] flap, [1] skor, [2] tabrak (self-clear) | Efek suara, langsung tanpa shadow |
| 0x3C | `AUDIO_CTRL` | [0] enable, [7:4] volume | |
| 0x40–0x7C | `PALETTE[0..15]` | [23:0] RGB888 | |

Register map ini (v1) dibekukan pada **hari ke-3 (M1)**. Versi resminya ada di [tugas/README.md](tugas/README.md) §3.1. Perubahan setelahnya harus lewat koordinator (C) dan disetujui D dan E.

### 2.6 Anggaran resource (target)
| Resource | Tersedia Z7-10 | Target pakai |
|---|---|---|
| LUT | 17.600 | < 30% |
| FF | 35.200 | < 20% |
| BRAM36 | 60 | < 20% (≈ 12) |
| DSP | 80 | Hampir 0 (scale memakai shift) |

Angka aktual diambil dari laporan utilisasi Vivado setelah implementasi dan dimasukkan ke laporan.

### 2.7 Efek suara hardware (fitur tambahan, minggu 3)
- **Codec:** audio codec bawaan Zybo Z7 (SSM2603) dikonfigurasi dari PL oleh FSM I2C (`i2c_init`) berisi urutan register dari datasheet.
- **Pembangkit suara:** sampel dibangkitkan di PL (`sfx_gen`) dan dikirim lewat I2S (`i2s_tx`). MCLK 12,288 MHz dari Clocking Wizard, sampling 48 kHz.
- **Efek:**
  - flap = sapuan nada naik;
  - skor = dua nada;
  - tabrak = derau LFSR yang meluruh.
- **Pemicu:** game di PS menulis `SFX_TRIGGER`. ARM tidak mengirim data audio sama sekali.
- **Prioritas:** suara tidak boleh mengganggu M4/M5. Bila waktu habis, fitur ini dilewati.

---

## 3. Software PS

### 3.1 Struktur aplikasi
```text
sw/
  main.c          inisialisasi, pilih mode input (switch board), loop utama
  gfx_regs.c/.h   mmap register, fungsi gfx_set_bird(), gfx_commit(), gfx_wait_vblank()
  game.c/.h       state machine, fisika, pipa, tabrakan, skor
  detector.c/.h   V4L2 capture, threshold, kalibrasi, state lompatan
  input.c/.h      tombol board (AXI GPIO) + antrian event flap
  config.ini      parameter game & detektor
```

Dua thread:
- **Thread kamera:** capture → deteksi → masukkan event `FLAP` ke antrian (dengan timestamp).
- **Thread game:** tunggu vblank → ambil event dari antrian → update fisika satu langkah → tulis register → `commit`.

### 3.2 State machine game
```text
MENU ──start──► KALIBRASI ──stabil 1 s──► COUNTDOWN (3-2-1) ──► PLAY
                    ▲                                           │  │
                    └──────── penanda hilang > 0,5 s ── PAUSE ◄─┘  │
GAME_OVER ◄──────────────── tabrakan / keluar arena ───────────────┘
    └──tombol──► MENU
```

### 3.3 Fisika dan penalaan
- Update tetap 60 kali per detik mengikuti vsync, memakai fixed-point (Q16.16 atau satuan sub-piksel), sehingga hasil deterministik dan sama dengan model PC.
- Parameter di `config.ini`: `gravity`, `flap_velocity`, `pipe_speed`, `pipe_spacing`, `gap_h`, `max_fall_speed`.
- **Desain untuk ritme manusia:** satu siklus lompat-mendarat ≈ 0,6–1 detik, jauh lebih lambat dari ketukan jari. Mulai dengan gravitasi lebih rendah, flap lebih tinggi, celah lebih lebar, dan pipa lebih lambat daripada Flappy Bird asli. Tala di model PC (`tools/game_model.py`) sejak minggu 1 dengan menekan tombol pada ritme lompatan (misal metronom 70 BPM).
- Tabrakan: AABB antara hitbox burung (sedikit lebih kecil dari sprite, agar adil) dan batang pipa atau batas arena.

### 3.4 Detektor lompatan (memperjelas Konsep §5)
1. **Capture** lewat V4L2 di 320×240 (atau 160×120) format **YUYV**, 30 fps. Tidak perlu dekompresi MJPEG.
2. **Segmentasi** penanda langsung di kanal U/V (warna) dengan ambang + batas Y minimal. Tidak perlu konversi ke HSV. Proses hanya di ROI area pemain.
3. **Centroid** penanda badan dan kaki dari momen piksel. Penanda dianggap hilang bila jumlah piksel di bawah ambang.
4. **Filter** EMA atau median 3 frame untuk meredam noise.
5. **Kalibrasi:** rata-rata posisi selama 1 detik berdiri diam menjadi `y_ref` dan tinggi badan dalam piksel `h_ref`. Ambang dinyatakan relatif terhadap `h_ref`, sehingga jarak pemain ke kamera tidak terlalu berpengaruh.
6. **State:**
   - `SIAP` → `LOMPAT` bila kedua penanda (badan **dan** kaki) naik > `k_up · h_ref` dalam ≤ N frame. Pada transisi ini event `FLAP` dikirim **sekali**.
   - `LOMPAT` → `MENUNGGU_MENDARAT` saat mencapai puncak (kecepatan berbalik).
   - `MENUNGGU_MENDARAT` → `SIAP` bila kaki kembali ke dalam `±k_land · h_ref` dari `y_ref` dan stabil 2 frame, ditambah cooldown minimum.
   - Syarat kaki ikut naik membedakan lompatan dari jongkok-berdiri atau membungkuk.
7. Jika OpenCV tersedia (mis. image PYNQ), boleh dipakai untuk prototipe. Versi akhir sebaiknya C murni bila CPU A9 terbukti lambat.

### 3.5 Anggaran latensi (target, wajib diukur)
| Tahap | Perkiraan |
|---|---|
| Eksposur + transfer frame kamera (30 fps) | ≤ 33 ms (+ buffer driver) |
| Deteksi di ARM (320×240) | < 20 ms |
| Tunggu update game di vsync berikutnya | ≤ 16,7 ms |
| Scan-out sampai posisi burung di layar | ≤ 16,7 ms |
| **Total target** | **< 100 ms** |

Metode ukur: rekam pemain dan layar bersamaan dengan kamera HP slow-motion 240 fps, lalu hitung selisih frame antara kaki lepas dari lantai dan burung mulai naik. Ulangi ≥ 20 kali dan laporkan rata-rata serta maksimum. Setel buffer V4L2 sekecil mungkin (2 buffer) untuk mengurangi antrean frame lama.

---

## 4. Strategi verifikasi

### 4.1 Simulasi HDL (sebelum menyentuh board)
- **Testbench frame-dump:** jalankan renderer satu frame penuh di simulator (Vivado XSim atau Icarus/Verilator), tulis setiap piksel aktif ke file **`.ppm`**, lalu buka sebagai gambar. Bug posisi, transparansi, dan prioritas layer langsung terlihat.
- **Model referensi Python** (`tools/ref_render.py`) menggambar frame yang sama dari atribut yang sama. Bandingkan piksel per piksel secara otomatis.
- **Unit test:**
  - Generator timing: jumlah clock per baris (800) dan baris per frame (525), lebar pulsa hsync/vsync.
  - Register shadow: tulis saat bukan vblank → register aktif **tidak** berubah sebelum vblank.
  - Pipa dengan x negatif/di tepi layar tidak menghasilkan artefak.

### 4.2 Uji bertahap di board
1. Test pattern (bar warna) di HDMI, tanpa PS.
2. Sprite burung statis dari BRAM.
3. Burung digerakkan dari PS (bare-metal atau Linux) lewat register.
4. Game lengkap dengan tombol board.
5. Game dengan kamera.

Setiap tahap diselesaikan dulu sebelum lanjut, dan direkam (foto/video) sebagai bukti untuk laporan.

### 4.3 Uji akurasi detektor
| Skenario | Seharusnya | Percobaan |
|---|---|---|
| Lompat normal | 1 flap | ≥ 30 |
| Lompat beruntun cepat | 1 flap per lompatan | ≥ 30 |
| Jongkok lalu berdiri | 0 flap | ≥ 30 |
| Membungkuk / mengangkat tangan | 0 flap | ≥ 30 |
| Berjalan di dalam frame | 0 flap | ≥ 30 |
| Pencahayaan berbeda (lampu ruang, jendela) | sesuai skenario di atas | sampel per kondisi |

Laporkan **TP / FP / FN**, tingkat deteksi, dan pemicu keliru per skenario. Catat kondisi uji (jarak kamera, tinggi kamera, pencahayaan, warna penanda).

---

## 5. Jadwal 3 minggu dan pembagian kerja (5 orang)

Detail per orang dan per hari ada di [tugas/README.md](tugas/README.md) dan file `tugasA.md`–`tugasE.md`. Ringkasnya:

| | Peran | Inti pekerjaan |
|---|---|---|
| A | Platform Linux & board | Bring-up Linux + webcam, lib platform (akses register, tombol, UART), autostart; bare-metal bila Cadangan A |
| B | Deteksi lompatan | Prototipe laptop sejak hari 1, kalibrasi + state machine, uji akurasi/latensi, port ke board atau pengirim UART |
| C | Software game + koordinator | Port model Python ke C, game loop vblank, integrasi; kontrak antar anggota dan laporan |
| D | Kerangka akselerator + suara (VHDL) | Timing, HDMI, register AXI shadow/commit, block design PS7; efek suara minggu 3 |
| E | Inti penggambar (VHDL) | Layer background/lantai, pipa, sprite burung, teks/skor, palet, testbench `.ppm` |

### Milestone dan gate keputusan
| Kode | Hari kerja | Pertanyaan | Jika TIDAK |
|---|---|---|---|
| M1 | H3 | Register map v1 beku, webcam + adaptor ada, penanda terpilih? | Koordinator mengejar yang terlambat hari itu juga |
| **M2** | **H4** | Linux boot dari SD **dan** webcam terbaca di board? | **Cadangan A** (§6) |
| M3 | H5 | Pola uji VHDL tampil di HDMI, renderer lulus simulasi? | D dan E fokus ke jalur video, fitur grafis dipangkas |
| M4 | H10 | Game dikendalikan tombol di board? | Hentikan fitur tambahan, seluruh tim bantu integrasi |
| M5 | H12 | Kontrol lompatan end-to-end? | Sederhanakan detektor ke penanda badan + ambang vertikal + cooldown |
| M6 | H15 | Uji, laporan, demo siap? | Demo dengan mode tombol + video rekaman |

**Versi 2 minggu:**
- Suara dihapus.
- Teks hanya angka + 3 ikon status.
- Gate M2 di H3, M4 di H7, M5 di H9, M6 di H10.

---

## 6. Rencana cadangan

| Cadangan | Pemicu | Isi | Yang tetap sama |
|---|---|---|---|
| **A: Kamera di laptop** | Linux/webcam gagal sampai gate M2 (H4) | Laptop menjalankan detektor (Python + OpenCV), mengirim byte `'F'` lewat USB-UART Zybo; PS menjalankan game **bare-metal** (Vitis) yang membaca UART | Seluruh renderer PL, register map, logika game |
| **B: Dominan HDL** | Dosen mewajibkan logika utama di FPGA | Fisika, pipa, tabrakan, dan skor dipindah ke PL sebagai FSM yang berjalan per frame; PS (atau laptop) hanya mengirim event flap | Renderer dan HDMI; register map dipakai sebagai sinyal internal |
| **C: Tanpa kamera** | Semua jalur kamera gagal menjelang demo | Kontrol dengan tombol/Pmod atau sensor lain; jujur dicatat di laporan | Game dan engine lengkap |

Karena renderer tidak bergantung pada asal input, pekerjaan anggota D dan E tidak pernah terbuang, apa pun cadangan yang dipakai. Begitu juga detektor B: kodenya tetap dipakai, hanya pindah tempat jalan (board atau laptop).

---

## 7. Register risiko

| Risiko | Kemungkinan | Dampak | Mitigasi | Pemicu cadangan |
|---|---|---|---|---|
| Versi PetaLinux/image tidak cocok dengan Vivado | Tinggi | Tinggi | Coba image siap pakai dulu; kunci satu versi Vivado untuk semua anggota | Gate M2 (H4) → A |
| Webcam tidak didukung UVC atau format YUYV | Sedang | Tinggi | Uji webcam di H3, siapkan webcam kedua bila perlu; pilih yang terbukti | Gate M2 (H4) → A |
| Daya USB Host kurang untuk webcam | Sedang | Sedang | Pakai adaptor daya eksternal untuk board (cek Reference Manual); atau USB hub berdaya | — |
| Monitor/TV menolak 640×480 | Sedang | Tinggi saat demo | Uji di ≥ 2 monitor; siapkan mode 720p; bawa monitor sendiri | Mode 720p |
| CPU A9 terlalu lambat untuk deteksi | Sedang | Sedang | Resolusi 160×120, ROI kecil, C murni tanpa konversi warna | — |
| Pencahayaan ruang demo berbeda | Tinggi | Sedang | Kalibrasi warna di tempat; bawa lampu dan penanda 2 warna | Mode tombol |
| Timing gagal di serializer TMDS | Rendah | Tinggi | Pakai IP `rgb2dvi` yang sudah teruji; pipeline renderer | — |
| Anggota berhalangan | Sedang | Sedang | Repo git bersama, dokumentasi register map, setiap bagian punya pendamping | Pangkas fitur |

---

## 8. Persiapan demo

**Checklist perangkat:** board Zybo Z7, adaptor daya, webcam (+ cadangan), kabel HDMI, monitor teruji, microSD + **salinan kartu kedua**, penanda warna (2 warna berbeda), lampu kecil, tripod/penyangga kamera, laptop (hanya untuk cadangan).

**Urutan demo (± 5 menit):**
1. Nyalakan board dari SD, game muncul otomatis (bukti berjalan mandiri).
2. Tunjukkan mode test pattern / register diubah langsung (bukti PL menyusun gambar dari atribut, bukan menampilkan gambar dari PS). Contoh: ganti palet untuk mode malam.
3. Kalibrasi pemain, lalu main dengan lompatan.
4. Tunjukkan penanda keluar frame → PAUSE → kalibrasi ulang.
5. Tunjukkan tabel resource, hasil uji akurasi, dan latensi.

**Jika ruangan bermasalah:** pindah ke mode tombol dengan switch board dan tunjukkan video rekaman permainan dengan kamera.

---

## 9. Struktur repo yang disarankan

```text
FinPROPSDIH/
  docs/      KONSEP-JUMP-TO-FLAP.md, PLAN-JUMP-TO-FLAP.md, laporan, foto bukti
  hw/        HDL (renderer, timing, register), .xdc, block design (export TCL)
  sim/       testbench, output .ppm, gambar referensi
  sw/        aplikasi PS (game, detektor, driver register), config.ini
  tools/     img2mem.py, ref_render.py, model game pygame
  assets/    PNG sprite asli sebelum dikonversi
```

Simpan block design sebagai skrip TCL (`write_bd_tcl`) supaya proyek Vivado bisa dibuat ulang di laptop anggota lain tanpa konflik file proyek.

---

## 10. Isi laporan akhir yang perlu disiapkan sejak awal
- Diagram arsitektur PS–PL dan diagram blok renderer.
- Register map final.
- Screenshot simulasi (`.ppm`) dan foto tampilan HDMI per tahap.
- Utilisasi LUT/FF/BRAM/DSP dan hasil timing (WNS/TNS).
- Tabel akurasi detektor dan hasil pengukuran latensi beserta metodenya.
- Daftar IP pihak lain yang dipakai (mis. `rgb2dvi`, Clocking Wizard, AXI Interconnect) dan bagian yang dirancang sendiri.
- Desain dan hasil uji efek suara (bila masuk).
- Keterbatasan dan pengembangan berikutnya (deteksi tanpa penanda, high score).

---

## 11. Keputusan
**Sudah diputuskan:**
- 5 anggota.
- Board Zybo Z7-10.
- HDL VHDL di Vivado.
- Efek suara hardware masuk cakupan.
- Gate kamera di H4.
- Jadwal 3 minggu dengan versi 2 minggu.

**Masih terbuka (hari pertama):**
1. **Tanyakan dosen:** apakah boleh memakai ARM/Linux, dan berapa porsi HDL minimal? Jawaban ini menentukan pakai arsitektur utama atau Cadangan B.
2. Isi nama anggota A–E di [tugas/README.md](tugas/README.md) dan sepakati satu versi Vivado.
3. Beli webcam USB (UVC, YUYV) dan adaptor daya 5 V.
4. Sepakati warna penanda dan lokasi uji (dinding polos, pencahayaan stabil). Ditetapkan B di H3.
