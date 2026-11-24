"""Tulis sw/game/config_default.c dari sw/config.ini.

Board bare-metal tidak punya sistem file, jadi parameter game ditanam ke
program. Pembulatan fixed-point sama dengan game_model.py (round(v * 256)).

  python tools/gen_config_c.py           tulis ulang file C
  python tools/gen_config_c.py --check   gagal (kode 1) bila file C basi
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import game_model as gm  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "sw", "game", "config_default.c")


def generate():
    p = gm.load_params(gm.DEFAULT_CONFIG)
    fields = []
    for key, (_section, typ) in gm.PARAM_SPEC.items():
        if typ is float:
            fields.append(f"    .{key}_fp = {int(round(p[key] * gm.FP))},   /* {p[key]} */")
        else:
            fields.append(f"    .{key} = {p[key]},")
    body = "\n".join(fields)
    return f"""/* config_default.c -- DIHASILKAN OTOMATIS oleh tools/gen_config_c.py dari
 * sw/config.ini. JANGAN DIEDIT TANGAN: ubah config.ini lalu jalankan ulang. */
#include "game.h"

const game_params_t GAME_DEFAULT_PARAMS = {{
{body}
}};
"""


def main():
    text = generate()
    if sys.argv[1:] == ["--check"]:
        try:
            with open(OUT, encoding="utf-8") as f:
                cur = f.read().replace("\r\n", "\n")
        except FileNotFoundError:
            cur = ""
        if cur != text:
            print("[FAIL] sw/game/config_default.c basi: jalankan python tools/gen_config_c.py")
            return 1
        print("[PASS] config_default.c sesuai sw/config.ini")
        return 0
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"ditulis {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
