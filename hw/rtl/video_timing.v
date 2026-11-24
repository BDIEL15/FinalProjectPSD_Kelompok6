// video_timing.v
// Generator timing video (VGA/DVI). Default 640x480 @ 60 Hz, pixel clock 25,175 MHz.
//
//   Horizontal: 640 aktif | 16 front porch | 96 sync | 48 back porch = 800
//   Vertikal  : 480 aktif | 10 front porch |  2 sync | 33 back porch = 525
//
// Untuk 1280x720 @ 60 Hz (74,25 MHz) ganti parameter:
//   H 1280/110/40/220, V 720/5/5/20, SYNC_POL = 1.
//
// Keluaran diturunkan dari counter terdaftar (registered), dipakai sebagai
// koordinat untuk renderer. Renderer yang menambah pipeline wajib menunda
// de/hsync/vsync dengan jumlah siklus yang sama.
`timescale 1ns / 1ps
`default_nettype none

module video_timing #(
    parameter H_ACTIVE = 640,
    parameter H_FP     = 16,
    parameter H_SYNC   = 96,
    parameter H_BP     = 48,
    parameter V_ACTIVE = 480,
    parameter V_FP     = 10,
    parameter V_SYNC   = 2,
    parameter V_BP     = 33,
    parameter SYNC_POL = 0          // 0 = sync aktif rendah (640x480), 1 = aktif tinggi
) (
    input  wire        clk,         // pixel clock
    input  wire        rst,         // reset sinkron, aktif tinggi
    output wire [11:0] x,           // kolom saat ini (valid saat de)
    output wire [11:0] y,           // baris saat ini (valid saat de)
    output wire        de,          // 1 = area aktif (piksel terlihat)
    output wire        hsync,
    output wire        vsync,
    output wire        vblank,      // 1 = baris di luar area aktif
    output wire        vblank_start // pulsa 1 siklus di awal vblank (x=0, y=V_ACTIVE)
);
    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [11:0] hcnt;
    reg [11:0] vcnt;

    always @(posedge clk) begin
        if (rst) begin
            hcnt <= 12'd0;
            vcnt <= 12'd0;
        end else if (hcnt == H_TOTAL - 1) begin
            hcnt <= 12'd0;
            vcnt <= (vcnt == V_TOTAL - 1) ? 12'd0 : vcnt + 12'd1;
        end else begin
            hcnt <= hcnt + 12'd1;
        end
    end

    wire hs_active = (hcnt >= H_ACTIVE + H_FP) && (hcnt < H_ACTIVE + H_FP + H_SYNC);
    wire vs_active = (vcnt >= V_ACTIVE + V_FP) && (vcnt < V_ACTIVE + V_FP + V_SYNC);

    assign x            = hcnt;
    assign y            = vcnt;
    assign de           = (hcnt < H_ACTIVE) && (vcnt < V_ACTIVE);
    assign hsync        = SYNC_POL ? hs_active : ~hs_active;
    assign vsync        = SYNC_POL ? vs_active : ~vs_active;
    assign vblank       = (vcnt >= V_ACTIVE);
    assign vblank_start = (hcnt == 12'd0) && (vcnt == V_ACTIVE);
endmodule

`default_nettype wire
