/* Register map v1 akselerator grafis (AXI-Lite, 32-bit).
 * Sumber kebenaran: docs/tugas/README.md §3.1. Harus sama dengan
 * hw/vhdl/system/gfx_pkg.vhd dan tools/ref_render.py. Perubahan lewat
 * koordinator dan disetujui D + E.
 *
 * Offset dalam byte. Register (S) = shadow: baru dipakai renderer pada
 * awal vblank setelah CTRL.commit ditulis.
 */
#ifndef REGS_H
#define REGS_H

#include <stdint.h>

#define REG_CTRL         0x00u   /* [0] enable [1] test_pattern [2] commit (self-clear) */
#define REG_STATUS       0x04u   /* RO: [0] in_vblank [1] commit_pending [7:4] btn [11:8] sw [31:16] frame_count */
#define REG_BIRD_POS     0x08u   /* S: [9:0] x  [25:16] y  (kiri-atas sprite 32x32) */
#define REG_BIRD_ATTR    0x0Cu   /* S: [1:0] frame animasi [2] visible [3] flash */
#define REG_PIPE(i)      (0x10u + 4u * (unsigned)(i))  /* S: [10:0] x signed [20:12] gap_y [31] visible */
#define REG_PIPE_CFG     0x20u   /* S: [8:0] gap_h  [15:9] width */
#define REG_SCROLL_X     0x24u   /* S: [9:0] pergeseran lantai (piksel) */
#define REG_SCORE        0x28u   /* S: [15:0] BCD 4 digit */
#define REG_TEXT_ID      0x2Cu   /* S: [3:0] lihat TEXT_* */
#define REG_COUNTDOWN    0x30u   /* S: [3:0] 0 = tidak tampil */
#define REG_IRQ          0x34u   /* [0] en_vblank [1] ack (opsional) */
#define REG_SFX_TRIGGER  0x38u   /* langsung: [0] flap [1] skor [2] tabrak (self-clear) */
#define REG_AUDIO_CTRL   0x3Cu   /* [0] enable [7:4] volume */
#define REG_PALETTE(i)   (0x40u + 4u * (unsigned)(i))  /* [23:0] RGB888, i = 0..15 */

#define REG_SPAN         0x80u   /* ukuran ruang register */
#define REG_COUNT        (REG_SPAN / 4u)
#define REG_IDX(off)     ((off) / 4u)

#define CTRL_ENABLE        (1u << 0)
#define CTRL_TEST_PATTERN  (1u << 1)
#define CTRL_COMMIT        (1u << 2)

#define STATUS_IN_VBLANK       (1u << 0)
#define STATUS_COMMIT_PENDING  (1u << 1)
#define STATUS_BTN(v)          (((v) >> 4) & 0xFu)    /* tombol BTN0..3 */
#define STATUS_SW(v)           (((v) >> 8) & 0xFu)    /* switch SW0..3 */
#define STATUS_FRAME(v)        (((v) >> 16) & 0xFFFFu)

#define BIRD_ATTR_VISIBLE  (1u << 2)
#define BIRD_ATTR_FLASH    (1u << 3)

#define PIPE_X_MASK        0x7FFu    /* 11-bit two's complement */
#define PIPE_VISIBLE       (1u << 31)

#define SFX_FLAP   (1u << 0)
#define SFX_SCORE  (1u << 1)
#define SFX_HIT    (1u << 2)

enum {
    TEXT_NONE = 0, TEXT_MENU = 1, TEXT_CALIBRATE = 2, TEXT_READY = 3,
    TEXT_PAUSE = 4, TEXT_GAME_OVER = 5, TEXT_NO_CAMERA = 6,
};

/* Indeks palet default (nilai RGB di render_regs.c, sama dengan ref_render.py).
 * Indeks 0 = transparan untuk sprite burung. */
enum {
    PAL_TRANSPARENT = 0, PAL_OUTLINE = 1, PAL_BIRD = 2, PAL_BEAK = 3,
    PAL_EYE = 4, PAL_WING = 5, PAL_PIPE = 6, PAL_PIPE_LIGHT = 7,
    PAL_PIPE_DARK = 8, PAL_GROUND_TOP = 9, PAL_GROUND_A = 10, PAL_GROUND_B = 11,
    PAL_TEXT_SHADOW = 12, PAL_SPARE = 13, PAL_SKY_BASE = 14, PAL_TEXT = 15,
};

#endif
