/* State game -> register (lihat render_regs.h). Aturan tampilan yang
 * dipakai di sini (frame animasi, kapan pipa terlihat, teks per state)
 * sama dengan jendela tools/game_model.py. */
#include "render_regs.h"

#define RGB(r, g, b) (((uint32_t)(r) << 16) | ((uint32_t)(g) << 8) | (uint32_t)(b))

const uint32_t RENDER_DEFAULT_PALETTE[16] = {
    [PAL_TRANSPARENT] = RGB(0, 0, 0),
    [PAL_OUTLINE]     = RGB(40, 40, 40),
    [PAL_BIRD]        = RGB(250, 210, 60),
    [PAL_BEAK]        = RGB(240, 120, 40),
    [PAL_EYE]         = RGB(255, 255, 255),
    [PAL_WING]        = RGB(255, 240, 170),
    [PAL_PIPE]        = RGB(90, 190, 70),
    [PAL_PIPE_LIGHT]  = RGB(150, 230, 110),
    [PAL_PIPE_DARK]   = RGB(30, 80, 30),
    [PAL_GROUND_TOP]  = RGB(90, 180, 60),
    [PAL_GROUND_A]    = RGB(222, 200, 120),
    [PAL_GROUND_B]    = RGB(204, 180, 100),
    [PAL_TEXT_SHADOW] = RGB(0, 0, 0),
    [PAL_SPARE]       = RGB(230, 60, 60),
    [PAL_SKY_BASE]    = RGB(90, 160, 230),
    [PAL_TEXT]        = RGB(255, 255, 255),
};

#define ANIM_PERIOD_FRAMES 6   /* ganti frame sayap tiap 6 frame (10 Hz) */
#define GAME_OVER_BIRD_FRAME 1

void render_regs_palette(uint32_t regs[REG_COUNT])
{
    for (unsigned i = 0; i < 16; i++)
        regs[REG_IDX(REG_PALETTE(i))] = RENDER_DEFAULT_PALETTE[i];
}

uint32_t render_score_bcd(int32_t score)
{
    if (score < 0)
        score = 0;
    if (score > 9999)
        score = 9999;
    uint32_t bcd = 0;
    for (int shift = 0; shift < 16; shift += 4) {
        bcd |= (uint32_t)(score % 10) << shift;
        score /= 10;
    }
    return bcd;
}

int32_t render_pipe_x(uint32_t reg)
{
    int32_t x = (int32_t)(reg & PIPE_X_MASK);
    return (x & 0x400) ? x - 0x800 : x;
}

static uint32_t clamp_u(int32_t v, int32_t lo, int32_t hi)
{
    return (uint32_t)(v < lo ? lo : (v > hi ? hi : v));
}

static uint32_t text_for_state(game_state_t s)
{
    switch (s) {
    case ST_MENU:      return TEXT_MENU;
    case ST_COUNTDOWN: return TEXT_READY;
    case ST_GAME_OVER: return TEXT_GAME_OVER;
    default:           return TEXT_NONE;
    }
}

void render_regs_frame(const game_t *g, uint32_t regs[REG_COUNT])
{
    const game_params_t *p = &g->p;

    regs[REG_IDX(REG_CTRL)] = CTRL_ENABLE;   /* commit ditulis terpisah oleh main.c */

    /* Burung: koordinat piksel, y tidak pernah negatif di logika game. */
    uint32_t bx = clamp_u(p->bird_x, 0, SCREEN_W - 1);
    uint32_t by = clamp_u(fdiv(g->bird_y, FP), 0, SCREEN_H - 1);
    regs[REG_IDX(REG_BIRD_POS)] = bx | (by << 16);
    uint32_t frame = (g->state == ST_GAME_OVER)
                         ? GAME_OVER_BIRD_FRAME
                         : (uint32_t)((g->frame / ANIM_PERIOD_FRAMES) % 4);
    regs[REG_IDX(REG_BIRD_ATTR)] = frame | BIRD_ATTR_VISIBLE;

    /* Pipa: visible hanya bila sebagian tutup/batang ada di layar. Ini juga
     * menjaga x tetap muat di field 11-bit (pipa baru muncul di x ~1640). */
    for (int i = 0; i < PIPE_SLOTS; i++) {
        int32_t px = fdiv(g->pipes[i].x, FP);
        uint32_t v = 0;
        if (px + p->pipe_width + PIPE_CAP_EXTRA > 0 && px - PIPE_CAP_EXTRA < SCREEN_W) {
            v = ((uint32_t)px & PIPE_X_MASK)
              | (clamp_u(g->pipes[i].gap_y, 0, 511) << 12)
              | PIPE_VISIBLE;
        }
        regs[REG_IDX(REG_PIPE(i))] = v;
    }
    regs[REG_IDX(REG_PIPE_CFG)] = clamp_u(p->gap_h, 0, 511) | (clamp_u(p->pipe_width, 0, 127) << 9);
    regs[REG_IDX(REG_SCROLL_X)] = (uint32_t)fdiv(g->scroll, FP) & 0x3FFu;

    regs[REG_IDX(REG_SCORE)] = render_score_bcd(g->score);
    regs[REG_IDX(REG_TEXT_ID)] = text_for_state(g->state);
    uint32_t cd = 0;
    if (g->state == ST_COUNTDOWN) {
        int32_t n = 3 - g->state_frame / FPS;
        cd = (uint32_t)(n < 1 ? 1 : n);
    }
    regs[REG_IDX(REG_COUNTDOWN)] = cd;

    uint32_t sfx = 0;
    if (g->events & GAME_EV_FLAP)
        sfx |= SFX_FLAP;
    if (g->events & GAME_EV_SCORE)
        sfx |= SFX_SCORE;
    if (g->events & GAME_EV_HIT)
        sfx |= SFX_HIT;
    regs[REG_IDX(REG_SFX_TRIGGER)] = sfx;
}
