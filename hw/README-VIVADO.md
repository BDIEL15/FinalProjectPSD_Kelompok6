# Dari VHDL ke game di monitor (Zybo Z7-10, Vivado 2026.1)

Semua langkah memakai **skrip**, bukan klik GUI, supaya bisa diulang siapa saja. Jalankan setiap perintah dari **folder root repo**.

| Tahap | Hasil di monitor | Skrip build | ARM? |
|---|---|---|---|
| A | Pola uji (bar warna, grid, kotak memantul) | `hw/scripts/build_hdmi_test.tcl` | Tidak |
| B | Game bergerak sendiri: pipa, burung, skor (tanpa C) | `hw/scripts/build_render_test.tcl` | Tidak |
| M4 | **Game dimainkan dengan tombol** | `hw/scripts/build_system.tcl` + `hw/scripts/vitis_app.py` | Ya (bare-metal) |

Kerjakan berurutan. Kalau A belum tampil, B dan M4 juga tidak akan tampil.

## 0. Persiapan (sekali saja)

1. **Vivado 2026.1**, centang **Vitis** dan device **Zynq-7000**. Versi ini dipakai semua anggota: `2026.1`.
2. **Board file Digilent** (wajib untuk M4, berisi preset ARM Zybo: DDR, UART, clock):
   salin isi `new/board_files` dari <https://github.com/Digilent/vivado-boards> ke `<Vivado>/data/boards/board_files/`.
3. **Pin XDC** di [constr/zybo_z7_hdmi.xdc](constr/zybo_z7_hdmi.xdc) sudah dicocokkan dengan `Zybo-Z7-Master.xdc` Digilent (22 port cocok). Cocokkan ulang bila menambah port baru.
4. **Simulasi harus lulus dulu** (cukup GHDL + gcc, tanpa Vivado):

