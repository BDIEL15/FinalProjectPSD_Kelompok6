/* platform_baremetal.c -- lib platform untuk ARM Zynq tanpa Linux (Vitis standalone).
 *
 * Register grafis diakses langsung lewat Xil_Out32/Xil_In32 di GFX_BASE.
 * Tombol dibaca dari STATUS[7:4] (disinkronkan di PL, tanpa IP GPIO).
 * UART = USB-UART bawaan Zybo (konsol 115200 8N1), juga untuk Cadangan A.
 */
#include "platform.h"

#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xtime_l.h"
#include "xuartps_hw.h"

#include "../game/regs.h"

int gfx_open(void)
{
    xil_printf("\r\nJump-to-Flap: register grafis di 0x%08x\r\n", (unsigned)GFX_BASE);
    uint32_t st = Xil_In32(GFX_BASE + REG_STATUS);
    uint32_t f0 = STATUS_FRAME(st);
    /* frame_count harus berjalan (~60 Hz). Bila tidak, bitstream salah/belum dimuat. */
    for (volatile uint32_t i = 0; i < 20000000u; i++) {
        if (STATUS_FRAME(Xil_In32(GFX_BASE + REG_STATUS)) != f0) {
            xil_printf("frame_count berjalan, STATUS = 0x%08x\r\n", (unsigned)st);
            return 0;
        }
    }
    xil_printf("GAGAL: frame_count tidak berubah. Bitstream system_wrapper sudah dimuat?\r\n");
    return -1;
}

void gfx_write(uint32_t offset, uint32_t v)
{
    Xil_Out32(GFX_BASE + offset, v);
}

uint32_t gfx_read(uint32_t offset)
{
    return Xil_In32(GFX_BASE + offset);
}

void gfx_commit(void)
{
    Xil_Out32(GFX_BASE + REG_CTRL, CTRL_ENABLE | CTRL_COMMIT);
}

void gfx_wait_vblank(void)
{
    uint32_t f0 = STATUS_FRAME(Xil_In32(GFX_BASE + REG_STATUS));
    while (STATUS_FRAME(Xil_In32(GFX_BASE + REG_STATUS)) == f0) {
    }
}

uint32_t btn_read(void)
{
    return STATUS_BTN(Xil_In32(GFX_BASE + REG_STATUS));
}

int uart_read_flap(void)
{
    if (!XUartPs_IsReceiveData(STDIN_BASEADDRESS))
        return -1;
    return (int)XUartPs_RecvByte(STDIN_BASEADDRESS);
}

uint32_t time_ms(void)
{
    XTime t;
    XTime_GetTime(&t);
    return (uint32_t)(t / (COUNTS_PER_SECOND / 1000u));
}
