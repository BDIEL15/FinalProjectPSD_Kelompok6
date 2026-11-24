# build_hdmi_test.tcl -- bitstream uji HDMI (milestone A), tanpa PS, tanpa IP.
# Mode non-project: tidak ada file proyek Vivado yang perlu di-commit.
#
#   vivado -mode batch -source hw/scripts/build_hdmi_test.tcl
#   (jalankan dari folder root repo; dari Vivado Tcl Shell juga bisa)
#
# Hasil: hw/out/hdmi_test/top_hdmi_test.bit + laporan utilisasi & timing.
source [file join [file dirname [info script]] common.tcl]

set top top_hdmi_test
set out [file join $repo hw out hdmi_test]
file mkdir $out

read_vhdl -vhdl2008 [system_sources $top]
read_xdc [file join $repo hw constr zybo_z7_hdmi.xdc]

synth_design -top $top -part $part
opt_design
place_design
route_design
finish_build $out $top
