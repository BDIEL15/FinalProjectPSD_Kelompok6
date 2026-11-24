// test_pattern.v
// Pola uji untuk membuktikan jalur HDMI sebelum renderer game jadi.
//   mode 0: 8 bar warna (putih, kuning, cyan, hijau, magenta, merah, biru, hitam)
//   mode 1: grid 32 px putih di atas biru tua + bingkai merah 1 px di tepi layar
//   mode 2: kotak kuning 32x32 memantul di atas gradien abu-abu
//           (posisi diperbarui SAAT VBLANK -> pola yang sama dipakai renderer
//            game agar gambar tidak sobek / tearing-free)
//
// Latensi pipeline: 1 siklus. de/hsync/vsync ikut ditunda 1 siklus.
// Rumus di sini harus sama persis dengan tools/ref_test_pattern.py.
`timescale 1ns / 1ps
`default_nettype none

module test_pattern #(
    parameter H_ACTIVE = 640,
    parameter V_ACTIVE = 480,
    parameter BOX      = 32,
    parameter BOX_X0   = 100,
    parameter BOX_Y0   = 50,
    parameter BOX_DX   = 3,
    parameter BOX_DY   = 2
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  mode,
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire        de,
    input  wire        hsync,
    input  wire        vsync,
    input  wire        vblank_start,
    output reg  [7:0]  r,
    output reg  [7:0]  g,
    output reg  [7:0]  b,
    output reg         de_o,
    output reg         hsync_o,
    output reg         vsync_o
);
    localparam BOX_XMAX = H_ACTIVE - BOX;
    localparam BOX_YMAX = V_ACTIVE - BOX;

    // ---------------- posisi kotak (mode 2), update sekali per frame -------
    reg [11:0] box_x, box_y;
    reg        dir_x, dir_y;        // 0 = kanan/bawah, 1 = kiri/atas

    always @(posedge clk) begin
        if (rst) begin
            box_x <= BOX_X0;
            box_y <= BOX_Y0;
            dir_x <= 1'b0;
            dir_y <= 1'b0;
        end else if (vblank_start) begin
            if (!dir_x) begin
                if (box_x + BOX_DX >= BOX_XMAX) begin box_x <= BOX_XMAX; dir_x <= 1'b1; end
                else box_x <= box_x + BOX_DX;
            end else begin
                if (box_x <= BOX_DX) begin box_x <= 12'd0; dir_x <= 1'b0; end
                else box_x <= box_x - BOX_DX;
            end
            if (!dir_y) begin
                if (box_y + BOX_DY >= BOX_YMAX) begin box_y <= BOX_YMAX; dir_y <= 1'b1; end
                else box_y <= box_y + BOX_DY;
            end else begin
                if (box_y <= BOX_DY) begin box_y <= 12'd0; dir_y <= 1'b0; end
                else box_y <= box_y - BOX_DY;
            end
        end
    end

    // ---------------- warna per piksel (kombinasional) ---------------------
    reg [23:0] bar_rgb;
    always @(*) begin
        if      (x <  80) bar_rgb = 24'hFFFFFF;   // putih
        else if (x < 160) bar_rgb = 24'hFFFF00;   // kuning
        else if (x < 240) bar_rgb = 24'h00FFFF;   // cyan
        else if (x < 320) bar_rgb = 24'h00FF00;   // hijau
        else if (x < 400) bar_rgb = 24'hFF00FF;   // magenta
        else if (x < 480) bar_rgb = 24'hFF0000;   // merah
        else if (x < 560) bar_rgb = 24'h0000FF;   // biru
        else              bar_rgb = 24'h000000;   // hitam
    end

    wire border = (x == 0) || (x == H_ACTIVE - 1) || (y == 0) || (y == V_ACTIVE - 1);
    wire grid   = (x[4:0] == 5'd0) || (y[4:0] == 5'd0);
    wire [23:0] grid_rgb = border ? 24'hFF0000 :
                           grid   ? 24'hFFFFFF : 24'h101850;

    wire in_box = (x >= box_x) && (x < box_x + BOX) && (y >= box_y) && (y < box_y + BOX);
    wire [7:0] grey = x[9:2];                       // 0..159 -> gradien horizontal
    wire [23:0] box_rgb = in_box ? 24'hFFD020 : {grey, grey, grey};

    reg [23:0] rgb;
    always @(*) begin
        case (mode)
            2'd0:    rgb = bar_rgb;
            2'd1:    rgb = grid_rgb;
            2'd2:    rgb = box_rgb;
            default: rgb = 24'h000000;
        endcase
    end

    // ---------------- register keluaran (pipeline 1 siklus) ----------------
    always @(posedge clk) begin
        if (rst) begin
            {r, g, b} <= 24'd0;
            de_o      <= 1'b0;
            hsync_o   <= 1'b1;
            vsync_o   <= 1'b1;
        end else begin
            {r, g, b} <= de ? rgb : 24'd0;
            de_o      <= de;
            hsync_o   <= hsync;
            vsync_o   <= vsync;
        end
    end
endmodule

`default_nettype wire
