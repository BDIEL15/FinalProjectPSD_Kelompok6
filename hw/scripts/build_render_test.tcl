# build_render_test.tcl -- bitstream renderer game tanpa ARM (milestone B).
#   vivado -mode batch -source hw/scripts/build_render_test.tcl
# Hasil: hw/out/render_test/top_render_test.bit + laporan utilisasi & timing.
source [file join [file dirname [info script]] common.tcl]

set top top_render_test
set out [file join $repo hw out render_test]
file mkdir $out

read_vhdl -vhdl2008 [system_sources $top]
read_xdc [file join $repo hw constr zybo_z7_hdmi.xdc]

synth_design -top $top -part $part
opt_design
place_design
route_design
finish_build $out $top
