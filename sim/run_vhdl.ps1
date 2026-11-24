# run_vhdl.ps1 -- semua simulasi VHDL (GHDL) + perbandingan dengan referensi Python.
# Pemakaian (dari folder mana saja):
#   powershell -ExecutionPolicy Bypass -File sim/run_vhdl.ps1
#   powershell -ExecutionPolicy Bypass -File sim/run_vhdl.ps1 -Only tmds,renderer
# Butuh: GHDL (MSYS2: pacman -S mingw-w64-ucrt-x86_64-ghdl-mcode), Python 3 + pygame-ce,
# dan sw/game/game_regs (mingw32-make -C sw/game pc) untuk uji renderer.
# Primitif Xilinx diganti sim/vhdl/unisim_stub.vhd (hanya cek sambungan).
param([string[]]$Only = @())

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command ghdl -ErrorAction SilentlyContinue)) {
    if (Test-Path 'C:\msys64\ucrt64\bin\ghdl.exe') { $env:Path = "C:\msys64\ucrt64\bin;$env:Path" }
    else { throw 'ghdl tidak ditemukan. Install lewat MSYS2: pacman -S mingw-w64-ucrt-x86_64-ghdl-mcode' }
}

$work = 'sim/out/ghdl'
New-Item -ItemType Directory -Force $work | Out-Null
Remove-Item "$work/*.cf" -ErrorAction SilentlyContinue
$ghdl = @('--std=08', "--workdir=$work", "-P$work")

# Urutan analisis = urutan dependensi. File baru ditambahkan di sini.
$sources = @(
    'hw/vhdl/system/gfx_pkg.vhd',
    'hw/vhdl/system/video_timing.vhd',
    'hw/vhdl/system/test_pattern.vhd',
    'hw/vhdl/system/tmds_encoder.vhd',
    'hw/vhdl/system/clocking.vhd',
    'hw/vhdl/system/dvi_tx.vhd',
    'hw/vhdl/system/top_hdmi_test.vhd'
)
$optional = @(
    'hw/vhdl/render/assets_pkg.vhd',
    'hw/vhdl/render/layer_bg.vhd',
    'hw/vhdl/render/layer_pipe.vhd',
    'hw/vhdl/render/layer_bird.vhd',
    'hw/vhdl/render/layer_text.vhd',
    'hw/vhdl/render/renderer.vhd',
    'hw/vhdl/render/top_render_test.vhd',
    'hw/vhdl/system/gfx_axi_regs.vhd',
    'hw/vhdl/system/gfx_top.vhd'
)
$sources += $optional | Where-Object { Test-Path $_ }
$benches = Get-ChildItem sim/vhdl/tb_*.vhd | ForEach-Object { "sim/vhdl/$($_.Name)" }

Write-Host '== analisis ==' -ForegroundColor Cyan
& ghdl -a --std=08 --work=unisim "--workdir=$work" sim/vhdl/unisim_stub.vhd
if ($LASTEXITCODE) { throw 'analisis unisim_stub gagal' }
foreach ($f in $sources + $benches) {
    & ghdl -a @ghdl $f
    if ($LASTEXITCODE) { throw "analisis $f gagal" }
}
foreach ($top in 'top_hdmi_test', 'top_render_test', 'gfx_top') {
    if ($sources -match "/$top\.vhd$") {
        & ghdl -e @ghdl $top
        if ($LASTEXITCODE) { throw "elaborasi $top gagal" }
        Write-Host "[PASS] elaborasi $top (sambungan primitif Xilinx dicek dengan stub)"
    }
}

$fail = $false
function Want($name) { return ($Only.Count -eq 0) -or ($Only -contains $name) }
function Run-Bench($tb, [string[]]$generics = @()) {
    $out = & ghdl --elab-run @ghdl $tb @generics 2>&1 | ForEach-Object { "$_" }
    $out | Where-Object { $_ -match 'PASS|FAIL|ditulis|error' } |
        ForEach-Object { Write-Host ($_ -replace '^.*\(report \w+\):\s*', '') }
    # Setiap [FAIL] / report error dari testbench menggagalkan seluruh skrip.
    if ($out -match '\[FAIL\]|\(report error\)|\(assertion error\)|\(report failure\)') {
        $script:fail = $true
    }
    return $out
}

if (Want 'timing') {
    Write-Host '== tb_video_timing ==' -ForegroundColor Cyan
    $o = Run-Bench 'tb_video_timing'
    if (-not ($o -match 'TB_VIDEO_TIMING PASS')) { $fail = $true }
}

if (Want 'pattern') {
    Write-Host '== tb_test_pattern + referensi Python ==' -ForegroundColor Cyan
    Run-Bench 'tb_test_pattern' @('-gOUT_DIR=sim/out') | Out-Null
    $cases = @{ 0 = 1; 1 = 2; 2 = 5 }     # mode : jumlah update kotak saat dump
    foreach ($m in 0, 1, 2) {
        python tools/ref_test_pattern.py $m $cases[$m] "sim/out/ref_mode$m.ppm" | Out-Null
        python tools/compare_ppm.py "sim/out/vhdl_mode$m.ppm" "sim/out/ref_mode$m.ppm"
        if ($LASTEXITCODE) { $fail = $true }
    }
}

if (Want 'tmds') {
    Write-Host '== tb_tmds vs tools/ref_tmds.py ==' -ForegroundColor Cyan
    python tools/ref_tmds.py --selftest
    if ($LASTEXITCODE) { $fail = $true }
    python tools/ref_tmds.py --gen 20000 sim/out/tmds_stim.txt sim/out/tmds_exp.txt
    $o = Run-Bench 'tb_tmds' @('-gSTIM=sim/out/tmds_stim.txt', '-gEXPECT=sim/out/tmds_exp.txt')
    if (-not ($o -match 'TB_TMDS PASS')) { $fail = $true }
}

if ((Want 'renderer') -and (Test-Path sim/vhdl/tb_renderer.vhd)) {
    Write-Host '== tb_renderer vs tools/ref_render.py (skenario game) ==' -ForegroundColor Cyan
    python tools/render_scenarios.py sim/out/scenarios
    if ($LASTEXITCODE) { throw 'pembuatan skenario gagal (sudah mingw32-make -C sw/game pc?)' }
    foreach ($s in Get-ChildItem sim/out/scenarios/*.regs) {
        $name = $s.BaseName
        $o = Run-Bench 'tb_renderer' @("-gREGS_FILE=sim/out/scenarios/$name.regs", "-gOUT_FILE=sim/out/scenarios/$name.vhdl.ppm")
        python tools/compare_ppm.py "sim/out/scenarios/$name.vhdl.ppm" "sim/out/scenarios/$name.ref.ppm" --png "sim/out/scenarios/$name.vhdl.png"
        if ($LASTEXITCODE) { $fail = $true }
    }
}

if ((Want 'axi') -and (Test-Path sim/vhdl/tb_axi_regs.vhd)) {
    Write-Host '== tb_axi_regs ==' -ForegroundColor Cyan
    $o = Run-Bench 'tb_axi_regs'
    if (-not ($o -match 'TB_AXI_REGS PASS')) { $fail = $true }
}

if ($fail) { Write-Host 'SIMULASI VHDL: ADA YANG GAGAL' -ForegroundColor Red; exit 1 }
Write-Host 'SIMULASI VHDL: SEMUA PASS  (gambar: sim/out/)' -ForegroundColor Green
