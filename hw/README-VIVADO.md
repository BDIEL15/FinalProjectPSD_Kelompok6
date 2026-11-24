# Uji HDMI di Zybo Z7 dengan Vivado (minggu 1, anggota D)

> **HDL final wajib VHDL.** Langkah di bawah memakai file Verilog acuan di `hw/rtl/`. Setelah D memporting ke VHDL (`hw/vhdl/system/`), langkahnya tetap sama, hanya ganti file sumber ke versi `.vhd` (Vivado mendukung proyek campuran). Tugas lengkap D: [../docs/tugas/tugasD.md](../docs/tugas/tugasD.md).

Target: monitor menampilkan pola uji dari FPGA (tanpa PS). Sebelum ke board, pastikan simulasi lulus:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1
```

## 1. Persiapan (sekali saja)
1. Pakai **satu versi Vivado yang sama** untuk semua anggota. Catat versinya di sini: `______`
2. Unduh board file Digilent agar Zybo Z7 muncul di daftar board: <https://github.com/Digilent/vivado-boards>.
3. Unduh **Digilent vivado-library** (berisi IP `rgb2dvi`): <https://github.com/Digilent/vivado-library>. Pilih tag/branch yang sesuai versi Vivado.
4. Unduh `Zybo-Z7-Master.xdc` dari <https://github.com/Digilent/digilent-xdc>. **Cocokkan semua pin** di [constr/zybo_z7_hdmi.xdc](constr/zybo_z7_hdmi.xdc) dengan file ini.

## 2. Membuat proyek
1. Create Project → RTL Project → part **xc7z010clg400-1** (Z7-10) atau `xc7z020clg400-1` (Z7-20), atau pilih board Zybo Z7.
2. Add Sources: `hw/rtl/video_timing.v`, `hw/rtl/test_pattern.v`, `hw/rtl/top_hdmi_test.v`. Set `top_hdmi_test` sebagai top.
3. Add Constraints: `hw/constr/zybo_z7_hdmi.xdc`.
4. Settings → IP → Repository → tambah folder `vivado-library` → Refresh.
5. IP Catalog → **Clocking Wizard**, beri nama `clk_wiz_0`:
   - input clock 125 MHz
   - `clk_out1` = 25.175 MHz (wizard akan memberi nilai terdekat, biasanya 25,2 MHz; itu tidak masalah)
   - aktifkan `reset` (aktif tinggi) dan `locked`
6. IP Catalog → **RGB to DVI Video Encoder** (`rgb2dvi`), beri nama `rgb2dvi_0`:
   - Generate SerialClk internally = **ya**
   - Clock primitive = MMCM
   - TMDS clock range = **>= 25 MHz (kClkRange 5)**
   - Reset active high = **ya**
   - Pastikan nama port sama dengan instansiasi di `top_hdmi_test.v`. Bila versi IP berbeda, sesuaikan nama port.
7. Run Synthesis → Implementation → Generate Bitstream.
8. Catat untuk laporan: **Report Utilization** (LUT/FF/BRAM) dan **Report Timing Summary** (WNS harus ≥ 0).

## 3. Program dan uji di board
1. Jumper boot ke **JTAG**, sambungkan USB-PROG, daya, dan kabel HDMI ke port **HDMI TX**.
2. Open Hardware Manager → Auto Connect → Program Device.
3. Cek hasil:

| Cek | Hasil (isi) |
|---|---|
| LED0 menyala (MMCM terkunci) | |
| LED1 menyala (monitor terdeteksi/HPD) | |
| LED2 berkedip ~1 Hz | |
| sw = 00: 8 bar warna urut putih, kuning, cyan, hijau, magenta, merah, biru, hitam | |
| sw = 01: grid + bingkai merah terlihat di **keempat tepi** (bukti tidak ada piksel terpotong) | |
| sw = 10: kotak kuning memantul halus tanpa sobek | |
| Monitor/TV yang dipakai + mode yang dilaporkan monitor | |

**Jika ada masalah:**
- **Warna hijau dan biru tertukar:** ubah `{r, b, g}` di `top_hdmi_test.v`.
- **Monitor "No signal" padahal LED0 menyala:** coba monitor lain. Sebagian TV menolak 640×480 (lihat cadangan 720p di `docs/PLAN-JUMP-TO-FLAP.md` §2.2).
- **Simpan bukti:** foto layar untuk setiap mode untuk laporan.
