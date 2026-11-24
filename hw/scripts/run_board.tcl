# run_board.tcl -- muat bitstream + jalankan game di Zybo lewat JTAG (tanpa GUI).
#
#   xsdb hw/scripts/run_board.tcl          (dari folder root repo, board tersambung,
#                                           jumper boot = JTAG, daya menyala)
#
# Butuh hasil hw/scripts/build_system.tcl dan hw/scripts/vitis_app.py.
# Konsol game (115200 8N1) muncul di port COM USB-UART Zybo.
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set bit  [file join $repo hw out system system_wrapper.bit]
set ws   [file join $repo sw vitis_ws]
set elf  [file join $ws jump_to_flap build jump_to_flap.elf]

# ps7_init.tcl dibuat Vitis saat membuat platform; lokasinya berbeda antar versi.
proc find_file {dir name} {
    foreach f [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $f]} {
            set r [find_file $f $name]
            if {$r ne ""} { return $r }
        } elseif {[file tail $f] eq $name} {
            return $f
        }
    }
    return ""
}
set ps7_init [find_file $ws ps7_init.tcl]
foreach f [list $bit $elf $ps7_init] {
    if {$f eq "" || ![file exists $f]} {
        error "File belum ada ($f). Jalankan build_system.tcl lalu vitis_app.py dulu."
    }
}

connect
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000
fpga -file $bit
source $ps7_init
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow $elf
con
puts "Game berjalan. Tekan BTN0 untuk flap, BTN1 untuk kembali ke menu."
