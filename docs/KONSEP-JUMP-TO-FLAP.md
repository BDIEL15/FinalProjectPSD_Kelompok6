# Jump-to-Flap
## Konsep awal proyek untuk diskusi kelompok

**Judul formal:** Perancangan Mesin Grafis 2D Berbasis FPGA untuk Permainan Flappy Bird dengan Kendali Lompatan melalui Webcam.

**Status:** Draft konsep, belum merupakan jaminan kompatibilitas kamera atau performa. Platform yang diasumsikan adalah Zybo Z7-10; model board, ketentuan penggunaan ARM, webcam, dan waktu pengerjaan perlu dikonfirmasi sebelum implementasi.

## 1. Deskripsi singkat

Jump-to-Flap adalah permainan bergaya Flappy Bird yang dikendalikan melalui lompatan fisik pemain di depan webcam. Sistem dirancang berjalan mandiri pada board Zybo Z7 dengan menggabungkan prosesor ARM atau Processing System (PS) dan logika FPGA atau Programmable Logic (PL). PS menerima gambar webcam, mendeteksi lompatan, dan menjalankan aturan permainan. PL mengimplementasikan mesin grafis 2D yang menyusun sprite burung, pipa, background, dan skor untuk ditampilkan melalui HDMI. Setiap lompatan yang terdeteksi menghasilkan satu kepakan burung. Proyek ini menekankan interaksi gerakan tubuh serta perancangan mesin grafis hardware yang dapat dikonfigurasi oleh software.

## 2. Ide dan pengalaman pemain

Pemain berdiri pada area yang terlihat oleh kamera. Setelah kalibrasi posisi awal, pemain melompat untuk membuat burung naik. Burung turun karena gravitasi, sedangkan pipa bergerak mendekati burung. Pemain menjaga burung melewati celah pipa untuk memperoleh skor. Permainan berakhir ketika burung menabrak pipa atau batas arena.

Kecepatan pipa, gravitasi, kekuatan flap, dan jarak antarrintangan disesuaikan dengan ritme lompatan manusia. Parameter tersebut tidak harus mengikuti Flappy Bird asli.

Alur penggunaan:

1. Sistem menampilkan menu awal dan status kamera.
2. Pemain masuk ke area kamera dan berdiri diam untuk kalibrasi.
3. Pemain menekan tombol mulai pada board; layar menampilkan hitung mundur.
4. Setiap lompatan yang sah menghasilkan satu flap.
5. Skor bertambah ketika burung berhasil melewati pipa.
6. Saat game over, skor akhir ditampilkan dan tombol board digunakan untuk mengulang.

Jika kamera terputus atau penanda pemain tidak terbaca dengan cukup baik, permainan masuk keadaan pause dan meminta kalibrasi ulang sebelum dilanjutkan.

## 3. Arsitektur sistem

```text
Webcam USB
    |
    v
PS / ARM pada Zybo
  - Driver dan penerimaan gambar
  - Pengolahan citra serta deteksi lompatan
  - Aturan game, gerak objek, tabrakan, skor
    |
    | AXI: posisi objek, pilihan sprite, skor, status
    v
PL / Logika FPGA
  - Antarmuka register grafis
  - Memori sprite dan palet warna
  - Mesin penggambar background, sprite, dan teks
  - Penggabungan layer
  - Timing video dan keluaran HDMI
    |
    v
Monitor / TV
```

Sistem ditargetkan dapat dimainkan tanpa laptop setelah boot dari media yang disiapkan, misalnya microSD. Laptop dipakai saat pengembangan dan pemrograman board. Perangkat saat demo meliputi board, webcam USB yang kompatibel, monitor/TV HDMI, kabel, microSD, dan catu daya yang sesuai untuk board serta webcam.

### Pembagian PS dan PL

| Bagian | Tanggung jawab |
| --- | --- |
| PS: penerimaan kamera | Mengatur webcam dan memperoleh frame menggunakan driver yang kompatibel |
| PS: deteksi lompatan | Menentukan posisi penanda, melakukan kalibrasi, dan menghasilkan event flap |
| PS: aplikasi game | Menghitung posisi/kecepatan burung, menggerakkan pipa, mendeteksi tabrakan, serta mengatur skor dan status |
| PS–PL: komunikasi | Mengirim atribut objek melalui register; rancangan awal memakai AXI-Lite |
| PL: mesin grafis 2D | Membentuk piksel dari atribut objek, gambar sprite, background, teks, dan prioritas layer |
| PL: keluaran video | Mengirim tampilan permainan ke monitor melalui HDMI |

PS dan PL sama-sama hardware di dalam chip. Program PS berjalan pada prosesor ARM yang sudah tersedia, sedangkan rangkaian PL dibentuk dari desain HDL. Pendekatan yang dipilih adalah gabungan hardware–software, bukan seluruh proses dalam Verilog/VHDL.

## 4. Pilihan pendekatan

