# 用「车机平台密钥」签名 APK，使其获得平台签名 + system UID。
#
# 背景：本车机（领克 05 / IP753）的系统应用全部用 AOSP 公开的 platform 密钥签名，
# 证书 SHA-256 = C8A2E9BCCF597C2FB6DC66BEE293FC13F2FC47EC77BC6B2B0D52C11F51192AB8。
# 因此我们也能用同一把（公开的）密钥签名，从而：
#   - 通过 android:sharedUserId="android.uid.system" 以 system(1000) 身份运行
#   - 获得 signature|privileged 级权限（CAR_ENGINE_DETAILED / CAR_VENDOR_EXTENSION 等）
#
# 用法：
#   .\tools\sign-system.ps1 -Apk app\build\ancprobe\outputs\apk\release\ancprobe-release.apk
#   .\tools\sign-system.ps1 -Apk <某个.apk> -Install 192.168.22.197:5555

param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Out,
    [string]$Install,
    [string]$Sdk = 'E:\Android\Sdk'
)

$ErrorActionPreference = 'Stop'
$expect = 'c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8'

$buildTools = Get-ChildItem (Join-Path $Sdk 'build-tools') -Directory |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $buildTools) { throw '找不到 build-tools' }
$zipalign  = Join-Path $buildTools.FullName 'zipalign.exe'
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'

$keyDir = Join-Path $PSScriptRoot 'aosp-platform-key'
New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
$pem = Join-Path $keyDir 'platform.x509.pem'
$pk8 = Join-Path $keyDir 'platform.pk8'
$base = 'https://raw.githubusercontent.com/aosp-mirror/platform_build/master/target/product/security'
if (-not (Test-Path $pem)) { Invoke-WebRequest "$base/platform.x509.pem" -OutFile $pem -TimeoutSec 60 }
if (-not (Test-Path $pk8)) { Invoke-WebRequest "$base/platform.pk8" -OutFile $pk8 -TimeoutSec 60 }

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pem)
$bytes = $cert.GetCertHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)
$hex = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
if ($hex -ne $expect) {
    throw "平台密钥指纹不匹配（得到 $hex，期望 $expect）——签了也装不上"
}
Write-Host "[1/4] 平台密钥校验通过: $hex" -ForegroundColor Green

if (-not $Out) {
    $dir  = Split-Path -Parent (Resolve-Path $Apk)
    $name = [IO.Path]::GetFileNameWithoutExtension($Apk)
    $Out  = Join-Path $dir "$name-system.apk"
}
$tmp = "$Out.aligned"
& $zipalign -f -p 4 $Apk $tmp | Out-Null
& $apksigner sign --key $pk8 --cert $pem --out $Out $tmp
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
Write-Host "[2/4] 已签名: $Out" -ForegroundColor Green

$verify = & $apksigner verify --print-certs $Out 2>&1 | Out-String
if ($verify -notmatch [regex]::Escape($expect)) { throw "签名验证失败`n$verify" }
Write-Host "[3/4] 签名验证通过（证书 = 车机平台证书）" -ForegroundColor Green

if ($Install) {
    $adb = Join-Path $Sdk 'platform-tools\adb.exe'
    & $adb -s $Install install -r $Out | Select-Object -Last 1
    Write-Host "[4/4] 已安装到 $Install" -ForegroundColor Green
} else {
    Write-Host "[4/4] 未指定 -Install，跳过安装"
}
