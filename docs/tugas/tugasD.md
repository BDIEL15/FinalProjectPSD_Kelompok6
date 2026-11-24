# Tugas D — Kerangka Akselerator Grafis + Efek Suara (VHDL)

**Nama:** ______  **Partner hardware:** E
Kontrak bersama: [README.md](README.md) · Arsitektur PL: [../PLAN-JUMP-TO-FLAP.md](../PLAN-JUMP-TO-FLAP.md) §2

## 1. Peran dan tujuan
Kamu membangun **kerangka akselerator grafis 2D** di FPGA, semuanya dalam **VHDL** di **Vivado**. Isinya:
- **Generator timing video:** kapan piksel, baris, dan frame dimulai.
- **Keluaran HDMI.**
- **Register AXI-Lite** yang ditulis ARM, dengan mekanisme shadow/commit saat vblank agar gambar tidak sobek.
- **Block design Vivado** yang menyatukan prosesor (PS7) dengan desain PL.

Inti penggambar layer dibuat E dan kamu pasang di dalam kerangka ini. Di minggu 3, kamu menambahkan **modul efek suara** ke audio codec bawaan Zybo.

## 2. Tanggung jawab dan file milikmu
- **VHDL sistem** (`hw/vhdl/system/`):
  - `video_timing.vhd`, `test_pattern.vhd`: porting dari Verilog di `hw/rtl/` yang sudah lulus simulasi;
  - `gfx_pkg.vhd`: record `gfx_regs_t` dan konstanta, disepakati bersama E;
  - `gfx_axi_regs.vhd`: slave AXI-Lite + shadow + commit;
  - `gfx_top.vhd`: timing + renderer E + rgb2dvi;
  - `audio/` (minggu 3): `i2c_init.vhd`, `i2s_tx.vhd`, `sfx_gen.vhd`.
- **Testbench** (`sim/vhdl/`): `tb_video_timing.vhd`, `tb_frame_dump.vhd` (dump `.ppm` dengan `textio`), `tb_axi_regs.vhd`.
- **Constraint:** `hw/constr/zybo_z7_hdmi.xdc`, dicocokkan dengan Digilent master XDC, termasuk pin audio.
- **Vivado:** block design TCL (`write_bd_tcl`), `.xsa` dan bitstream untuk A, serta [../../hw/README-VIVADO.md](../../hw/README-VIVADO.md).
- **Dokumen:** `docs/bukti/D/`, ditambah bab laporan "Kerangka akselerator, register, dan suara".

Setelah versi VHDL lulus simulasi, file Verilog di `hw/rtl/` dihapus atau dipindah ke `hw/legacy/`.

## 3. Menerima dan menyerahkan
| Dari | Kamu terima | Kapan |
|---|---|---|
| C | Register map v1 final | H3 |
| E | Entity `renderer` sesuai antarmuka (README 3.2) | Versi awal H7, final H9 |
| C | Kapan efek suara dipicu | H8 |

| Ke | Kamu serahkan | Kapan |
|---|---|---|
| E | `gfx_pkg.vhd` | **H2** |
| Semua | Pola uji tampil di monitor (**M3**) | H5 |
| A | Bitstream uji + `.xsa` + alamat dasar AXI (register saja, tanpa renderer) | H6 |
| A, C | Bitstream lengkap (register + renderer E) | H8 |
| C | Modul suara di bitstream (`SFX_TRIGGER`, `AUDIO_CTRL`) | H12 |

