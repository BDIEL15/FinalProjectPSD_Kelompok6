/* platform_pc.c -- lib platform tiruan untuk PC (uji main.c tanpa board).
 *
 * Meniru perilaku gfx_axi_regs.vhd: register shadow di memori, commit baru
 * disalin ke "aktif" saat vblank berikutnya, frame_count naik tiap vblank.
 * Tombol diputar dari skenario (platform_pc_script). Fungsi platform_pc_*
 * dipakai oleh sw/game/board_sim.c untuk memeriksa hasilnya.
 */
#include "platform.h"

#include <string.h>

#include "../game/regs.h"

static uint32_t shadow[REG_COUNT];
static uint32_t active[REG_COUNT];
static int commit_pending;
static uint32_t frame_count;
static uint32_t commits_applied;
static uint32_t sfx_seen;
static uint32_t (*script)(uint32_t frame);

void platform_pc_script(uint32_t (*fn)(uint32_t frame)) { script = fn; }
const uint32_t *platform_pc_active(void) { return active; }
uint32_t platform_pc_frames(void) { return frame_count; }
uint32_t platform_pc_commits(void) { return commits_applied; }
uint32_t platform_pc_sfx(void) { return sfx_seen; }

int gfx_open(void)
{
    memset(shadow, 0, sizeof shadow);
    memset(active, 0, sizeof active);
    commit_pending = 0;
    frame_count = commits_applied = sfx_seen = 0;
    return 0;
}

void gfx_write(uint32_t offset, uint32_t v)
{
    uint32_t i = REG_IDX(offset);
    if (i >= REG_COUNT || offset == REG_STATUS)
        return;
    if (offset == REG_SFX_TRIGGER) {
        sfx_seen |= v & 7u;
        return;
    }
    if (offset == REG_CTRL) {
        if (v & CTRL_COMMIT)
            commit_pending = 1;
        v &= ~CTRL_COMMIT;
    }
    shadow[i] = v;
}

uint32_t gfx_read(uint32_t offset)
{
    if (offset == REG_STATUS)
        return (frame_count << 16) | ((uint32_t)commit_pending << 1)
             | ((script ? script(frame_count) : 0u) << 4);
    return shadow[REG_IDX(offset) % REG_COUNT];
}

void gfx_commit(void)
{
    gfx_write(REG_CTRL, CTRL_ENABLE | CTRL_COMMIT);
}

void gfx_wait_vblank(void)
{
    frame_count = (frame_count + 1u) & 0xFFFFu;
    if (commit_pending) {
        memcpy(active, shadow, sizeof active);
        commit_pending = 0;
        commits_applied++;
    }
}

uint32_t btn_read(void)
{
    return STATUS_BTN(gfx_read(REG_STATUS));
}

int uart_read_flap(void)
{
    return -1;
}

uint32_t time_ms(void)
{
    return frame_count * 1000u / 60u;
}
