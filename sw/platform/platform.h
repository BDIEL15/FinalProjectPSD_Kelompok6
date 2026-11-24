/* Lib platform (kontrak A -> C, docs/tugas/README.md §3.4).
 *
 * Satu header, beberapa implementasi:
 *   platform_baremetal.c  ARM tanpa Linux (Vitis standalone)  <- dipakai M4
 *   platform_pc.c         PC: register di memori, tombol berskenario (uji)
 *   platform_linux.c      nanti: /dev/mem atau UIO (setelah Linux jalan)
 * Kode game (sw/game/main.c) hanya memanggil fungsi di sini, jadi sama untuk
 * semua implementasi.
 */
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>

/* Alamat dasar register grafis = offset di block design
 * (hw/scripts/build_system.tcl). */
#ifndef GFX_BASE
#define GFX_BASE 0x43C00000u
#endif

/* Tombol board (bit di btn_read). */
#define BTN_FLAP  (1u << 0)    /* BTN0 */
#define BTN_MENU  (1u << 1)    /* BTN1 */

int      gfx_open(void);                       /* 0 = OK */
void     gfx_write(uint32_t offset, uint32_t v);
uint32_t gfx_read(uint32_t offset);
void     gfx_commit(void);                     /* CTRL = enable | commit */
void     gfx_wait_vblank(void);                /* blok sampai awal vblank berikutnya */
uint32_t btn_read(void);                       /* 4 tombol, bit per tombol */
int      uart_read_flap(void);                 /* -1 tidak ada, atau 'F' / 'L' / 'K' */
uint32_t time_ms(void);

#endif
