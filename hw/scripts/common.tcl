# common.tcl -- pengaturan bersama skrip build Vivado.
# Board: Zybo Z7-10. Untuk Z7-20 ganti part ke xc7z020clg400-1.
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set part xc7z010clg400-1

# Sumber VHDL untuk satu top-level, urut dependensi.
proc system_sources {top} {
    global repo
    set sys [file join $repo hw vhdl system]
    set ren [file join $repo hw vhdl render]
    set files [list \
        [file join $sys gfx_pkg.vhd] \
        [file join $sys video_timing.vhd] \
        [file join $sys tmds_encoder.vhd] \
        [file join $sys clocking.vhd] \
        [file join $sys dvi_tx.vhd]]
    switch $top {
        top_hdmi_test {
            lappend files [file join $sys test_pattern.vhd] [file join $sys top_hdmi_test.vhd]
        }
        top_render_test {
            lappend files {*}[render_sources] [file join $ren top_render_test.vhd]
        }
        gfx_top {
            lappend files [file join $sys test_pattern.vhd] {*}[render_sources] \
                [file join $sys gfx_axi_regs.vhd] [file join $sys gfx_top.vhd]
        }
        default { error "top tidak dikenal: $top" }
    }
    return $files
}

proc render_sources {} {
    global repo
    set ren [file join $repo hw vhdl render]
    return [list \
        [file join $ren assets_pkg.vhd] \
        [file join $ren layer_bg.vhd] \
        [file join $ren layer_pipe.vhd] \
        [file join $ren layer_bird.vhd] \
        [file join $ren layer_text.vhd] \
        [file join $ren renderer.vhd]]
}

# Laporan + bitstream. Gagal keras bila timing tidak terpenuhi.
proc finish_build {out top} {
    report_utilization -file [file join $out utilization.txt]
    report_timing_summary -file [file join $out timing.txt]
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
    puts "WNS = $wns ns"
    write_bitstream -force [file join $out $top.bit]
    if {$wns < 0} {
        error "TIMING GAGAL: WNS = $wns ns (lihat [file join $out timing.txt])"
    }
    puts "BUILD OK: [file join $out $top.bit]"
}
