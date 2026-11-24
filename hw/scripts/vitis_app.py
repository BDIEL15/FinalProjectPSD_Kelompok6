"""Buat dan build aplikasi bare-metal Jump-to-Flap dengan Vitis Unified IDE.

  vitis -s hw/scripts/vitis_app.py          (jalankan dari folder root repo)

Masukan : hw/out/system/system.xsa (dari hw/scripts/build_system.tcl)
Hasil   : sw/vitis_ws/ (workspace, tidak di-commit)
          sw/vitis_ws/jump_to_flap/build/jump_to_flap.elf

Isi aplikasi: sw/game/{main,game,render_regs,config_default}.c + header,
dan sw/platform/platform_baremetal.c. File uji PC (trace_main, regs_main,
board_sim, config.c, platform_pc) TIDAK ikut.

Ditulis untuk API Python Vitis Unified (2023.2+) sebelum Vitis 2026.1
tersedia di laptop pengembang. Bila nama fungsi berubah di versi ini, lihat
"Vitis Python API" di dokumentasi versi tersebut atau ikuti langkah GUI
cadangan di hw/README-VIVADO.md (hasilnya sama).
"""

import os
import shutil

import vitis  # modul bawaan `vitis -s`

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
XSA = os.path.join(ROOT, "hw", "out", "system", "system.xsa")
WS = os.path.join(ROOT, "sw", "vitis_ws")
PLATFORM = "zybo_jump_platform"
APP = "jump_to_flap"
DOMAIN = "standalone_ps7_cortexa9_0"

GAME_FILES = ["main.c", "game.c", "game.h", "render_regs.c", "render_regs.h",
              "regs.h", "config_default.c"]
PLATFORM_FILES = ["platform.h", "platform_baremetal.c"]

if not os.path.exists(XSA):
    raise SystemExit(f"{XSA} belum ada: jalankan dulu vivado -mode batch -source hw/scripts/build_system.tcl")

if os.path.exists(WS):
    shutil.rmtree(WS)
os.makedirs(WS)

client = vitis.create_client()
client.set_workspace(path=WS)

platform = client.create_platform_component(
    name=PLATFORM, hw_design=XSA, os="standalone", cpu="ps7_cortexa9_0",
    domain_name=DOMAIN)
platform.build()
xpfm = os.path.join(WS, PLATFORM, "export", PLATFORM, f"{PLATFORM}.xpfm")

app = client.create_app_component(name=APP, platform=xpfm, domain=DOMAIN,
                                  template="empty_application")
# Struktur folder sama dengan repo (src/game, src/platform) supaya
# #include "../platform/platform.h" dan "../game/regs.h" tetap berlaku.
app.import_files(from_loc=os.path.join(ROOT, "sw", "game"), files=GAME_FILES,
                 dest_dir_in_cmp="src/game")
app.import_files(from_loc=os.path.join(ROOT, "sw", "platform"), files=PLATFORM_FILES,
                 dest_dir_in_cmp="src/platform")
app.build()

elf = os.path.join(WS, APP, "build", f"{APP}.elf")
print(f"BUILD OK: {elf}" if os.path.exists(elf) else f"Periksa log build: {elf} tidak ditemukan")
vitis.dispose()
