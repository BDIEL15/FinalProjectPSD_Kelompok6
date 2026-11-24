# Tugas B — Deteksi Lompatan (Computer Vision)

**Nama:** ______
Kontrak bersama: [README.md](README.md) · Desain detektor: [../PLAN-JUMP-TO-FLAP.md](../PLAN-JUMP-TO-FLAP.md) §3.4

## 1. Peran dan tujuan
Kamu mengubah gambar webcam menjadi **satu event FLAP untuk setiap lompatan sah**. Jongkok, membungkuk, mengangkat tangan, dan berjalan **tidak boleh** memicu flap.

Kamu mulai **hari pertama di laptop**, tidak perlu menunggu board. Hasilnya tetap terpakai apa pun keputusan gate:
- bila Linux di board jalan, kodemu dipindah ke board;
- bila tidak, laptop yang menjalankan detektor saat demo dan mengirim flap lewat UART (Cadangan A).

## 2. Tanggung jawab dan file milikmu
- **Prototipe detektor di laptop:** `tools/detector_proto.py` (Python + OpenCV).
- **Versi board:** `sw/detector/`. Bahasanya C + V4L2, atau Python bila image board punya OpenCV dan cukup cepat.
- **Mode pengirim UART:** `tools/detector_uart.py` (Cadangan A, kirim `'F'`, `'L'`, `'K'`).
- **Uji dan parameter:**
  - parameter detektor di `sw/config.ini` bagian `[detector]`;
  - video uji di `assets/video_uji/` (jangan commit file besar; simpan di drive bersama);
  - tabel akurasi dan latensi.
- **Dokumen:** `docs/bukti/B/`, ditambah bab laporan "Deteksi lompatan".

## 3. Menerima dan menyerahkan
| Dari | Kamu terima | Kapan |
|---|---|---|
| A | Webcam yang sama dengan untuk board, dan info `/dev/video0`, format, fps di board | H1 (webcam), H4 (info board) |
| C | Fungsi `game_flap_event(t_ms)` dan antrian event | H6 |

| Ke | Kamu serahkan | Kapan |
|---|---|---|
| Semua | Warna penanda terpilih + cara pakai (posisi di badan dan dekat kaki) | H3 |
| A | Kebutuhan software detektor di board (paket, resolusi) | H5 |
| C | `detector_poll()` (board) atau `detector_uart.py` (Cadangan A) | H9 |
| C | Parameter rekomendasi (ambang, cooldown) | H12 |

## 4. Jadwal
| Hari | Pekerjaan | Hasil |
|---|---|---|
| H1 | Pasang Python + OpenCV di laptop. Tampilkan webcam laptop. Siapkan 2–3 bahan penanda (hijau neon, oranye, magenta) | Jendela kamera live |
| H2 | Segmentasi warna (HSV untuk prototipe, nanti U/V di board), ROI, centroid badan + kaki, overlay di layar | Penanda terlacak |
| H3 | Pilih warna paling kontras di ruangan uji. **Umumkan ke tim (M1)**. Kalibrasi berdiri diam 1 detik → `y_ref`, `h_ref` | Penanda terpilih |
| H4 | State machine `BELUM_KALIBRASI / SIAP / LOMPAT / MENUNGGU_MENDARAT`, ambang relatif terhadap `h_ref`, cooldown. Cetak `FLAP` ke terminal | Event flap di laptop |
| H5 | **Rekam video uji** (lompat normal, beruntun, jongkok, membungkuk, angkat tangan, berjalan; 2 kondisi cahaya). Bisa diputar ulang ke detektor supaya tuning bisa diulang | Set video uji |
| H6–H7 | Skrip uji otomatis: putar video, hitung TP/FP/FN. Tala ambang | Tabel akurasi awal |
| H8–H9 | **Bila Linux jalan:** port ke board (C + V4L2 YUYV, threshold di U/V, resolusi 320×240 atau 160×120), ukur fps di board. **Bila Cadangan A:** `detector_uart.py` mengirim `'F'`/`'L'`/`'K'` ke USB-UART board | Detektor siap diintegrasikan |
| H10–H11 | Integrasi dengan game C, uji langsung dengan melompat | **M5** (bersama C) |
| H12 | Tala akhir parameter bersama C (ritme game vs lompatan) | Parameter final |
| H13 | **Uji akurasi final** (≥ 30 percobaan per skenario) + **ukur latensi** (rekam slow-motion HP 240 fps, ≥ 20 kali) | Tabel final |
| H14–H15 | Bab laporan + bagian demo kalibrasi | M6 |

**Versi 2 minggu:**
- Port ke board atau mode UART selesai di H7, integrasi H8–H9.
- Uji akurasi minimal 15 percobaan per skenario.
- Bila waktu sempit, cukup penanda badan + ambang vertikal + cooldown.

## 5. Definisi selesai
- [ ] Video demo detektor di laptop dengan overlay penanda dan state
- [ ] Warna penanda + cara pakai terdokumentasi
- [ ] Tabel akurasi: TP/FP/FN per skenario + kondisi uji (jarak, tinggi kamera, cahaya)
- [ ] Hasil latensi: rata-rata dan maksimum + metode
- [ ] fps detektor di platform akhir (board atau laptop)
- [ ] Integrasi: satu lompatan = satu flap di game

## 6. Risiko dan jalan keluar
| Masalah | Jalan keluar |
|---|---|
| Warna penanda mirip background | Pilih warna lain, pasang kain polos di belakang pemain, batasi ROI |
| Cahaya ruang demo berbeda | Kalibrasi warna otomatis saat kalibrasi (ambil warna penanda dari frame), bawa lampu |
| Detektor lambat di board | Turunkan resolusi ke 160×120, proses hanya ROI, tulis dalam C, hindari konversi HSV |
| Banyak flap palsu | Wajibkan kaki ikut naik, perbesar ambang, tambah cooldown dan syarat mendarat |
| Lompatan terlewat | Kecilkan ambang, kurangi filter, cek fps kamera (pencahayaan rendah menurunkan fps) |

## 7. Referensi
- [../PLAN-JUMP-TO-FLAP.md](../PLAN-JUMP-TO-FLAP.md) §3.4 (algoritma), §3.5 (latensi), §4.3 (skenario uji)
- [../KONSEP-JUMP-TO-FLAP.md](../KONSEP-JUMP-TO-FLAP.md) §5
- Dokumentasi OpenCV: `cv2.inRange`, `cv2.moments`. Dokumentasi V4L2 untuk versi C
