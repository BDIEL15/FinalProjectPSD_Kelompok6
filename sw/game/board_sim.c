/* board_sim.c -- jalankan main.c (loop board) di PC dengan platform_pc.c.
 *
 * "Pemain" tiruan hanya melihat apa yang ada di layar: register AKTIF yang
 * digambar renderer (posisi burung, pipa, skor, teks). Ia menekan BTN0 saat
 * burung di bawah tengah celah pipa berikutnya dan sedang turun, sampai skor 3,
 * lalu berhenti menekan supaya burung jatuh (menguji game over + suara tabrak).
 * Setelah game over ia menekan lagi untuk bermain ulang.
 *
 * Yang dicek: satu commit per frame, enable + palet, skor naik (BCD), pipa
 * terlihat, game over tercapai lalu main lagi, efek suara flap/skor/tabrak,
 * dan BTN1 kembali ke menu. Akses hardware sungguhan (platform_baremetal.c)
 * hanya bisa diuji di Zybo.
 */
#include <stdio.h>

#include "game.h"
#include "regs.h"
#include "../platform/platform.h"

int jump_to_flap_run(uint32_t max_frames);
void platform_pc_script(uint32_t (*fn)(uint32_t frame));
const uint32_t *platform_pc_active(void);
uint32_t platform_pc_frames(void);
uint32_t platform_pc_commits(void);
uint32_t platform_pc_sfx(void);

#define BIRD_X 160

static int failures;
static uint32_t best_score, game_overs, restarts, saw_pipe;

static void expect(int cond, const char *msg)
{
    printf("[%s] %s\n", cond ? "PASS" : "FAIL", msg);
    failures += !cond;
}

static int32_t pipe_x(uint32_t v)
{
    int32_t x = (int32_t)(v & PIPE_X_MASK);
    return (x & 0x400) ? x - 0x800 : x;
}

/* Pemain yang membaca layar (register aktif). Dipanggil sekali per frame. */
static uint32_t screen_player(uint32_t frame)
{
    static int32_t prev_y = 0;
    static uint32_t last_press = 0, prev_text = TEXT_MENU;
    const uint32_t *a = platform_pc_active();
    uint32_t text = a[REG_IDX(REG_TEXT_ID)];
    uint32_t score = a[REG_IDX(REG_SCORE)];
    int32_t y = (int32_t)((a[REG_IDX(REG_BIRD_POS)] >> 16) & 0x3FFu);
    uint32_t press = 0;

    if (score > best_score)
        best_score = score;
    if (text == TEXT_GAME_OVER && prev_text != TEXT_GAME_OVER)
        game_overs++;
    if (text == TEXT_READY && prev_text == TEXT_GAME_OVER)
        restarts++;
    prev_text = text;

    if (text == TEXT_MENU || (text == TEXT_GAME_OVER && (frame % 90u) == 0u)) {
        press = 1;                                   /* mulai / main lagi */
    } else if (text == TEXT_NONE && score < 0x3u) {  /* sedang main, sampai skor 3 */
        uint32_t cfg = a[REG_IDX(REG_PIPE_CFG)];
        int32_t gap_h = (int32_t)(cfg & 0x1FFu), w = (int32_t)((cfg >> 9) & 0x7Fu);
        int32_t best_x = 100000, target = -1;
        for (int i = 0; i < 4; i++) {
            uint32_t v = a[REG_IDX(REG_PIPE(i))];
            if (!(v & PIPE_VISIBLE))
                continue;
            saw_pipe = 1;
            int32_t x = pipe_x(v);
            if (x + w > BIRD_X && x < best_x) {
                best_x = x;
                target = (int32_t)((v >> 12) & 0x1FFu) + gap_h / 2 + 10;
            }
        }
        if (target < 0)
            target = 208;                            /* belum ada pipa: jaga di tengah */
        press = (y + 16 > target && y >= prev_y);
    }
    prev_y = y;

    /* tombol dilepas di frame berikutnya supaya main.c melihat tepi tekan */
    if (press && frame - last_press >= 2u) {
        last_press = frame;
        return BTN_FLAP;
    }
    return 0;
}

static uint32_t menu_button(uint32_t frame)
{
    return frame == 5u ? BTN_MENU : 0u;
}

int main(void)
{
    const uint32_t frames = 6000;
    platform_pc_script(screen_player);
    expect(jump_to_flap_run(frames) == 0, "loop board berjalan");

    const uint32_t *a = platform_pc_active();
    expect(platform_pc_frames() == frames, "satu vblank per iterasi");
    expect(platform_pc_commits() == frames - 1u,
           "satu commit diterapkan per frame (commit terakhir menunggu vblank)");
    expect((a[REG_IDX(REG_CTRL)] & CTRL_ENABLE) != 0, "CTRL.enable aktif");
    expect(a[REG_IDX(REG_PALETTE(14))] == 0x5AA0E6u, "palet terisi (langit)");
    expect(saw_pipe, "pipa terlihat di layar");
    expect(best_score >= 0x3u, "skor naik sampai 3 (BCD) dengan BTN0");
    expect(game_overs >= 2, "game over tercapai (lebih dari sekali)");
    expect(restarts >= 1, "main lagi setelah game over");
    expect((platform_pc_sfx() & (SFX_FLAP | SFX_SCORE | SFX_HIT)) == (SFX_FLAP | SFX_SCORE | SFX_HIT),
           "efek suara flap, skor, dan tabrak terpicu");

    platform_pc_script(menu_button);
    jump_to_flap_run(20);
    a = platform_pc_active();
    expect(a[REG_IDX(REG_TEXT_ID)] == TEXT_MENU, "BTN1 -> menu");

    printf("BOARD SIM %s (skor tertinggi 0x%04X, game over %u kali, main lagi %u kali)\n",
           failures ? "FAIL" : "PASS", (unsigned)best_score, (unsigned)game_overs,
           (unsigned)restarts);
    return failures ? 1 : 0;
}
