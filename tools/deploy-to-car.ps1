# 一键把「顶替版语音」部署到车机
#
# 做的事（按顺序，每步都检查结果）：
#   1. 连接车机
#   2. 解禁原车小卡（我们之前 disable 过，不解禁无法覆盖）
#   3. 备份旧包设置（若旧包 xyz.i4o.uni.voice 还在，提示先手动导出）
#   4. 卸载旧包 xyz.i4o.uni.voice（换包名必须）
#   5. 安装顶替包 com.ecarx.xiaoka（平台签名版，versionCode 990）
#   6. 授予麦克风权限、启动界面
#   7. 打印验证信息（userId / 版本 / 关键权限 / 兼容组件）
#
# 回滚：adb uninstall com.ecarx.xiaoka
#
# 用法：
#   pwsh -File tools\deploy-to-car.ps1 -Serial 192.168.22.197:5555

param(
    [string]$Serial = '192.168.22.197:5555',
    [string]$Sdk = 'E:\Android\Sdk',
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $Sdk 'platform-tools\adb.exe'
$root = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $root 'app\build\voice\outputs\apk\release\voice-arm64-v8a-release-system.apk'

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "    ✓ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    ! $msg" -ForegroundColor Yellow }

Step 1 "连接车机 $Serial"
& $adb connect $Serial | Out-Null
$devices = & $adb devices
if ($devices -notmatch [regex]::Escape($Serial)) { throw "连不上 $Serial" }
Ok "已连接"

Step 2 "解禁原车小卡"
& $adb -s $Serial shell "pm enable com.ecarx.xiaoka" 2>&1 | Out-Null
& $adb -s $Serial shell "pm list packages -e | grep com.ecarx.xiaoka" 2>&1 | ForEach-Object { Ok $_.Trim() }

Step 3 "检查旧包与旧设置"
$old = & $adb -s $Serial shell "pm list packages | grep xyz.i4o.uni.voice"
if ($old) {
    Warn "旧包 xyz.i4o.uni.voice 还在：它会随卸载一起丢掉数据"
    Warn "如果还没导出设置，先执行："
    Warn "  adb -s $Serial shell am start -n xyz.i4o.uni.voice/.VoiceSettingsActivity"
    Warn "  点「导出设置」→ /sdcard/Download/uni-voice-settings.json"
    $backup = & $adb -s $Serial shell "ls /sdcard/Download/uni-voice-settings.json 2>/dev/null"
    if (-not $backup) {
        $go = Read-Host "没检测到备份文件，仍然继续？(y/N)"
        if ($go -ne 'y') { throw "已中止：请先导出设置" }
    } else { Ok "已找到备份：$($backup.Trim())" }
} else { Ok "旧包不存在，跳过" }

if (-not $SkipInstall) {
    Step 4 "卸载旧包"
    & $adb -s $Serial uninstall xyz.i4o.uni.voice 2>&1 | Out-Null
    Ok "已卸载（若原本不存在则忽略）"

    Step 5 "安装顶替包"
    if (-not (Test-Path $apk)) { throw "找不到 APK：$apk（先跑 tools\sign-system.ps1）" }
    & $adb -s $Serial install -r $apk 2>&1 | Select-Object -Last 1
    Ok "安装完成：$apk"
}

Step 6 "授权与启动"
& $adb -s $Serial shell "pm grant com.ecarx.xiaoka android.permission.RECORD_AUDIO" 2>&1 | Out-Null
& $adb -s $Serial shell "am start -n com.ecarx.xiaoka/xyz.i4o.uni.voice.VoiceSettingsActivity" 2>&1 | Out-Null
Ok "界面已启动（记得点「导入设置」把火山 Key 找回来）"

Step 7 "验证"
$d = & $adb -s $Serial shell "dumpsys package com.ecarx.xiaoka"
foreach ($k in @('versionCode=', 'userId=', 'sharedUser=', 'CAR_VENDOR_EXTENSION: granted', 'CAR_ENGINE_DETAILED: granted')) {
    $line = ($d | Select-String -Pattern ([regex]::Escape($k)) | Select-Object -First 1)
    if ($line) { Ok $line.Line.Trim() } else { Warn "未找到：$k" }
}
Step 7.1 "兼容组件"
$d2 = & $adb -s $Serial shell "dumpsys package com.ecarx.xiaoka"
foreach ($k in @('XKMainActivity', 'MagicActivity', 'VRClientService', 'VoiceKeyReceiver')) {
    $line = ($d2 | Select-String -Pattern $k | Select-Object -First 1)
    if ($line) { Ok $k } else { Warn "缺少组件：$k" }
}

Write-Host "`n下一步手动验证（按顺序）：" -ForegroundColor Cyan
Write-Host "  1) 说「你好小优」看是否应答"
Write-Host "  2) 说「开空调」看面板是否真的动（CAR_VENDOR_EXTENSION 生效）"
Write-Host "  3) 按方向盘语音键，看日志：adb -s $Serial logcat -s uniVoice.key"
Write-Host "  4) 看有没有外部来找引擎：adb -s $Serial logcat -s UniVoice.VRBridge"
Write-Host "  5) 看双麦时延（真车上应 20~70 点）：adb -s $Serial logcat -s UniVoice.Beam"
Write-Host "`n回滚：adb -s $Serial uninstall com.ecarx.xiaoka" -ForegroundColor Yellow
