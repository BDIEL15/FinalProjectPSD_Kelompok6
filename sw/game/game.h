/* Logika game Jump-to-Flap (port dari tools/game_model.py).
 *
 * Murni: tanpa I/O dan tanpa float di jalur PLAY, sehingga bisa diuji di PC
 * dan hasilnya identik frame demi frame dengan model Python
 * (lihat tools/trace_compare.py). Satuan posisi fixed-point x256 (FP).
 */
#ifndef GAME_H
#define GAME_H

#include <stdbool.h>
#include <stdint.h>

/* Konstanta layar: harus sama dengan game_model.py dan renderer PL. */
#define SCREEN_W        640
#define SCREEN_H        480
#define GROUND_Y        416
#define BIRD_SIZE       32
#define PIPE_SLOTS      4       /* = register PIPE0..3 */
#define PIPE_CAP_H      20
#define PIPE_CAP_EXTRA  4
#define GAP_MARGIN      40
#define FPS             60
#define FP              256

#define COUNTDOWN_FRAMES       (3 * FPS)
#define GAME_OVER_LOCK_FRAMES  (FPS / 2)
#define FLAP_QUEUE_LEN         16

typedef enum { ST_MENU = 0, ST_COUNTDOWN = 1, ST_PLAY = 2, ST_GAME_OVER = 3 } game_state_t;

/* Parameter dari sw/config.ini. Nilai *_fp sudah dikali FP dan dibulatkan. */
typedef struct {
    int32_t gravity_fp;
    int32_t flap_velocity_fp;
    int32_t max_fall_speed_fp;
    int32_t pipe_speed_fp;
    int32_t pipe_spacing;
    int32_t gap_h;
    int32_t pipe_width;
    int32_t max_gap_delta;
    int32_t seed;
    int32_t bird_x;
    int32_t hitbox_margin;
    int32_t ceiling_kills;
    int32_t input_latency_ms;
    int32_t min_flap_interval_ms;
} game_params_t;

typedef struct {
    int32_t x;        /* fixed-point, tepi kiri batang */
    int32_t gap_y;    /* piksel, tepi atas celah */
    bool scored;
} pipe_t;

typedef struct {
    game_params_t p;
    game_state_t state;
    int32_t frame;        /* penghitung frame global */
    int32_t state_frame;
    int32_t score;
    int32_t scroll;       /* fixed-point; SCROLL_X = scroll / FP */
    int32_t bird_y;       /* fixed-point */
    int32_t bird_vy;      /* fixed-point per frame */
    uint32_t rng;
    pipe_t pipes[PIPE_SLOTS];
    int32_t last_flap_frame;
    int32_t flap_due[FLAP_QUEUE_LEN];   /* frame jatuh tempo flap tertunda */
    int flap_count;
} game_t;

void game_init(game_t *g, const game_params_t *p);
void game_reset_to_menu(game_t *g);
/* Dipanggil saat tombol/lompatan terdeteksi. false = diabaikan (terlalu rapat). */
bool game_press(game_t *g);
/* Satu langkah 1/60 detik, sekali per vblank. */
void game_step(game_t *g);
/* Pipa terdekat yang belum dilewati burung, atau NULL. */
const pipe_t *game_next_pipe(const game_t *g);

/* Pembagian bulat ke bawah (sama dengan // di Python, juga untuk negatif). */
static inline int32_t fdiv(int32_t a, int32_t b)
{
    int32_t q = a / b;
    return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q;
}

#endif
