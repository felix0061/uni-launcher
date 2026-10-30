# Impeller 后端 A/B 开关（C1）
#
# 车机上 Impeller 后端只能靠 AndroidManifest 的 meta-data 指定，属于构建期
# 配置，不能在运行时切换。这个脚本只改 AndroidManifest.xml 里被
# `<!-- impeller-ab:start -->` / `<!-- impeller-ab:end -->` 括住的那一段，
# 默认构建内容为空（走引擎默认，通常是 Vulkan）。
#
# 用法：
#   pwsh tools/impeller_ab.ps1 -Backend opengles
#   pwsh tools/impeller_ab.ps1 -Backend opengles -Lazy -NoAntialias
#   pwsh tools/impeller_ab.ps1 -Backend vulkan
#   pwsh tools/impeller_ab.ps1 -Restore          # 清空实验位
#
# 每组都要单独构建 + 上车用 tools/car_perf_probe.ps1 采一轮，比较
# interaction.p50 / coldStart.medianTotalMs 两个字段。
param(
    [ValidateSet('vulkan', 'opengles')]
    [string]$Backend = 'opengles',
    [switch]$Lazy,
    [switch]$NoAntialias,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$manifest = Join-Path $PSScriptRoot '..\app\android\app\src\main\AndroidManifest.xml'
$manifest = [System.IO.Path]::GetFullPath($manifest)
if (-not (Test-Path $manifest)) { throw "找不到 AndroidManifest.xml: $manifest" }

$text = Get-Content $manifest -Raw
$pattern = '(?s)<!--\s*impeller-ab:start\s*-->(.*?)<!--\s*impeller-ab:end\s*-->'
if ($text -notmatch $pattern) { throw '清单里缺少 impeller-ab 标记，先恢复原始清单再运行' }

$lines = @()
if (-not $Restore) {
    $lines += '    <meta-data android:name="ImpellerBackend" android:value="' + $Backend + '"/>'
    if ($Lazy) { $lines += '    <meta-data android:name="ImpellerLazyShaderInitialization" android:value="true"/>' }
    if ($NoAntialias) { $lines += '    <meta-data android:name="ImpellerAntialiasLines" android:value="false"/>' }
}
$body = "`n" + (($lines -join "`n")) + $(if ($lines.Count) { "`n" } else { '' })
$replacement = "<!-- impeller-ab:start -->" + $body + "    <!-- impeller-ab:end -->"
$updated = [regex]::Replace($text, $pattern, $replacement.Replace('$', '$$'))
Set-Content -Path $manifest -Value $updated -Encoding utf8NoBOM

if ($Restore) {
    Write-Host '已清空 Impeller 实验位（回到引擎默认后端）。'
} else {
    $label = $Backend + $(if ($Lazy) { '+lazy' } else { '' }) + $(if ($NoAntialias) { '+noAA' } else { '' })
    Write-Host "已写入 Impeller 实验位: $label"
    Write-Host '接着构建：'
    Write-Host '  cd app; flutter build apk --release --target-platform android-arm64 --split-per-abi'
    Write-Host "采数：pwsh ../tools/car_perf_probe.ps1 -Label impeller-$label"
}