## 4. Jadwal
| Hari | Pekerjaan | Hasil |
|---|---|---|
| H1 | Pasang Vivado (versi yang disepakati) + board file Digilent + `vivado-library`. Baca `hw/rtl/*.v` dan `sim/*.v` | Lingkungan siap |
| H2 | Port `video_timing` + `test_pattern` ke VHDL. Tulis `gfx_pkg.vhd` dan serahkan ke E | VHDL terkompilasi |
| H3 | Testbench VHDL (XSim): uji timing + dump `.ppm`, dibandingkan dengan `tools/ref_test_pattern.py` + `tools/compare_ppm.py` (harus identik). Rapat register map (M1) | Simulasi PASS |
| H4 | Cocokkan XDC dengan `Zybo-Z7-Master.xdc`. Proyek Vivado `top_hdmi_test` VHDL. Sintesis dan implementasi | Bitstream |
| H5 | **Program board**: bar warna, grid (keempat tepi terlihat), kotak memantul. Cek urutan warna rgb2dvi | **M3** (foto) |
| H6 | `gfx_axi_regs.vhd` dari template "Create and Package New IP → AXI4 Peripheral" (VHDL), lalu tambahkan shadow + commit. Block design: PS7 + IP register. **Rekomendasi:** clock AXI = clock piksel (M_AXI_GP0_ACLK dari clk_wiz) agar tidak perlu sinkronisasi antar-domain. Serahkan ke A | Bitstream uji register |
| H7 | `tb_axi_regs.vhd`: tulis shadow di luar vblank → register aktif **tidak** berubah sampai vblank setelah commit | Simulasi PASS |
| H8 | Gabungkan renderer E ke `gfx_top`. Tunda sync sebanyak `RENDER_LATENCY`. Sintesis, cek timing (WNS ≥ 0). Serahkan ke A + C | Bitstream lengkap |
| H9–H10 | Debug integrasi di board bersama C/E sampai **M4** | M4 |
| H11 | **Suara:** cek pin audio (`ac_mclk`, `ac_bclk`, `ac_pblrc`, `ac_pbdat`, `ac_muten`, `ac_scl`, `ac_sda`) di master XDC. MCLK 12,288 MHz dari clk_wiz. `i2c_init.vhd`: FSM + ROM urutan register SSM2603 (reset, power, jalur DAC, format I2S, sampling 48 kHz, active), alamat I2C 0x1A (cek datasheet) | Codec terkonfigurasi |
| H12 | `i2s_tx.vhd` + `sfx_gen.vhd` (E membantu generator nada). Simulasi lalu uji di board dengan headphone | Suara terdengar |
| H13 | Integrasi `SFX_TRIGGER` dari game C. Laporan utilisasi (LUT/FF/BRAM/DSP) + timing | Tabel resource |
| H14–H15 | Bab laporan, diagram blok PL, bantu demo | M6 |

**Versi 2 minggu:**
- Port VHDL + simulasi di H2–H3, HDMI di board H4.
- Register + block design H5, renderer digabung H6, M4 di H7.
- **Suara dihapus.**

## 5. Definisi selesai
- [ ] Testbench VHDL timing PASS + frame `.ppm` identik dengan referensi Python
- [ ] Foto monitor: bar warna, grid dengan bingkai di keempat tepi, kotak memantul
- [ ] Simulasi register: shadow tidak bocor sebelum vblank + commit
- [ ] Bitstream lengkap + `.xsa` diserahkan, alamat dasar tercatat di README
- [ ] Timing met (WNS ≥ 0), tabel utilisasi
- [ ] Efek suara flap/skor/tabrak terdengar (bila suara masuk cakupan)
- [ ] Block design tersimpan sebagai TCL di repo

## 6. Risiko dan jalan keluar
| Masalah | Jalan keluar |
|---|---|
| Monitor "No signal" | LED locked menyala? HPD menyala? Coba monitor lain. Cek pin TMDS di XDC |
| Hijau dan biru tertukar | Urutan `vid_pData` rgb2dvi adalah {R, B, G}. Tukar urutan |
| Timing gagal | Tambah register pipeline di renderer (koordinasikan `RENDER_LATENCY` dengan E) |
| Data register sobek saat menyeberang domain clock | Pakai clock AXI = clock piksel (rekomendasi). Bila berbeda clock, gunakan handshake `commit` 2-FF + `commit_pending` |
| Codec diam | Cek `ac_muten` (aktif rendah), cek ACK I2C di simulasi/ILA, cek MCLK. Cadangan: konfigurasi codec lewat AXI IIC dari PS (bantuan A) |
| Waktu habis untuk suara | Suara adalah fitur tambahan. Lewati tanpa mengganggu M4/M5 |

## 7. Referensi
- Kode Verilog acuan yang sudah lulus simulasi: `hw/rtl/video_timing.v`, `hw/rtl/test_pattern.v`, `sim/tb_*.v`
- [../../hw/README-VIVADO.md](../../hw/README-VIVADO.md): langkah Vivado dan uji HDMI
- Digilent: `vivado-library` (rgb2dvi), `digilent-xdc` (Zybo-Z7-Master.xdc), Zybo Z7 Reference Manual (HDMI, audio)
- Datasheet Analog Devices SSM2603 (register codec, format I2S)
