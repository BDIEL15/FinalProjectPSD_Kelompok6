/* Uji jejak: jalankan game dengan daftar frame tekan yang sama dengan model
 * Python, lalu cetak satu baris CSV per frame. Formatnya harus sama persis
 * dengan trace_row() di tools/game_model.py.
 *
 *   game_trace <config.ini> <presses.txt> <frames> <latency_ms> <min_interval_ms>
 */
#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "game.h"

int main(int argc, char **argv)
{
    if (argc != 6) {
        fprintf(stderr, "pakai: %s config.ini presses.txt frames latency_ms min_interval_ms\n", argv[0]);
        return 2;
    }
    game_params_t p;
    int rc = config_load(argv[1], &p);
    if (rc != 0) {
        fprintf(stderr, "gagal membaca %s (%d)\n", argv[1], rc);
        return 1;
    }
    p.input_latency_ms = atoi(argv[4]);
    p.min_flap_interval_ms = atoi(argv[5]);

    FILE *pf = fopen(argv[2], "r");
    if (!pf) {
        fprintf(stderr, "tidak bisa membuka %s\n", argv[2]);
        return 1;
    }
    long frames = atol(argv[3]);
    long next_press = -1;
    if (fscanf(pf, "%ld", &next_press) != 1)
        next_press = -1;

    static game_t g;
    game_init(&g, &p);
    for (long i = 0; i < frames; i++) {
        while (next_press == g.frame) {
            game_press(&g);
            if (fscanf(pf, "%ld", &next_press) != 1)
                next_press = -1;
        }
        game_step(&g);

        printf("%d,%d,%d,", g.frame, (int)g.state, g.state_frame);
        if (g.state == ST_MENU)
            printf("-,");
        else
            printf("%d,", g.bird_y);
        printf("%d,%d,%d", g.bird_vy, g.score, g.scroll);
        for (int k = 0; k < PIPE_SLOTS; k++)
            printf(",%d,%d,%d", g.pipes[k].x, g.pipes[k].gap_y, g.pipes[k].scored ? 1 : 0);
        printf("\n");
    }
    fclose(pf);
    return 0;
}
