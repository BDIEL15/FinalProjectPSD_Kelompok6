/* main.c -- loop utama game di ARM (sama untuk board dan uji PC).
 *
 * Tiap frame (60x per detik, mengikuti vblank dari hardware):
 *   1. tunggu awal vblank (STATUS.frame_count berubah)
 *   2. baca input: BTN0 = flap, BTN1 = kembali ke menu,
 *      byte 'F' dari UART = flap (Cadangan A: detektor di laptop)
 *   3. game_step -> render_regs_frame -> tulis register shadow
 *   4. commit: hardware menyalin shadow ke aktif pada vblank berikutnya,
 *      jadi gambar tidak pernah sobek.
 *
 * Parameter game diambil dari config_default.c (dihasilkan dari config.ini).
 */
#include <stdint.h>

#include "game.h"
#include "regs.h"
#include "render_regs.h"
#include "../platform/platform.h"

extern const game_params_t GAME_DEFAULT_PARAMS;

/* Register shadow yang ditulis tiap frame (BIRD_POS .. COUNTDOWN). */
static void write_frame_regs(const uint32_t regs[REG_COUNT])
{
    for (uint32_t off = REG_BIRD_POS; off <= REG_COUNTDOWN; off += 4u)
        gfx_write(off, regs[REG_IDX(off)]);
    uint32_t sfx = regs[REG_IDX(REG_SFX_TRIGGER)];
    if (sfx)
        gfx_write(REG_SFX_TRIGGER, sfx);
}

/* Jalankan game. max_frames = 0 berarti selamanya (board). */
int jump_to_flap_run(uint32_t max_frames)
{
    static game_t g;
    static uint32_t regs[REG_COUNT];

    if (gfx_open() != 0)
        return 1;
    game_init(&g, &GAME_DEFAULT_PARAMS);

    /* palet sekali di awal; ikut diterapkan bersama commit pertama */
    render_regs_palette(regs);
    for (unsigned i = 0; i < 16; i++)
        gfx_write(REG_PALETTE(i), regs[REG_IDX(REG_PALETTE(i))]);

    uint32_t prev_btn = 0;
    for (uint32_t n = 0; max_frames == 0 || n < max_frames; n++) {
        gfx_wait_vblank();

        uint32_t b = btn_read();
        uint32_t rise = b & ~prev_btn;      /* hanya tepi tekan, bukan tahan */
        prev_btn = b;
        if (rise & BTN_MENU)
            game_reset_to_menu(&g);
        if (rise & BTN_FLAP)
            game_press(&g);
        for (int c = uart_read_flap(); c >= 0; c = uart_read_flap()) {
            if (c == 'F')
                game_press(&g);
        }

        game_step(&g);
        render_regs_frame(&g, regs);
        write_frame_regs(regs);
        gfx_commit();
    }
    return 0;
}

#ifndef BOARD_SIM
int main(void)
{
    return jump_to_flap_run(0);
}
#endif
