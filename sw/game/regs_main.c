/* Pencetak register: jalankan game C seperti uji jejak, lalu cetak isi
 * register (hasil render_regs) per frame. Dipakai tools/render_check.py dan
 * nanti oleh testbench renderer E sebagai skenario.
 *
 *   game_regs --selftest
 *   game_regs <config.ini> <presses.txt> <frames> <latency_ms> <min_interval_ms>
 *
 * Format keluaran: satu baris per frame,
 *   <frame> <reg 0x00> <reg 0x04> ... <reg 0x7C>     (32 angka hex 8 digit)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "game.h"
#include "render_regs.h"

static int failures;

static void expect(const char *name, uint32_t got, uint32_t want)
{
    if (got != want) {
        printf("[FAIL] %s: 0x%08X, seharusnya 0x%08X\n", name, (unsigned)got, (unsigned)want);
        failures++;
    } else {
        printf("[PASS] %s\n", name);
    }
}

static game_params_t default_params(void)
{
    game_params_t p = {
        .gravity_fp = 31, .flap_velocity_fp = 768, .max_fall_speed_fp = 1280,
        .pipe_speed_fp = 384, .pipe_spacing = 300, .gap_h = 170, .pipe_width = 64,
        .max_gap_delta = 110, .seed = 12345, .bird_x = 160, .hitbox_margin = 5,
    };
    return p;
}

static int selftest(void)
{
    static game_t g;
    uint32_t r[REG_COUNT] = { 0 };
    game_params_t p = default_params();
    game_init(&g, &p);

    expect("BCD 0", render_score_bcd(0), 0x0000);
    expect("BCD 12", render_score_bcd(12), 0x0012);
    expect("BCD 9087", render_score_bcd(9087), 0x9087);
    expect("BCD dipotong 12345 -> 9999", render_score_bcd(12345), 0x9999);

    /* MENU: semua pipa di kanan luar layar -> tidak terlihat. */
    render_regs_frame(&g, r);
    expect("MENU: TEXT_ID", r[REG_IDX(REG_TEXT_ID)], TEXT_MENU);
    for (int i = 0; i < PIPE_SLOTS; i++)
        expect("MENU: pipa di luar layar invisible", r[REG_IDX(REG_PIPE(i))] & PIPE_VISIBLE, 0);
    expect("PIPE_CFG gap 170 lebar 64", r[REG_IDX(REG_PIPE_CFG)], 170u | (64u << 9));

    /* Pipa sebagian di kiri: x negatif harus terkode two's complement. */
    g.state = ST_PLAY;
    g.pipes[0].x = -40 * FP;
    g.pipes[0].gap_y = 120;
    g.pipes[1].x = -(64 + 4) * FP;     /* tepat hilang: tutup berakhir di x = -1 */
    g.pipes[2].x = 643 * FP;           /* tutup mulai di x = 639: masih terlihat */
    g.pipes[3].x = 644 * FP;           /* tutup mulai di x = 640: hilang */
    render_regs_frame(&g, r);
    uint32_t p0 = r[REG_IDX(REG_PIPE(0))];
    expect("pipa x=-40 visible", p0 & PIPE_VISIBLE, PIPE_VISIBLE);
    expect("pipa x=-40 terkode", (uint32_t)render_pipe_x(p0), (uint32_t)-40);
    expect("pipa gap_y", (p0 >> 12) & 0x1FF, 120);
    expect("pipa x=-68 invisible", r[REG_IDX(REG_PIPE(1))] & PIPE_VISIBLE, 0);
    expect("pipa x=643 visible", r[REG_IDX(REG_PIPE(2))] & PIPE_VISIBLE, PIPE_VISIBLE);
    expect("pipa x=644 invisible", r[REG_IDX(REG_PIPE(3))] & PIPE_VISIBLE, 0);
    expect("PLAY: TEXT_ID kosong", r[REG_IDX(REG_TEXT_ID)], TEXT_NONE);

    /* Countdown 3-2-1 lalu PLAY. */
    game_init(&g, &p);
    game_press(&g);
    game_step(&g);                                  /* MENU -> COUNTDOWN */
    render_regs_frame(&g, r);
    expect("COUNTDOWN awal = 3", r[REG_IDX(REG_COUNTDOWN)], 3);
    for (int i = 0; i < 2 * FPS; i++)
        game_step(&g);
    render_regs_frame(&g, r);
    expect("COUNTDOWN setelah 2 s = 1", r[REG_IDX(REG_COUNTDOWN)], 1);
    while (g.state == ST_COUNTDOWN)
        game_step(&g);
    render_regs_frame(&g, r);
    expect("PLAY: COUNTDOWN 0", r[REG_IDX(REG_COUNTDOWN)], 0);

    /* Tanpa flap: burung jatuh, SFX tabrak terpicu tepat sekali. */
    int hits = 0;
    while (g.state == ST_PLAY) {
        game_step(&g);
        render_regs_frame(&g, r);
        hits += (r[REG_IDX(REG_SFX_TRIGGER)] & SFX_HIT) != 0;
    }
    expect("SFX tabrak sekali", (uint32_t)hits, 1);
    game_step(&g);
    render_regs_frame(&g, r);
    expect("GAME_OVER: TEXT_ID", r[REG_IDX(REG_TEXT_ID)], TEXT_GAME_OVER);
    expect("GAME_OVER: frame burung 1", r[REG_IDX(REG_BIRD_ATTR)] & 3u, 1);
    expect("GAME_OVER: SFX diam", r[REG_IDX(REG_SFX_TRIGGER)], 0);

    printf("REGS SELFTEST %s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}

int main(int argc, char **argv)
{
    if (argc == 2 && strcmp(argv[1], "--selftest") == 0)
        return selftest();
    if (argc != 6) {
        fprintf(stderr, "pakai: %s --selftest\n"
                        "       %s config.ini presses.txt frames latency_ms min_interval_ms\n",
                argv[0], argv[0]);
        return 2;
    }
    game_params_t p;
    if (config_load(argv[1], &p) != 0) {
        fprintf(stderr, "gagal membaca %s\n", argv[1]);
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
    uint32_t r[REG_COUNT] = { 0 };
    game_init(&g, &p);
    render_regs_palette(r);
    for (long i = 0; i < frames; i++) {
        while (next_press == g.frame) {
            game_press(&g);
            if (fscanf(pf, "%ld", &next_press) != 1)
                next_press = -1;
        }
        game_step(&g);
        render_regs_frame(&g, r);
        printf("%d", g.frame);
        for (unsigned k = 0; k < REG_COUNT; k++)
            printf(" %08X", (unsigned)r[k]);
        printf("\n");
    }
    fclose(pf);
    return 0;
}
