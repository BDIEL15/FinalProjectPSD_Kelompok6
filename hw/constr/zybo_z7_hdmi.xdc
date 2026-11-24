## zybo_z7_hdmi.xdc -- constraint Zybo Z7-10 / Z7-20 untuk semua top:
##   top_hdmi_test, top_render_test, dan system_wrapper (block design)
## Nama port di ketiganya sama: sysclk, sw, btn, led, hdmi_tx_*.
##
## Pin sudah dicocokkan dengan Digilent Zybo-Z7-Master.xdc (24 Nov 2026):
## 22 port (sysclk, sw, btn, led, HDMI TX) cocok persis, termasuk IOSTANDARD.
## Sumber: https://github.com/Digilent/digilent-xdc  ->  Zybo-Z7-Master.xdc
## Pin audio dan lainnya belum dipakai. Tambahkan dari file master bila perlu.
## Port HDMI yang dipakai adalah konektor "HDMI TX" (J8, sisi sumber/source).

## Clock 125 MHz
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { sysclk }]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sysclk }]

## Switch
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]

## Tombol
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]
set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]

## LED
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## HDMI TX
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_hpd }]
set_property -dict { PACKAGE_PIN H16 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_p }]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_n }]
set_property -dict { PACKAGE_PIN D19 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[0] }]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[0] }]
set_property -dict { PACKAGE_PIN C20 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[1] }]
set_property -dict { PACKAGE_PIN B20 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[1] }]
set_property -dict { PACKAGE_PIN B19 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_p[2] }]
set_property -dict { PACKAGE_PIN A20 IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_n[2] }]

## Switch dan tombol asinkron terhadap clock piksel
set_false_path -from [get_ports { sw[*] btn[*] hdmi_tx_hpd }]
