/* Port 1:1 dari kelas Game di tools/game_model.py. Urutan operasi sengaja
 * dibuat sama agar uji jejak identik. */
#include "game.h"

#include <math.h>
#include <stddef.h>

#define BIRD_CENTER_Y ((GROUND_Y / 2 - BIRD_SIZE / 2) * FP)

static int32_t min32(int32_t a, int32_t b) { return a < b ? a : b; }
static int32_t max32(int32_t a, int32_t b) { return a > b ? a : b; }

/* LCG 31-bit, sama dengan Rng di Python. */
static int32_t rng_next(game_t *g)
{
    g->rng = (g->rng * 1103515245u + 12345u) & 0x7FFFFFFFu;
    return (int32_t)(g->rng >> 16);
}

static void gap_limits(const game_t *g, int32_t *lo, int32_t *hi)
{
    *lo = GAP_MARGIN;
    *hi = max32(*lo, GROUND_Y - GAP_MARGIN - g->p.gap_h);
}

static int32_t next_gap(game_t *g, int32_t prev)
{
    int32_t lo, hi;
    int32_t d = g->p.max_gap_delta;
    gap_limits(g, &lo, &hi);
    int32_t r = rng_next(g);
    int32_t gp = prev + (r % (2 * d + 1)) - d;
    return max32(lo, min32(hi, gp));
}

static void set_state(game_t *g, game_state_t s)
{
    g->state = s;
    g->state_frame = 0;
}

void game_reset_to_menu(game_t *g)
{
    g->state = ST_MENU;
    g->state_frame = 0;
    g->score = 0;
    g->bird_y = BIRD_CENTER_Y;
    g->bird_vy = 0;
    g->rng = (uint32_t)g->p.seed & 0x7FFFFFFFu;
    g->flap_count = 0;
    int32_t prev = (GROUND_Y - g->p.gap_h) / 2;
    for (int i = 0; i < PIPE_SLOTS; i++) {
        int32_t gap = next_gap(g, prev);
        g->pipes[i].x = (SCREEN_W + 100 + i * g->p.pipe_spacing) * FP;
        g->pipes[i].gap_y = gap;
        g->pipes[i].scored = false;
        prev = gap;
    }
}

void game_init(game_t *g, const game_params_t *p)
{
    g->p = *p;
    g->frame = 0;
    g->scroll = 0;
    g->last_flap_frame = -1000000000;
    g->events = 0;
    game_reset_to_menu(g);
}

bool game_press(game_t *g)
{
    int32_t min_frames = g->p.min_flap_interval_ms * FPS / 1000;
    if (g->frame - g->last_flap_frame < min_frames)
        return false;
    g->last_flap_frame = g->frame;
    if (g->flap_count >= FLAP_QUEUE_LEN)
        return false;   /* antrian penuh: hanya mungkin bila latensi sangat besar */
    int32_t delay = g->p.input_latency_ms * FPS / 1000;
    g->flap_due[g->flap_count++] = g->frame + delay;
    return true;
}

/* Ambil semua flap yang sudah jatuh tempo; true bila ada minimal satu. */
static bool take_flap(game_t *g)
{
    bool any = false;
    int n = 0;
    for (int i = 0; i < g->flap_count; i++) {
        if (g->flap_due[i] <= g->frame)
            any = true;
        else
            g->flap_due[n++] = g->flap_due[i];
    }
    g->flap_count = n;
    return any;
}

static bool collides(const game_t *g)
{
    int32_t m = g->p.hitbox_margin;
    int32_t by = fdiv(g->bird_y, FP);
    int32_t l = g->p.bird_x + m, t = by + m;
    int32_t r = g->p.bird_x + BIRD_SIZE - m, b = by + BIRD_SIZE - m;
    if (b >= GROUND_Y)
        return true;
    if (g->p.ceiling_kills && t <= 0)
        return true;
    for (int i = 0; i < PIPE_SLOTS; i++) {
        int32_t px = fdiv(g->pipes[i].x, FP);
        if (px < r && px + g->p.pipe_width > l) {
            if (t < g->pipes[i].gap_y || b > g->pipes[i].gap_y + g->p.gap_h)
                return true;
        }
    }
    return false;
}

