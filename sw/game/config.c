/* Parser config.ini sederhana: [section], key = value, komentar ; atau #
 * (termasuk di akhir baris). Nama key unik di seluruh file, jadi section
 * hanya dipakai sebagai keterangan. Key float dikonversi ke fixed-point
 * dengan pembulatan yang sama seperti round(v * 256) di Python. */
#include "config.h"

#include <ctype.h>
#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *key;
    bool is_float;
    size_t offset;
} param_spec_t;

#define P_INT(k)   { #k, false, offsetof(game_params_t, k) }
#define P_FP(k)    { #k, true, offsetof(game_params_t, k##_fp) }

static const param_spec_t SPECS[] = {
    P_FP(gravity), P_FP(flap_velocity), P_FP(max_fall_speed), P_FP(pipe_speed),
    P_INT(pipe_spacing), P_INT(gap_h), P_INT(pipe_width), P_INT(max_gap_delta),
    P_INT(seed), P_INT(bird_x), P_INT(hitbox_margin), P_INT(ceiling_kills),
    P_INT(input_latency_ms), P_INT(min_flap_interval_ms),
};
#define N_SPECS (sizeof SPECS / sizeof SPECS[0])

static char *trim(char *s)
{
    while (isspace((unsigned char)*s))
        s++;
    char *e = s + strlen(s);
    while (e > s && isspace((unsigned char)e[-1]))
        *--e = '\0';
    return s;
}

int config_load(const char *path, game_params_t *params)
{
    FILE *f = fopen(path, "r");
    if (!f)
        return -1;
    bool found[N_SPECS] = { false };
    char line[256];
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, ";#\r\n")] = '\0';
        char *s = trim(line);
        if (*s == '\0' || *s == '[')
            continue;
        char *eq = strchr(s, '=');
        if (!eq)
            continue;
        *eq = '\0';
        char *key = trim(s), *val = trim(eq + 1);
        for (size_t i = 0; i < N_SPECS; i++) {
            if (strcmp(key, SPECS[i].key) != 0)
                continue;
            int32_t *dst = (int32_t *)((char *)params + SPECS[i].offset);
            *dst = SPECS[i].is_float ? (int32_t)lround(strtod(val, NULL) * FP)
                                     : (int32_t)strtol(val, NULL, 10);
            found[i] = true;
        }
    }
    fclose(f);
    int rc = 0;
    for (size_t i = 0; i < N_SPECS; i++) {
        if (!found[i]) {
            fprintf(stderr, "config: key '%s' tidak ada di %s\n", SPECS[i].key, path);
            rc = -2;
        }
    }
    return rc;
}
