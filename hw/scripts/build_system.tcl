# build_system.tcl -- sistem lengkap (milestone M4): ARM (PS7) + akselerator grafis.
#
#   vivado -mode batch -source hw/scripts/build_system.tcl
#
# Block design dibuat seluruhnya dari skrip ini (tidak ada klik manual):
#
#   [ZYNQ7 PS] --M_AXI_GP0--> [AXI Interconnect] --> [gfx_top (VHDL, module reference)]
#        |  FCLK_RESET0_N                                   |  pix_clk_o (25 MHz)
#        +--> [proc_sys_reset] <-- dcm_locked = locked_o     +--> semua clock AXI
#
# Semua logika ada di VHDL (hw/vhdl). Block design hanya kabel.
# Hasil di hw/out/system/: system_wrapper.bit, system.xsa (untuk Vitis),
# utilization.txt, timing.txt, dan system_bd.pdf/.tcl (diagram untuk laporan).
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
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_gfx
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_ic
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_ic]

# clock: satu clock piksel untuk AXI dan video
connect_bd_net [get_bd_pins gfx/pix_clk_o] \
    [get_bd_pins gfx/s_axi_aclk] \
    [get_bd_pins ps7/M_AXI_GP0_ACLK] \
    [get_bd_pins axi_ic/ACLK] [get_bd_pins axi_ic/S00_ACLK] [get_bd_pins axi_ic/M00_ACLK] \
    [get_bd_pins rst_gfx/slowest_sync_clk]

# reset
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_gfx/ext_reset_in]
connect_bd_net [get_bd_pins gfx/locked_o] [get_bd_pins rst_gfx/dcm_locked]
connect_bd_net [get_bd_pins rst_gfx/interconnect_aresetn] [get_bd_pins axi_ic/ARESETN]
connect_bd_net [get_bd_pins rst_gfx/peripheral_aresetn] \
    [get_bd_pins axi_ic/S00_ARESETN] [get_bd_pins axi_ic/M00_ARESETN] [get_bd_pins gfx/s_axi_aresetn]

# bus
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_ic/M00_AXI] [get_bd_intf_pins gfx/s_axi]

# pin board: nama port = nama di hw/constr/zybo_z7_hdmi.xdc
create_bd_port -dir I -type clk -freq_hz 125000000 sysclk
connect_bd_net [get_bd_ports sysclk] [get_bd_pins gfx/sysclk]
foreach {name dir width} {
    btn I 4  sw I 4  led O 4
    hdmi_tx_hpd I 1  hdmi_tx_clk_p O 1  hdmi_tx_clk_n O 1  hdmi_tx_p O 3  hdmi_tx_n O 3
} {
    if {$width == 1} {
        create_bd_port -dir $dir $name
    } else {
        create_bd_port -dir $dir -from [expr {$width - 1}] -to 0 $name
    }
    connect_bd_net [get_bd_ports $name] [get_bd_pins gfx/$name]
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
