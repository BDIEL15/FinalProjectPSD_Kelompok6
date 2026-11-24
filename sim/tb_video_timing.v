// tb_video_timing.v -- uji timing 640x480@60 dari video_timing.v
// Memeriksa: panjang baris, jumlah baris per frame, lebar & posisi pulsa sync,
// jumlah piksel aktif, dan pulsa vblank_start (tepat satu per frame).
`timescale 1ns / 1ps

module tb_video_timing;
    localparam H_TOTAL = 800, V_TOTAL = 525;
    localparam FRAME_CYC = H_TOTAL * V_TOTAL;   // 420000

    reg clk = 0, rst = 1;
    always #20 clk = ~clk;                       // 25 MHz (periode tidak penting)

    wire [11:0] x, y;
    wire de, hs, vs, vblank, vblank_start;

    video_timing dut (
        .clk(clk), .rst(rst), .x(x), .y(y), .de(de), .hsync(hs), .vsync(vs),
        .vblank(vblank), .vblank_start(vblank_start)
    );

    integer errors = 0;
    integer cyc = 0;
    integer de_count = 0, de_line = 0, max_de_line = 0, min_de_line = 99999;
    integer hs_low = 0, last_hs_fall = -1, vs_low_cyc = 0, last_vs_fall = -1;
    integer vbs_count = 0, last_vbs = -1;
    integer hs_fall_x = -1, vs_fall_x = -1, vs_fall_y = -1;
    integer hs_width = -1, vs_width = -1, line_len = -1, frame_len = -1;
    reg hs_d = 1, vs_d = 1, de_d = 0;

    task check(input cond, input [8*64-1:0] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("[FAIL] %0s", msg);
            end else
                $display("[PASS] %0s", msg);
        end
    endtask

    // Ukur selama 3 frame setelah reset; statistik diambil di frame ke-2.
    always @(posedge clk) if (!rst) begin
        cyc = cyc + 1;

        // hsync (aktif rendah)
        if (hs_d && !hs) begin
            if (last_hs_fall >= 0) line_len = cyc - last_hs_fall;
            last_hs_fall = cyc;
            hs_fall_x = x;
            hs_low = 0;
        end
        if (!hs) hs_low = hs_low + 1;
        if (!hs_d && hs) hs_width = hs_low;

        // vsync (aktif rendah)
        if (vs_d && !vs) begin
            if (last_vs_fall >= 0) frame_len = cyc - last_vs_fall;
            last_vs_fall = cyc;
            vs_fall_x = x; vs_fall_y = y;
            vs_low_cyc = 0;
        end
        if (!vs) vs_low_cyc = vs_low_cyc + 1;
        if (!vs_d && vs) vs_width = vs_low_cyc;

        // piksel aktif per baris & per frame (frame ke-2 saja)
        if (cyc > FRAME_CYC && cyc <= 2 * FRAME_CYC) begin
            if (de) begin
                de_count = de_count + 1;
                de_line = de_line + 1;
            end
            if (de_d && !de) begin
                if (de_line > max_de_line) max_de_line = de_line;
                if (de_line < min_de_line) min_de_line = de_line;
                de_line = 0;
            end
            if (de && (x >= 640 || y >= 480)) begin
                errors = errors + 1;
                $display("[FAIL] de aktif di luar area: x=%0d y=%0d", x, y);
            end
            if (vblank != (y >= 480)) begin
                errors = errors + 1;
                $display("[FAIL] vblank salah di y=%0d", y);
            end
        end

        // vblank_start
        if (vblank_start) begin
            vbs_count = vbs_count + 1;
            if (x != 0 || y != 480) begin
                errors = errors + 1;
                $display("[FAIL] vblank_start di x=%0d y=%0d", x, y);
            end
            if (last_vbs >= 0 && cyc - last_vbs != FRAME_CYC) begin
                errors = errors + 1;
                $display("[FAIL] jarak vblank_start %0d", cyc - last_vbs);
            end
            last_vbs = cyc;
        end

        hs_d = hs; vs_d = vs; de_d = de;
    end

    initial begin
        repeat (4) @(posedge clk);
        rst = 0;
        repeat (3 * FRAME_CYC + 10) @(posedge clk);

        $display("line_len=%0d hs_width=%0d hs_fall_x=%0d", line_len, hs_width, hs_fall_x);
        $display("frame_len=%0d vs_width=%0d vs_fall=(%0d,%0d)", frame_len, vs_width, vs_fall_x, vs_fall_y);
        $display("de_count=%0d de/line=%0d..%0d vblank_start=%0d", de_count, min_de_line, max_de_line, vbs_count);

        check(line_len == 800,            "1 baris = 800 clock");
        check(hs_width == 96,             "lebar hsync = 96 clock");
        check(hs_fall_x == 656,           "hsync mulai di x = 640+16");
        check(frame_len == FRAME_CYC,     "1 frame = 525 baris = 420000 clock");
        check(vs_width == 2 * H_TOTAL,    "lebar vsync = 2 baris");
        check(vs_fall_x == 0 && vs_fall_y == 490, "vsync mulai di y = 480+10");
        check(de_count == 640 * 480,      "piksel aktif per frame = 307200");
        check(min_de_line == 640 && max_de_line == 640, "piksel aktif per baris = 640");
        check(vbs_count == 3,             "vblank_start 1x per frame");

        if (errors == 0) $display("TB_VIDEO_TIMING PASS");
        else             $display("TB_VIDEO_TIMING FAIL (%0d error)", errors);
        $finish;
    end
endmodule