```powershell
mingw32-make -C sw/game check
```

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_vhdl.ps1
```

Keduanya harus diakhiri `PASS`. Simulasi membuktikan logika dan gambar. Yang **tidak** bisa dibuktikan simulasi: primitif Xilinx (MMCM, OSERDES), pin, dan monitor. Itulah yang diuji di board.

Perintah `vivado`, `vitis`, dan `xsdb` ada di folder `bin` Vivado/Vitis. Di PowerShell, atur PATH sekali per jendela (jangan klik file `.bat`/`.tcl` langsung; Windows akan menanyakan "buka dengan apa"):

```powershell
$env:Path = "C:\AMDDesignTools\2026.1\Vivado\bin;C:\AMDDesignTools\2026.1\Vitis\bin;$env:Path"
```

(`C:\AMDDesignTools` adalah lokasi instalasi di laptop kelompok; sesuaikan bila berbeda.)

## Membuka di GUI Vivado (opsional)

Skrip `build_*.tcl` berjalan di terminal tanpa jendela. Untuk melihat/mengedit di GUI:

| Tujuan | Perintah |
|---|---|
| Proyek tahap A (pola uji HDMI) | `vivado -mode gui -source hw/scripts/open_project.tcl -tclargs hdmi_test` |
| Proyek tahap B (renderer game) | `vivado -mode gui -source hw/scripts/open_project.tcl -tclargs render_test` |
| Proyek M4 (block design + ARM), setelah `build_system.tcl` pernah jalan | `vivado hw/out/system/proj/system.xpr` |
| Memprogram board saja | `vivado`, lalu **Open Hardware Manager** (tanpa proyek) |

`open_project.tcl` hanya membuat proyek (sumber, XDC, top), tanpa build. Setelah GUI terbuka, klik **Run Synthesis → Run Implementation → Generate Bitstream** di Flow Navigator, atau lihat schematic lewat **Open Elaborated Design**. File VHDL **tidak disalin**: proyek menunjuk langsung ke `hw/vhdl/`, jadi edit di GUI = edit di repo. Proyek ada di `hw/out/gui_*/` (diabaikan git, aman dihapus). Perubahan koneksi block design lewat klik tidak ikut git; masukkan ke `hw/scripts/build_system.tcl`.

## Tahap A: pola uji HDMI (tanpa ARM)

```powershell
vivado -mode batch -source hw/scripts/build_hdmi_test.tcl
```

Hasil: `hw/out/hdmi_test/top_hdmi_test.bit`, `utilization.txt`, `timing.txt`. Skrip berhenti dengan error bila **WNS < 0** (timing gagal).

Program board:
1. Jumper JP5 (boot) ke **JTAG**, sambungkan USB-PROG, adaptor daya, dan HDMI ke port **HDMI TX**.
2. Vivado → Open Hardware Manager → Open Target → Auto Connect → Program Device → pilih `.bit`.

| Cek | Hasil |
|---|---|
| LED0 menyala (MMCM terkunci) | |
| LED1 menyala (monitor terdeteksi) | |
| LED2 berkedip ~1 Hz (frame berjalan) | |
| SW1..0 = 00: 8 bar warna putih, kuning, cyan, hijau, magenta, merah, biru, hitam | |
| SW1..0 = 01: grid + bingkai merah di **keempat tepi** | |
| SW1..0 = 10: kotak kuning memantul tanpa sobek | |
| Merek/model monitor + mode yang dilaporkan monitor | |

## Tahap B: renderer game tanpa ARM

```powershell
vivado -mode batch -source hw/scripts/build_render_test.tcl
```

Program `hw/out/render_test/top_render_test.bit` seperti tahap A. Yang harus terlihat (sama dengan gambar simulasi di `sim/out/scenarios/`):

| Cek | Hasil |
|---|---|
| Langit gradien, lantai bergaris bergulir, 3 pipa hijau | |
| Satu pipa bergeser ke kiri lalu muncul lagi di kanan; skor di atas bertambah tiap putaran | |
| Burung mengepak dan naik-turun pelan | |
| SW0 = burung putih (flash), SW1 = langit malam, SW2 = angka 3 besar di tengah | |

## M4: game dimainkan dengan tombol

1. **Hardware** (bitstream + `system.xsa`). Clock 25/125 MHz dibuat IP Clocking Wizard di block design, bukan di dalam `gfx_top`:

```powershell
vivado -mode batch -source hw/scripts/build_system.tcl
```

2. **Software** (aplikasi bare-metal dari `sw/game` + `sw/platform`):

```powershell
vitis -s hw/scripts/vitis_app.py
```

3. **Jalankan** (memuat bitstream, menginisialisasi ARM, dan menjalankan game lewat JTAG):

```powershell
xsdb hw/scripts/run_board.tcl
```

4. Buka konsol serial (PuTTY/Tera Term, port COM USB Serial Zybo, **115200 8N1**). Harus muncul:
   `Jump-to-Flap: register grafis di 0x43c00000` lalu `frame_count berjalan`.

| Cek | Hasil |
|---|---|
| Sebelum program C jalan: pola uji (CTRL.enable masih 0), pilih dengan SW1..0 | |
| Setelah program jalan: menu dengan burung naik-turun | |
| BTN0: hitung mundur 3-2-1, lalu flap | |
| Skor bertambah saat melewati pipa | |
| Tabrak pipa/lantai: game over; BTN0 untuk main lagi | |
| BTN1: kembali ke menu | |
| LED3 berkedip ~1 Hz (ARM commit tiap frame) | |
| Ketik `F` di konsol serial: burung flap (jalur Cadangan A) | |

Setelah mengubah kode C, jalankan ulang langkah 2 dan 3. Langkah 1 hanya perlu diulang bila VHDL atau XDC berubah.

### Cadangan bila skrip Vitis/xsdb gagal (GUI)
1. Vitis → File → New Component → Platform: pilih `hw/out/system/system.xsa`, OS standalone, CPU `ps7_cortexa9_0`, lalu Build.
2. New Component → Application → platform tadi → template **Empty Application (C)**.
3. Tambahkan ke `src/game/`: `main.c game.c game.h render_regs.c render_regs.h regs.h config_default.c`; ke `src/platform/`: `platform.h platform_baremetal.c`. Build.
4. Run → Launch Hardware (Vitis memuat bitstream dan ELF sekaligus).

## Kalau ada masalah

| Gejala | Kemungkinan dan jalan keluar |
|---|---|
| LED0 mati | MMCM tidak terkunci: cek pin `sysclk` (K17) di XDC |
| LED0 menyala, monitor "No signal" | Coba monitor lain (sebagian TV menolak 640×480). Bila tetap gagal, ganti `dvi_tx.vhd` dengan IP `rgb2dvi` Digilent (`vivado-library`); modul lain tidak berubah |
| Warna tertukar | Urutan kanal: 0 = biru, 1 = hijau, 2 = merah di `dvi_tx.vhd`. Cek pin `hdmi_tx_p/n[0..2]` di XDC |
| Gambar bergeser/berkedip | Lihat `timing.txt`: WNS harus ≥ 0 |
| Konsol: `GAGAL: frame_count tidak berubah` | Bitstream `system_wrapper.bit` belum dimuat, atau alamat bukan `0x43C0_0000` (cek Address Editor) |
| Pola uji tetap tampil, game tidak | Program C tidak menulis `CTRL.enable`: cek konsol serial, LED3 harus berkedip |
| `build_system.tcl` error di nama perintah/properti | Skrip ditulis sebelum Vivado 2026.1 tersedia; perbaiki baris itu di skrip (bukan lewat GUI), lalu catat perubahannya |

Simpan foto/video setiap tahap ke `docs/bukti/D/` dan `docs/bukti/E/` untuk laporan, bersama `utilization.txt` dan `timing.txt`. Diagram block design untuk laporan: buka `hw/out/system/proj/system.xpr` di GUI, buka block design `system`, lalu klik kanan di kanvas → **Save as PDF File**.
