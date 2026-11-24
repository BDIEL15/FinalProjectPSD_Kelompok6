/* config_default.c -- DIHASILKAN OTOMATIS oleh tools/gen_config_c.py dari
 * sw/config.ini. JANGAN DIEDIT TANGAN: ubah config.ini lalu jalankan ulang. */
#include "game.h"

const game_params_t GAME_DEFAULT_PARAMS = {
    .gravity_fp = 31,   /* 0.12 */
    .flap_velocity_fp = 768,   /* 3.0 */
    .max_fall_speed_fp = 1280,   /* 5.0 */
    .pipe_speed_fp = 384,   /* 1.5 */
    .pipe_spacing = 300,
    .gap_h = 170,
    .pipe_width = 64,
    .max_gap_delta = 110,
    .seed = 12345,
    .bird_x = 160,
    .hitbox_margin = 5,
    .ceiling_kills = 0,
    .input_latency_ms = 0,
    .min_flap_interval_ms = 0,
};
