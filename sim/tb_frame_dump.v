// tb_frame_dump.v -- simulasikan video_timing + test_pattern, lalu simpan
// satu frame penuh tiap mode ke file .ppm (P3) agar bisa dilihat sebagai gambar
// dan dibandingkan dengan referensi Python (tools/ref_test_pattern.py).
//
// Urutan: reset -> vblank #1 -> dump mode 0 -> vblank #2 -> dump mode 1
//         -> tunggu sampai vblank #5 -> dump mode 2 (kotak sudah bergerak 5 kali)
// Output: sim/out/frame_mode0.ppm, frame_mode1.ppm, frame_mode2.ppm
`timescale 1ns / 1ps

module tb_frame_dump;
    localparam W = 640, H = 480;

    reg clk = 0, rst = 1;
    reg [1:0] mode = 0;
    always #20 clk = ~clk;

    wire [11:0] x, y;
    wire de, hs, vs, vblank, vblank_start;
    wire [7:0] r, g, b;
    wire de_o, hs_o, vs_o;

    video_timing u_t (
        .clk(clk), .rst(rst), .x(x), .y(y), .de(de), .hsync(hs), .vsync(vs),
        .vblank(vblank), .vblank_start(vblank_start)
    );

    test_pattern u_p (
        .clk(clk), .rst(rst), .mode(mode),
        .x(x), .y(y), .de(de), .hsync(hs), .vsync(vs), .vblank_start(vblank_start),
        .r(r), .g(g), .b(b), .de_o(de_o), .hsync_o(hs_o), .vsync_o(vs_o)
    );

    integer vbs = 0;
    always @(posedge clk) if (!rst && vblank_start) vbs = vbs + 1;

    // Tangkap W*H piksel de_o berikutnya ke file
    task dump_frame(input [8*64-1:0] fname);
        integer fd, n;
        begin
            fd = $fopen(fname, "w");
            if (fd == 0) begin
                $display("[FAIL] tidak bisa membuka %0s (folder sim/out sudah ada?)", fname);
                $finish;
            end
            $fwrite(fd, "P3\n%0d %0d\n255\n", W, H);
            n = 0;
            while (n < W * H) begin
                @(posedge clk);
                #1;                       // baca keluaran register setelah tepi clock
                if (de_o) begin
                    $fwrite(fd, "%0d %0d %0d\n", r, g, b);
                    n = n + 1;
                end
            end
            $fclose(fd);
            $display("ditulis %0s (%0d piksel, setelah vblank ke-%0d)", fname, n, vbs);
        end
    endtask

    task wait_vblank_count(input integer k);
        begin
            while (vbs < k) @(posedge clk);
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst = 0;

        mode = 0; wait_vblank_count(1); dump_frame("sim/out/frame_mode0.ppm");
        mode = 1; wait_vblank_count(2); dump_frame("sim/out/frame_mode1.ppm");
        mode = 2; wait_vblank_count(5); dump_frame("sim/out/frame_mode2.ppm");

        $display("TB_FRAME_DUMP DONE");
        $finish;
    end
endmodule