| Pendekatan | Kelebihan | Konsekuensi | Posisi dalam konsep |
| --- | --- | --- | --- |
| Laptop menangani kamera; board menjalankan game/grafis | Memudahkan eksperimen pengolahan gambar | Membutuhkan laptop ketika dimainkan | Alternatif yang dibahas sebelumnya |
| Webcam USB diterima PS; aplikasi game di PS; renderer di PL | Bisa mandiri di board dan memberi pemisahan CPU–mesin grafis yang jelas | Memerlukan software kamera dan integrasi PS–PL | Arah yang dipakai draft ini mengikuti pembahasan terakhir |
| Kamera berantarmuka PL; deteksi dan game dibuat di PL | Kontribusi rangkaian digital lebih luas | Receiver kamera, konfigurasi sensor, dan algoritma citra menjadi pekerjaan hardware tambahan | Alternatif bila tugas mewajibkan seluruh logika dalam HDL |

PS cocok sebagai penerima webcam USB karena port USB Host bawaan Zybo tersambung ke sisi PS. Untuk webcam, rancangan awal mengusulkan Linux pada ARM dengan driver UVC dan format video yang didukung kamera. Dukungan driver, format piksel, resolusi, dan frame rate harus dibuktikan pada perangkat nyata; webcam tidak diasumsikan langsung bekerja begitu dipasang.

## 5. Deteksi lompatan: usulan awal

Metode awal yang diusulkan adalah pelacakan penanda warna, tanpa neural network pose estimation. Pemain memakai penanda dengan warna berbeda dari lingkungan pada badan dan dekat kaki. Kamera dipasang tetap dan area pemain terlihat dengan jelas.

Tahapan pemrosesan pada PS:

1. Mengambil gambar dan membatasi area pengamatan pemain.
2. Memisahkan warna penanda dari background.
3. Menghitung posisi penanda badan serta kaki.
4. Menyimpan posisi berdiri saat kalibrasi sebagai acuan.
5. Memeriksa perpindahan vertikal dan urutan gerak selama beberapa frame.
6. Menghasilkan satu event flap saat syarat gerakan terpenuhi.
7. Menunggu kondisi mendarat sebelum mengizinkan event berikutnya.

Keadaan detektor dapat berupa `BELUM_KALIBRASI`, `SIAP`, `LOMPAT`, dan `MENUNGGU_MENDARAT`. Ambang gerakan, penyaringan perubahan posisi, serta syarat mendarat ditentukan melalui pengujian.

Pelacakan penanda badan saja hanya menunjukkan gerak naik-turun. Pengamatan kaki ditambahkan untuk membantu membedakan lompatan dari gerakan badan biasa, tetapi ketepatannya tetap harus diuji. Sistem tidak diklaim langsung dapat mengenali semua lompatan dan kondisi ruangan.

**Batas keberhasilan metode awal:** satu pemain, kamera tetap, pencahayaan cukup stabil, dan penanda terlihat. Pengenalan lompatan tanpa penanda menjadi pengembangan berikutnya. Bila kelompok menginginkan tanpa penanda sejak awal, algoritma dan cakupan perlu ditinjau kembali.

## 6. Mesin grafis 2D yang dirancang di FPGA

Mesin grafis menerima atribut objek, bukan gambar satu frame yang sudah digambar oleh PS. Contoh atributnya adalah posisi burung, posisi pipa, indeks animasi, skor, dan status game. PL menggunakan atribut tersebut untuk membentuk gambar.

Usulan kemampuan awal:

- Background sederhana dan lantai.
- Sprite burung dengan beberapa frame animasi.
- Pipa atas dan bawah yang dapat ditempatkan melalui register.
- Satu indeks warna transparan untuk sprite.
- Prioritas layer untuk menentukan objek yang tampil di depan.
- Tampilan angka skor serta tulisan status dasar.
- Pembaruan atribut objek secara konsisten pada batas frame agar gambar tidak memakai campuran posisi lama dan baru.

Usulan target video awal adalah 640 × 480 pada sekitar 60 Hz, bergantung pada hasil implementasi dan kompatibilitas monitor. Frame rate kamera dan laju pembaruan game tidak harus sama dengan refresh video.

Rancangan awal menggunakan renderer sprite sederhana tanpa framebuffer penuh. Grafik disimpan pada memori internal sesuai anggaran BRAM; kapasitas sprite, kedalaman warna, dan jumlah pipa aktif ditentukan setelah anggaran resource dibuat. Engine ini merupakan akselerator grafis 2D, bukan GPU 3D umum.

Blok integrasi seperti AXI, clock, dan transmisi video dapat menggunakan IP yang tersedia. Kontribusi rancangan kelompok berfokus pada register grafis, penggambaran objek, penggabungan layer, dan integrasi dengan aplikasi. Penggunaan IP pihak lain tetap didokumentasikan.

## 7. Fitur inti dan pengembangan

