// top_hdmi_test.v
// Top-level uji HDMI untuk Zybo Z7 (minggu 1, anggota C). Tanpa PS.
//
//   sysclk 125 MHz -> clk_wiz_0 (25,175 MHz, hasil wizard biasanya 25,2 MHz)
//                  -> video_timing -> test_pattern -> rgb2dvi_0 -> HDMI TX
//
//   sw[1:0]  pilih pola (0 bar warna, 1 grid, 2 kotak memantul)
//   btn[0]   reset
//   led[0]   MMCM terkunci
//   led[1]   HPD: monitor terdeteksi
//   led[2]   berkedip ~1 Hz (bukti frame berjalan)
//
// IP yang harus dibuat di Vivado (lihat hw/README-VIVADO.md):
//   clk_wiz_0  : input 125 MHz, clk_out1 25,175 MHz, reset aktif tinggi, locked
//   rgb2dvi_0  : dari Digilent vivado-library. Generate SerialClk = ya,
//                MMCM, kClkRange = 5 (>=25 MHz), reset aktif tinggi.
//
// PERHATIAN urutan warna rgb2dvi Digilent: vid_pData = {R, B, G}.
// Jika di monitor hijau dan biru tertukar, ubah urutan di bawah.
`timescale 1ns / 1ps
`default_nettype none

module top_hdmi_test (
    input  wire       sysclk,
    input  wire [3:0] sw,
    input  wire [3:0] btn,
    output wire [3:0] led,
    input  wire       hdmi_tx_hpd,
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n
);
    // ---------------- clock ----------------
    wire pix_clk;
    wire locked;

    clk_wiz_0 u_clk (
        .clk_in1  (sysclk),
        .reset    (btn[0]),
        .clk_out1 (pix_clk),
        .locked   (locked)
    );

    // reset sinkron di domain piksel: aktif selama MMCM belum terkunci
    reg [3:0] rst_sr = 4'hF;
    always @(posedge pix_clk or negedge locked) begin
        if (!locked) rst_sr <= 4'hF;
        else         rst_sr <= {rst_sr[2:0], 1'b0};
    end
    wire rst = rst_sr[3];

    // sinkronisasi switch ke domain piksel
    reg [1:0] mode_s1, mode_s2;
    always @(posedge pix_clk) begin
        mode_s1 <= sw[1:0];
        mode_s2 <= mode_s1;
    end

    // ---------------- video ----------------
    wire [11:0] x, y;
    wire de, hs, vs, vblank, vblank_start;

    video_timing u_timing (
        .clk(pix_clk), .rst(rst),
        .x(x), .y(y), .de(de), .hsync(hs), .vsync(vs),
        .vblank(vblank), .vblank_start(vblank_start)
    );

    wire [7:0] r, g, b;
    wire de_o, hs_o, vs_o;

    test_pattern u_pattern (
        .clk(pix_clk), .rst(rst), .mode(mode_s2),
        .x(x), .y(y), .de(de), .hsync(hs), .vsync(vs), .vblank_start(vblank_start),
        .r(r), .g(g), .b(b), .de_o(de_o), .hsync_o(hs_o), .vsync_o(vs_o)
    );

    rgb2dvi_0 u_dvi (
        .TMDS_Clk_p  (hdmi_tx_clk_p),
        .TMDS_Clk_n  (hdmi_tx_clk_n),
        .TMDS_Data_p (hdmi_tx_p),
        .TMDS_Data_n (hdmi_tx_n),
        .aRst        (rst),
        .vid_pData   ({r, b, g}),
        .vid_pVDE    (de_o),
        .vid_pHSync  (hs_o),
        .vid_pVSync  (vs_o),
        .PixelClk    (pix_clk)
    );

    // ---------------- LED ----------------
    reg [5:0] frame_cnt;
    always @(posedge pix_clk) begin
        if (rst) frame_cnt <= 6'd0;
        else if (vblank_start) frame_cnt <= frame_cnt + 6'd1;
    end

    assign led[0] = locked;
    assign led[1] = hdmi_tx_hpd;
    assign led[2] = frame_cnt[5];      // 60 frame/s / 64 -> ~0,94 Hz
    assign led[3] = 1'b0;
endmodule

`default_nettype wire
