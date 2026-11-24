# Checklist Minggu 1 — Jalur A (Linux + Webcam di board)

Tujuan minggu ini: membuktikan bahwa **Linux bisa boot dari microSD di Zybo** dan **webcam bisa dibaca** di board. Hasil checklist ini menentukan **gate M2 di hari kerja ke-4 (H4)** (lihat [tugas/README.md](tugas/README.md) dan [tugas/tugasA.md](tugas/tugasA.md)). Dikerjakan A bersama C.

> **Batas waktu:** jika sampai H4 Linux atau webcam belum jalan, kelompok pindah ke **Cadangan A**. Pada Cadangan A, laptop memproses kamera dan mengirim flap lewat UART. Renderer HDL tetap sama, jadi tidak ada pekerjaan yang terbuang.

---

## 0. Hari pertama: konfirmasi ke dosen
Draft pesan (silakan disesuaikan):

> Selamat pagi/siang Pak/Bu. Kelompok kami berencana membuat final project game Flappy Bird di Zybo Z7. Kontrolnya lompatan pemain yang dibaca webcam USB. Rancangannya: mesin grafis 2D (sprite, layer, keluaran HDMI) kami rancang dalam VHDL di PL, sedangkan pembacaan webcam dan logika game berjalan di prosesor ARM (PS) dengan Linux. Apakah penggunaan PS/ARM dan Linux seperti ini diperbolehkan? Apakah ada porsi minimal yang harus dikerjakan dalam HDL? Terima kasih.

| Pertanyaan | Jawaban |
|---|---|
| PS/ARM boleh dipakai? | |
| Linux di PS boleh? | |
| Porsi HDL minimal / komponen wajib? | |
| IP pihak lain (rgb2dvi, clocking wizard) boleh? | |

Jika PS tidak boleh, pakai **Cadangan B** (logika game di PL). Kabari anggota B dan C hari itu juga.

## 1. Inventaris perangkat
| Item | Ada? | Catatan |
|---|---|---|
| Board: **Z7-10** atau **Z7-20**? (lihat tulisan di chip/kotak) | | |
| **Belum ada, beli H1:** adaptor daya eksternal 5 V (jack barrel; cek ukuran jack dan arus di Reference Manual). Jangan hanya mengandalkan daya USB saat webcam dipasang | | |
| microSD ≥ 8 GB + card reader | | |
| **Belum ada, beli H1:** webcam USB berlabel UVC / plug-and-play tanpa driver, mendukung YUYV 320×240 atau 640×480 @30 fps (contoh kelas Logitech C270/C310). Catat merek/model | | |
| Kabel micro-USB (UART/JTAG), kabel HDMI, monitor | | |

Atur jumper pemilih daya ke **WALL/adaptor**. Atur jumper mode boot (JP5) ke **SD**. Cek posisi tepatnya di Reference Manual Zybo Z7.

## 2. Siapkan image Linux di microSD (jalur cepat dulu; PetaLinux via WSL2 dicoba C secara paralel bila perlu)
1. Cari image siap pakai untuk Zybo Z7 dengan prioritas:
   1. Image **PYNQ** untuk Zybo Z7 (port komunitas; sudah ada Python + OpenCV).
   2. Image demo Linux dari Digilent untuk Zybo Z7.
   3. Bila keduanya tidak ada atau tidak cocok, pakai **PetaLinux** dari `.xsa` Vivado. Butuh Ubuntu/WSL dan versi yang sama dengan Vivado.
2. Catat sumber, versi image, dan tanggal unduh (untuk laporan).
3. Tulis image ke microSD dengan **balenaEtcher** atau **Rufus** (untuk file `.img`). Untuk file `BOOT.BIN` + `image.ub`, salin ke partisi FAT.
4. Pasang SD, sambungkan micro-USB ke laptop, lalu nyalakan board.

## 3. Konsol serial
1. Buka Device Manager → Ports → catat `COMx` untuk USB Serial Port Zybo.
2. Buka PuTTY / Tera Term: **115200 baud, 8N1**, tanpa flow control.
3. Tekan reset board. Pesan boot U-Boot lalu kernel Linux harus muncul, lalu prompt login.

| Cek | Hasil |
|---|---|
| Pesan U-Boot muncul | |
| Kernel boot sampai prompt login | |
| Lama boot (detik) | |
| `uname -a` (salin hasilnya) | |

## 4. Uji webcam
Colok webcam ke port **USB Host** board, lalu jalankan:

```sh
lsusb                                  # webcam terdaftar?
dmesg | grep -i -E "uvc|usb" | tail -20 # driver uvcvideo terpasang?
ls /dev/video*
v4l2-ctl --list-devices
v4l2-ctl -d /dev/video0 --list-formats-ext
```

Jika `v4l2-ctl` belum ada, install dengan `sudo apt install v4l-utils` (image berbasis Ubuntu/PYNQ).

Yang dicari di `--list-formats-ext`: format **YUYV** pada **320x240** atau **640x480**, sebaiknya 30 fps.

Ukur frame rate nyata dan simpan satu frame:

```sh
v4l2-ctl -d /dev/video0 --set-fmt-video=width=320,height=240,pixelformat=YUYV
time v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=90 --stream-to=/tmp/cap.raw
ls -l /tmp/cap.raw     # ukuran = 90 x 320 x 240 x 2 = 13.824.000 byte bila lengkap
```

fps ≈ 90 / waktu `real`. Salin `cap.raw` ke laptop (`scp`, atau lewat SD) untuk dilihat.

| Cek | Hasil |
|---|---|
| Webcam terdeteksi `lsusb` | |
| `/dev/video0` muncul, driver `uvcvideo` | |
| Format YUYV tersedia? Resolusi apa saja? | |
| fps terukur di 320×240 | |
| fps terukur di 640×480 | |
| Board stabil (tidak reset) saat webcam menyala | |

Jika PYNQ/OpenCV tersedia, coba juga baca frame dengan Python:

```python
import cv2, time
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320); cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
t = time.time(); n = 0
while n < 90:
    ok, f = cap.read(); n += ok
print("fps", n / (time.time() - t)); cv2.imwrite("/tmp/frame.png", f)
```

## 5. Keputusan gate M2 (H4)
| Kondisi | Keputusan |
|---|---|
| Linux boot **dan** webcam ≥ 15 fps di 320×240 | Lanjut arsitektur utama (minggu 2: capture + threshold penanda) |
| Linux boot, webcam tidak terbaca | Coba `modprobe uvcvideo` / webcam lain sampai H4. Bila tetap gagal → **Cadangan A** |
| Linux tidak boot sampai H4 (image siap pakai + PetaLinux WSL2 gagal) | **Cadangan A** |
| Dosen melarang PS | **Cadangan B** |

Keputusan: `__________`  Tanggal: `__________`

## 6. Sambil menunggu (opsional)
- (Dikerjakan B sejak H1, lihat [tugas/tugasB.md](tugas/tugasB.md).) Prototipe deteksi penanda di **laptop** dengan Python + OpenCV + webcam yang sama. Algoritmanya bisa dipindah ke board nanti, dan dipakai langsung bila Cadangan A terjadi.
- Uji 2–3 warna penanda (mis. hijau neon, oranye, magenta) di ruangan yang akan dipakai demo. Pilih yang paling kontras dengan background.