| Fitur inti | Pengembangan setelah fitur inti stabil |
| --- | --- |
| Webcam terhubung langsung ke board | Deteksi gerak tanpa penanda |
| Kalibrasi pemain dan satu event per lompatan | Pilihan karakter dan tema |
| Burung, pipa, gravitasi, tabrakan, dan skor | Efek suara |
| Renderer 2D pada PL dan output HDMI | Background berlapis atau scrolling |
| Menu, mulai, pause, game over, dan restart | Penyimpanan high score |
| Tombol board untuk menguji flap tanpa kamera | Demo animasi kedua untuk menunjukkan engine bisa dipakai ulang |

Tombol flap dipertahankan sebagai alat uji agar masalah game/grafis dapat diperiksa terpisah dari kamera. Demo akhir tetap menggunakan lompatan sebagai kontrol utama.

## 8. Nilai proyek

| Kriteria | Hal yang ditonjolkan |
| --- | --- |
| Kreativitas | Interaksi fisik pemain sebagai kontrol game serta penggabungan webcam dengan mesin grafis buatan kelompok |
| Kompleksitas | Integrasi kamera, pengolahan citra, state machine, game, register PS–PL, memori sprite, dan output video |
| Kesukaran | Penanganan webcam di embedded Linux, pemicu lompatan yang stabil, latensi input, timing grafis, dan pengelolaan resource FPGA |

Pembeda dari Flappy Bird tombol adalah kontrol lompatan. Pembeda dari controller HDMI sederhana adalah PL benar-benar menyusun gambar dari atribut objek. Penilaian akhir tetap mengikuti rubrik dosen; konsep ini tidak mengklaim kebaruan global.

## 9. Tahap pengerjaan dan bukti keberhasilan

1. **Validasi board dan webcam:** pastikan penggunaan PS diperbolehkan; buktikan kamera bisa dibaca pada board menggunakan mode video yang dipilih.
2. **Tampilan dasar:** hasilkan pola uji dan satu sprite melalui HDMI.
3. **Engine dan game:** jalankan permainan melalui tombol board; buktikan PS mengendalikan atribut dan PL menyusun gambar.
4. **Deteksi lompatan:** uji kalibrasi dan event tunggal, termasuk gerakan yang seharusnya tidak memicu flap.
5. **Integrasi:** hubungkan detektor dengan game, sesuaikan ritme permainan, dan tangani hilangnya input kamera.

Keberhasilan ditunjukkan melalui permainan mandiri di board, respons satu flap per lompatan yang sah, tabrakan/skor yang benar, serta tampilan stabil. Laporan mencatat keberhasilan deteksi dan pemicu keliru pada skenario uji yang dijelaskan, latensi gerakan-ke-respons dengan metode pengukuran yang dinyatakan, penggunaan LUT/FF/BRAM, dan hasil timing. Angka performa baru ditetapkan setelah pengujian awal, bukan diasumsikan tercapai.

Pembagian kerja dapat mengikuti tiga tanggung jawab: kamera dan deteksi gerakan; software game dan komunikasi PS–PL; renderer HDL dan HDMI. Jumlah anggota serta pembagian orang belum ditentukan.

## 10. Keputusan yang masih terbuka

- Konfirmasi model board dan izin penggunaan ARM/software dari ketentuan tugas.
- Webcam, format video, catu daya, dan dukungan image Linux yang digunakan.
- Persetujuan kelompok terhadap penanda warna untuk versi awal.
- Waktu pengerjaan dan jumlah anggota untuk membatasi fitur.

Pilihan driver, versi tool yang kompatibel, detail register, ukuran sprite, parameter deteksi, dan mekanisme boot diserahkan pada perancangan teknis setelah validasi awal. Vivado dipakai untuk konfigurasi PS, integrasi IP, dan desain PL; software PS dikembangkan dengan alur embedded yang sesuai. Jika Linux dipilih untuk webcam, image Linux dan aplikasi kameranya juga perlu dibangun/disiapkan; pekerjaan ini tidak selesai hanya dengan konfigurasi Vivado.

## Referensi teknis

- [Digilent — Zybo Z7 Reference Manual](https://digilent.com/reference/_media/reference/programmable-logic/zybo-z7/zybo-z7_rm.pdf): arsitektur board, USB pada PS, dan HDMI pada PL.
- [AMD — Using the Zynq SoC Processing System](https://docs.amd.com/r/2026.1-English/ug1165-zynq-embedded-design-tutorial/Using-the-Zynq-SoC-Processing-System?contentId=YrteZsDKZir~zBq48UWCBQ): peran PS–PL dan alur hardware/software.
- [Linux Kernel — UVC driver](https://www.kernel.org/doc/html/latest/userspace-api/media/drivers/uvcvideo.html): dokumentasi driver USB Video Class.
- [Project F — Hardware Sprites](https://projectf.io/posts/hardware-sprites/): contoh pendekatan penggambaran sprite menggunakan hardware.
