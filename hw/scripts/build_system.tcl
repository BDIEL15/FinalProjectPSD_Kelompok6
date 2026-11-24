# build_system.tcl -- sistem lengkap (milestone M4): ARM (PS7) + akselerator grafis.
#
#   vivado -mode batch -source hw/scripts/build_system.tcl
#
# Block design dibuat seluruhnya dari skrip ini (tidak ada klik manual):
#
#   sysclk 125 MHz --> [Clocking Wizard] --clk_out1 25 MHz--> semua clock AXI + gfx_top
#                            |  clk_out2 125 MHz (5x) --> gfx_top (serializer HDMI)
#                            |  locked --> proc_sys_reset + gfx_top
#   [ZYNQ7 PS] --M_AXI_GP0--> [AXI Interconnect] --> [gfx_top (VHDL, module reference)]
#        |  FCLK_RESET0_N
#        +--> [proc_sys_reset] --> reset AXI
#
# Clock dibangkitkan di Clocking Wizard, bukan di dalam gfx_top, agar Vivado tahu
# frekuensinya dan meneruskannya ke PS7/interconnect. (Diuji: dengan MMCM di
# dalam gfx_top, validate_bd_design gagal "FREQ_HZ does not match".)
#
# Semua logika ada di VHDL (hw/vhdl). Block design hanya kabel.
# Hasil di hw/out/system/: system_wrapper.bit, system.xsa (untuk Vitis),
# utilization.txt, timing.txt, dan system_bd.tcl. Diagram PDF hanya bisa dibuat dari
# GUI (write_bd_layout gagal di mode batch).
#
# Syarat: board file Digilent terpasang (preset PS7 Zybo Z7: DDR, MIO, UART, ...).
# Skrip ini ditulis sebelum Vivado 2026.1 tersedia di laptop pengembang:
# jalankan sekali, dan bila ada nama perintah/properti yang berubah di versi
# ini, perbaiki di sini (bukan lewat GUI) agar tetap bisa dibuat ulang.
source [file join [file dirname [info script]] common.tcl]

set out  [file join $repo hw out system]
set proj [file join $out proj]
file mkdir $out

create_project -force system $proj -part $part

# --- board part Zybo Z7 (wajib untuk preset PS7) -------------------------------
set bp [lindex [lsort [get_board_parts -quiet *zybo-z7-10*]] end]
if {$part eq "xc7z020clg400-1"} {
    set bp [lindex [lsort [get_board_parts -quiet *zybo-z7-20*]] end]
}
if {$bp eq ""} {
    error "Board file Zybo Z7 tidak ditemukan. Pasang Digilent vivado-boards (lihat hw/README-VIVADO.md)."
}
set_property board_part $bp [current_project]
puts "board part: $bp"

# --- sumber VHDL ------------------------------------------------------------------
set srcs [system_sources gfx_top]
add_files -norecurse $srcs
foreach f $srcs {
    # gfx_top = top module reference: ditulis VHDL-93; sisanya VHDL-2008
    if {[file tail $f] eq "gfx_top.vhd"} {
        set_property file_type VHDL [get_files $f]
    } else {
        set_property file_type {VHDL 2008} [get_files $f]
    }
}
add_files -fileset constrs_1 -norecurse [file join $repo hw constr zybo_z7_hdmi.xdc]
update_compile_order -fileset sources_1

# --- block design -----------------------------------------------------------------
create_bd_design system

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1}] [get_bd_cells ps7]

create_bd_cell -type module -reference gfx_top gfx
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_gen
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {125.000} \
    CONFIG.CLKOUT1_USED {true} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} \
    CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.USE_RESET {false} CONFIG.USE_LOCKED {true}] [get_bd_cells clk_gen]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_gfx
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_ic
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_ic]

# clock: satu clock piksel 25 MHz untuk AXI dan video; 125 MHz hanya untuk serializer
connect_bd_net [get_bd_pins clk_gen/clk_out1] \
    [get_bd_pins gfx/s_axi_aclk] \
    [get_bd_pins ps7/M_AXI_GP0_ACLK] \
    [get_bd_pins axi_ic/ACLK] [get_bd_pins axi_ic/S00_ACLK] [get_bd_pins axi_ic/M00_ACLK] \
    [get_bd_pins rst_gfx/slowest_sync_clk]

# reset
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_gfx/ext_reset_in]
connect_bd_net [get_bd_pins clk_gen/clk_out2] [get_bd_pins gfx/ser_clk]
connect_bd_net [get_bd_pins clk_gen/locked] [get_bd_pins rst_gfx/dcm_locked] [get_bd_pins gfx/pll_locked]
connect_bd_net [get_bd_pins rst_gfx/interconnect_aresetn] [get_bd_pins axi_ic/ARESETN]
connect_bd_net [get_bd_pins rst_gfx/peripheral_aresetn] \
    [get_bd_pins axi_ic/S00_ARESETN] [get_bd_pins axi_ic/M00_ARESETN] [get_bd_pins gfx/s_axi_aresetn]

# bus
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M00_AXI] [get_bd_intf_pins gfx/s_axi]

# pin board: nama port = nama di hw/constr/zybo_z7_hdmi.xdc
create_bd_port -dir I -type clk -freq_hz 125000000 sysclk
connect_bd_net [get_bd_ports sysclk] [get_bd_pins clk_gen/clk_in1]
# {port board, pin gfx_top, arah, lebar}; pin TMDS gfx_top tanpa "clk" di nama
# supaya tidak disangka antarmuka clock oleh Vivado.
foreach {name pin dir width} {
    btn btn I 4  sw sw I 4  led led O 4
    hdmi_tx_hpd hdmi_tx_hpd I 1
    hdmi_tx_clk_p tmds_ck_p O 1  hdmi_tx_clk_n tmds_ck_n O 1
    hdmi_tx_p tmds_d_p O 3  hdmi_tx_n tmds_d_n O 3
} {
    if {$width == 1} {
        create_bd_port -dir $dir $name
    } else {
        create_bd_port -dir $dir -from [expr {$width - 1}] -to 0 $name
    }
    connect_bd_net [get_bd_ports $name] [get_bd_pins gfx/$pin]
}

# alamat: register grafis di 0x43C0_0000 (sama dengan GFX_BASE di sw/platform)
assign_bd_address
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces ps7/Data]] {
    set_property offset 0x43C00000 $seg
    set_property range 4K $seg
}

validate_bd_design
save_bd_design
write_bd_tcl -force [file join $out system_bd.tcl]
catch {write_bd_layout -force -format pdf -orientation landscape [file join $out system_bd.pdf]}

# sintesis module reference bersama top (tanpa checkpoint OOC terpisah)
set bd_file [get_files system.bd]
set_property synth_checkpoint_mode None $bd_file
generate_target all $bd_file
set wrapper [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# --- build ------------------------------------------------------------------------
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementasi gagal: lihat log di $proj/system.runs/impl_1"
}
open_run impl_1
report_utilization -file [file join $out utilization.txt]
report_timing_summary -file [file join $out timing.txt]
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS = $wns ns"
file copy -force [file join $proj system.runs impl_1 system_wrapper.bit] [file join $out system_wrapper.bit]
write_hw_platform -fixed -include_bit -force -file [file join $out system.xsa]
if {$wns < 0} {
    error "TIMING GAGAL: WNS = $wns ns (lihat [file join $out timing.txt])"
}
puts "BUILD OK: [file join $out system.xsa]"
