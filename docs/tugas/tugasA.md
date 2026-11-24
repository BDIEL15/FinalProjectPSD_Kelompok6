# Tugas A — Platform Linux & Board

**Nama:** ______  **Pendamping:** C (koordinator, ikut bring-up Linux dan mencoba WSL2)
Kontrak bersama: [README.md](README.md) · Checklist detail minggu 1: [../MINGGU-1-CHECKLIST-A.md](../MINGGU-1-CHECKLIST-A.md)

## 1. Peran dan tujuan
Kamu membuat board menjadi **komputer yang siap dipakai game**:
- Linux jalan dari microSD dan webcam terbaca.
- Desain FPGA buatan D dimuat, dan registernya bisa ditulis dari program C.
- Game menyala otomatis saat board dihidupkan.

Bila Linux gagal sampai gate H4, kamu menyiapkan **jalur bare-metal** sebagai gantinya.

Bagian ini paling berisiko karena hanya bisa dibuktikan di board. Karena itu ada batas waktu yang tegas.

## 2. Tanggung jawab dan file milikmu
- **Perangkat:** webcam dan adaptor daya. Inventaris board, dan jumper boot (SD/JTAG) serta daya (WALL).
- **Image Linux:** image di microSD, dengan catatan sumber dan versinya.
- **Lib platform** (`sw/platform/`):
  - `platform.h`;
  - `platform_linux.c` (mmap `/dev/mem` atau UIO, tombol, UART);
  - `platform_baremetal.c` (Vitis, bila Cadangan A);
  - `platform_pc.c` (stub untuk C di laptop).
- **Boot:** memuat bitstream milik sendiri (FPGA manager / overlay PYNQ, atau `BOOT.BIN` baru).
- **Autostart:** service game saat boot (`systemd` atau `/etc/rc.local`).
- **Dokumen:** `docs/bukti/A/`, ditambah bab laporan "Platform dan boot".

## 3. Menerima dan menyerahkan
| Dari | Kamu terima | Kapan |
|---|---|---|
| D | `.xsa` + bitstream + alamat dasar AXI | H8 (versi awal H6) |
| B | Kebutuhan detektor di board (Python/OpenCV atau C + V4L2) | H5 |

| Ke | Kamu serahkan | Kapan |
|---|---|---|
| Semua | Keputusan gate kamera (M2) | H4 |
| C | `platform.h` + `platform_pc.c` (stub) | **H3** |
| C | `platform_linux.c` (atau `platform_baremetal.c`) yang teruji di board | H8 |
| B | Akses webcam di board: `/dev/video0`, format, dan fps | H4 |

## 4. Jadwal
| Hari | Pekerjaan | Hasil |
|---|---|---|
| H1 | **Beli webcam** (UVC, sebutkan YUYV 320×240/640×480 @30 fps; contoh kelas Logitech C270/C310) dan **adaptor 5 V** untuk Zybo Z7 (cek ukuran jack dan arus di Reference Manual). Unduh image Linux kandidat (port PYNQ Zybo Z7 / image Digilent). Cek konsol serial | Daftar perangkat, image terunduh |
| H2 | Tulis image ke SD, boot, login lewat serial (bersama C). Catat `uname -a` | Log boot |
| H3 | Webcam: `lsusb`, `dmesg`, `v4l2-ctl --list-formats-ext`, ukur fps. Tulis `platform.h` + stub PC untuk C | Tabel format/fps, header |
| H4 | **GATE M2**: Linux + webcam ≥ 15 fps di 320×240? Paralel: C mencoba jalur PetaLinux di WSL2 bila image siap pakai gagal | Keputusan tertulis |
| H5–H6 | **Jalur Linux:** cara memuat bitstream sendiri (FPGA manager / overlay), uji baca-tulis register dengan bitstream uji dari D. **Jalur Cadangan A:** platform Vitis bare-metal dari `.xsa` D, UART + GPIO tombol | Register bisa dibaca/ditulis |
| H7–H8 | `platform_linux.c` lengkap: `gfx_*`, `gfx_wait_vblank` (polling `STATUS.in_vblank` atau UIO IRQ), `btn_read`, `time_ms`. Uji: tulis `BIRD_POS` lalu burung bergerak | Serahkan ke C |
| H9–H10 | Bantu C mencapai **M4**: game dengan tombol di board | M4 |
| H11 | Autostart: game jalan sendiri setelah boot, tanpa laptop | Video boot sampai game |
| H12 | Bantu integrasi detektor B di board: prioritas thread, beban CPU (`top`) | M5 |
| H13–H14 | Uji stabilitas: 30 menit main tanpa reset, cabut-pasang webcam, siapkan SD cadangan (salin image) | Log uji |
| H15 | Kit demo (checklist perangkat), bab laporan | M6 |

**Versi 2 minggu:** gate di H3. Lib platform selesai di H6, M4 di H7, dan autostart hanya bila sempat.

## 5. Definisi selesai
- [ ] Foto board + daftar perangkat (model webcam, adaptor)
- [ ] Log boot Linux dari SD + `uname -a`
- [ ] Tabel format/fps webcam di board
- [ ] Keputusan gate M2 tertulis di [README.md](README.md)
- [ ] Program kecil yang menggerakkan burung lewat register terbukti di monitor
- [ ] `platform.h` sesuai kontrak, dipakai C tanpa perubahan
- [ ] Board menyala → game muncul sendiri (video)
- [ ] SD cadangan siap

## 6. Risiko dan jalan keluar
| Masalah | Jalan keluar |
|---|---|
| Image untuk **Zybo lama**, bukan Z7 | Pastikan nama file/halaman menyebut "Zybo Z7". Jika tidak ada, PetaLinux lewat WSL2 (C) |
| `lsusb` kosong | Pastikan USB diset `dr_mode = "host"` di device tree. Cek jumper/daya USB |
| Tidak ada `/dev/video0` | Kernel tanpa `uvcvideo`: coba `modprobe uvcvideo`. Di PetaLinux aktifkan `CONFIG_USB_VIDEO_CLASS` |
| Board reset saat webcam dicolok | Pakai adaptor eksternal, atau USB hub berdaya |
| Bitstream sendiri tidak bisa dimuat di image siap pakai | Ganti bitstream di `BOOT.BIN`, atau pakai mekanisme overlay PYNQ. Bila buntu → Cadangan A |
| Waktu habis di gate H4 | **Jangan diteruskan**: Cadangan A, kamu pindah ke Vitis bare-metal |

## 7. Referensi
- [../MINGGU-1-CHECKLIST-A.md](../MINGGU-1-CHECKLIST-A.md): perintah uji langkah demi langkah
- [../PLAN-JUMP-TO-FLAP.md](../PLAN-JUMP-TO-FLAP.md) §1: penjelasan boot SD dan akses register
- Digilent Zybo Z7 Reference Manual (USB host, daya, jumper)
- Dokumentasi Linux UVC driver, `v4l2-ctl`
