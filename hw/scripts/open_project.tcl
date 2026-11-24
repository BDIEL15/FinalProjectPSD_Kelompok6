# open_project.tcl -- buat (atau buka) proyek Vivado untuk dilihat/diedit di GUI.
# TIDAK menjalankan sintesis atau implementasi: itu tetap lewat skrip build_*.tcl,
# atau klik Run Synthesis / Run Implementation / Generate Bitstream di GUI.
#
#   vivado -mode gui -source hw/scripts/open_project.tcl -tclargs hdmi_test
#   vivado -mode gui -source hw/scripts/open_project.tcl -tclargs render_test
#
# Argumen (default hdmi_test):
#   hdmi_test    top_hdmi_test    (tahap A: pola uji HDMI)
#   render_test  top_render_test  (tahap B: renderer game tanpa ARM)
#
# Proyek ada di hw/out/gui_<nama>/ (diabaikan git). File VHDL TIDAK disalin:
# proyek menunjuk langsung ke hw/vhdl/, jadi edit di GUI = edit di repo.
# Untuk M4 (block design + ARM) pakai hw/scripts/build_system.tcl, lalu buka
# hw/out/system/proj/system.xpr.
source [file join [file dirname [info script]] common.tcl]

set name hdmi_test
if {[info exists ::argv] && [llength $::argv] > 0} { set name [lindex $::argv 0] }
switch $name {
    hdmi_test   { set top top_hdmi_test }
    render_test { set top top_render_test }
    default     { error "argumen tidak dikenal: $name (pilih hdmi_test atau render_test)" }
}

set dir [file join $repo hw out gui_$name]
set xpr [file join $dir gui_$name.xpr]

if {[file exists $xpr]} {
    open_project $xpr
    puts "Proyek dibuka: $xpr"
} else {
    file mkdir $dir
    create_project gui_$name $dir -part $part
    set_property target_language VHDL [current_project]

    set srcs [system_sources $top]
    add_files -norecurse $srcs
    foreach f $srcs {
        set_property file_type {VHDL 2008} [get_files $f]
    }
    add_files -fileset constrs_1 -norecurse [file join $repo hw constr zybo_z7_hdmi.xdc]
    set_property top $top [current_fileset]
    update_compile_order -fileset sources_1
    puts "Proyek dibuat: $xpr (top = $top)"
}
