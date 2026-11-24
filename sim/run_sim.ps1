# run_sim.ps1 -- jalankan semua simulasi HDL + perbandingan dengan referensi Python.
# Pemakaian (dari folder mana saja):
#   powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1
# Butuh: Icarus Verilog (winget install -e --id Icarus.Verilog) dan Python 3.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    foreach ($p in 'C:\iverilog\bin', 'C:\Program Files\iverilog\bin') {
        if (Test-Path "$p\iverilog.exe") { $env:Path = "$p;$env:Path"; break }
    }
}
if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    throw 'iverilog tidak ditemukan. Install: winget install -e --id Icarus.Verilog'
}

New-Item -ItemType Directory -Force sim/out | Out-Null
$fail = $false
$rtl = 'hw/rtl/video_timing.v', 'hw/rtl/test_pattern.v'

Write-Host '== tb_video_timing ==' -ForegroundColor Cyan
iverilog -g2005 -Wall -o sim/out/tb_video_timing.vvp sim/tb_video_timing.v @rtl
if ($LASTEXITCODE) { throw 'kompilasi tb_video_timing gagal' }
$out = vvp -n sim/out/tb_video_timing.vvp
$out | ForEach-Object { Write-Host $_ }
if (-not ($out -match 'TB_VIDEO_TIMING PASS')) { $fail = $true }

Write-Host '== tb_frame_dump ==' -ForegroundColor Cyan
iverilog -g2005 -Wall -o sim/out/tb_frame_dump.vvp sim/tb_frame_dump.v @rtl
if ($LASTEXITCODE) { throw 'kompilasi tb_frame_dump gagal' }
vvp -n sim/out/tb_frame_dump.vvp
if ($LASTEXITCODE) { $fail = $true }

Write-Host '== bandingkan dengan referensi Python ==' -ForegroundColor Cyan
# mode : jumlah update kotak saat frame di-dump (lihat tb_frame_dump.v)
$cases = @{ 0 = 1; 1 = 2; 2 = 5 }
foreach ($m in 0, 1, 2) {
    python tools/ref_test_pattern.py $m $cases[$m] "sim/out/ref_mode$m.ppm" | Out-Null
    python tools/compare_ppm.py "sim/out/frame_mode$m.ppm" "sim/out/ref_mode$m.ppm" --png "sim/out/frame_mode$m.png"
    if ($LASTEXITCODE) { $fail = $true }
}

if ($fail) { Write-Host 'SIMULASI: ADA YANG GAGAL' -ForegroundColor Red; exit 1 }
Write-Host 'SIMULASI: SEMUA PASS  (gambar: sim/out/frame_mode*.png)' -ForegroundColor Green
