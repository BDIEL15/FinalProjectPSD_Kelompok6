/* Pemetaan keadaan game -> nilai register akselerator grafis.
 *
 * Fungsi di sini hanya MENGISI array regs[REG_COUNT] (indeks = offset/4).
 * Menulisnya ke hardware (gfx_write + gfx_commit) adalah tugas main.c memakai
 * lib platform A, sehingga modul ini bisa diuji di PC tanpa board.
 */
#ifndef RENDER_REGS_H
#define RENDER_REGS_H

#include <stdint.h>

#include "game.h"
#include "regs.h"

/* Palet default 16 warna (RGB888), indeks sesuai PAL_* di regs.h. */
extern const uint32_t RENDER_DEFAULT_PALETTE[16];

/* Isi PALETTE0..15 dengan palet default. Cukup sekali saat start. */
void render_regs_palette(uint32_t regs[REG_COUNT]);

/* Isi semua register per frame (CTRL tanpa commit, posisi, skor, teks,
 * SFX_TRIGGER) dari keadaan game setelah game_step(). */
void render_regs_frame(const game_t *g, uint32_t regs[REG_COUNT]);

/* Skor biner -> BCD 4 digit (dipotong ke 0..9999). */
uint32_t render_score_bcd(int32_t score);

/* Field x pipa 11-bit two's complement -> nilai bertanda (untuk uji). */
int32_t render_pipe_x(uint32_t reg);

#endif