static void fall(game_t *g)
{
    g->bird_vy = min32(g->bird_vy + g->p.gravity_fp, g->p.max_fall_speed_fp);
}

void game_step(game_t *g)
{
    bool flap = take_flap(g);
    g->events = 0;
    g->frame++;
    g->state_frame++;

    if (g->state != ST_GAME_OVER)
        g->scroll = (g->scroll + g->p.pipe_speed_fp) % (10000 * FP);

    if (g->state == ST_MENU) {
        /* Mengambang naik-turun; hanya tampilan, di-snap saat start. */
        g->bird_y = BIRD_CENTER_Y + (int32_t)(6.0 * FP * sin(g->frame / 20.0));
        if (flap) {
            g->bird_y = BIRD_CENTER_Y;
            set_state(g, ST_COUNTDOWN);
        }
        return;
    }

    if (g->state == ST_COUNTDOWN) {
        if (g->state_frame >= COUNTDOWN_FRAMES) {
            set_state(g, ST_PLAY);
            g->bird_vy = -g->p.flap_velocity_fp;
        }
        return;
    }

    if (g->state == ST_GAME_OVER) {
        /* Burung jatuh ke lantai, lalu menunggu tombol. */
        if (fdiv(g->bird_y, FP) + BIRD_SIZE < GROUND_Y) {
            fall(g);
            g->bird_y = min32(g->bird_y + g->bird_vy, (GROUND_Y - BIRD_SIZE) * FP);
        }
        if (flap && g->state_frame >= GAME_OVER_LOCK_FRAMES) {
            game_reset_to_menu(g);
            set_state(g, ST_COUNTDOWN);
        }
        return;
    }

    /* ---- PLAY ---- */
    if (flap) {
        g->bird_vy = -g->p.flap_velocity_fp;
        g->events |= GAME_EV_FLAP;
    }
    fall(g);
    g->bird_y += g->bird_vy;
    if (g->bird_y < 0) {
        g->bird_y = 0;
        g->bird_vy = 0;
    }

    int32_t w = g->p.pipe_width;
    int32_t bird_center = g->p.bird_x + BIRD_SIZE / 2;
    for (int i = 0; i < PIPE_SLOTS; i++)
        g->pipes[i].x -= g->p.pipe_speed_fp;
    for (int i = 0; i < PIPE_SLOTS; i++) {
        pipe_t *q = &g->pipes[i];
        if (fdiv(q->x, FP) + w <= -PIPE_CAP_EXTRA) {
            /* Pipa paling kanan (yang pertama bila seri, seperti max() Python). */
            const pipe_t *right = &g->pipes[0];
            for (int j = 1; j < PIPE_SLOTS; j++)
                if (g->pipes[j].x > right->x)
                    right = &g->pipes[j];
            int32_t rx = right->x, rgap = right->gap_y;
            q->x = rx + g->p.pipe_spacing * FP;
            q->gap_y = next_gap(g, rgap);
            q->scored = false;
        }
        if (!q->scored && fdiv(q->x, FP) + w / 2 < bird_center) {
            q->scored = true;
            g->score++;
            g->events |= GAME_EV_SCORE;
        }
    }

    if (collides(g)) {
        set_state(g, ST_GAME_OVER);
        g->events |= GAME_EV_HIT;
    }
}

const pipe_t *game_next_pipe(const game_t *g)
{
    const pipe_t *best = NULL;
    for (int i = 0; i < PIPE_SLOTS; i++) {
        const pipe_t *q = &g->pipes[i];
        if (fdiv(q->x, FP) + g->p.pipe_width > g->p.bird_x && (!best || q->x < best->x))
            best = q;
    }
    return best;
}
