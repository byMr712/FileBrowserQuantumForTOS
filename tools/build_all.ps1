<#
.SYNOPSIS
    Одной командой собирает ОБА TPK-варианта: обычный и с ffmpeg.

.DESCRIPTION
    Оркестрирует tools\build_tpk.ps1 и собирает оба пакета одной версии:
      1) обычный пакет  ...-<BaseReleaseTag>-<platform>.tpk
      2) пакет с ffmpeg  ...-<FFmpegReleaseTag>-<platform>.tpk
    Если в tools\ffmpeg\ нет статических ffmpeg/ffprobe - они автоматически
    скачиваются один раз через tools\fetch_ffmpeg.ps1 (John Van Sickle static
    builds, linux x86_64, GPLv3). Никаких ручных шагов кроме установки Go и xz.

    Версия в именах файлов и в заголовке .tpk берётся из config.ini дерева пакета.
    Каждая сборка идёт в отдельном staging-пространстве: чистое дерево
    FileBrowserQuantumTOS\ не изменяется ни в одном из вариантов.

.PARAMETER PkgDir
    Каталог с деревом пакета (относительно tools\). По умолчанию ..\FileBrowserQuantumTOS.

.PARAMETER OutDir
    Куда положить готовые .tpk (относительно tools\). По умолчанию .. (корень репозитория).

.PARAMETER XzPath
    Путь к xz.exe (пробрасывается в build_tpk.ps1). По умолчанию авто-поиск.

.PARAMETER BaseReleaseTag
    Суффикс версии обычного TPK. По умолчанию beta.

.PARAMETER FFmpegReleaseTag
    Суффикс версии ffmpeg TPK. По умолчанию beta-ffmpeg.

.PARAMETER FFmpegDir
    Каталог со своими ffmpeg/ffprobe (по умолчанию tools\ffmpeg). Если задан - автозагрузка
    не выполняется.

.PARAMETER SkipFfmpegFetch
    Не скачивать ffmpeg автоматически; требовать уже готовые бинарники в tools\ffmpeg\.

.PARAMETER KeepGoing
    Продолжать сборку вторым вариантом, даже если первый упал.

.EXAMPLE
    pwsh -NoProfile -Command "& .\tools\build_all.ps1"
    # → FileBrowserQuantum_TOS7_TOS6_2.1.0.0-beta-x86_64.tpk
    # → FileBrowserQuantum_TOS7_TOS6_2.1.0.0-beta-ffmpeg-x86_64.tpk

.EXAMPLE
    # со своими бинарниками ffmpeg (никакой загрузки)
    pwsh -NoProfile -Command "& .\tools\build_all.ps1 -FFmpegDir D:\ffmpeg-static"
#>
[CmdletBinding()]
param(
    [string]$PkgDir = '..\FileBrowserQuantumTOS',
    [string]$OutDir = '..',
    [string]$XzPath = '',
    [string]$BaseReleaseTag = 'beta',
    [string]$FFmpegReleaseTag = 'beta-ffmpeg',
    [string]$FFmpegDir = '',
    [switch]$SkipFfmpegFetch,
    [switch]$KeepGoing
)

$ErrorActionPreference = 'Stop'
$WorkRoot = $PSScriptRoot
Set-Location -LiteralPath $WorkRoot

$buildScript = Join-Path $WorkRoot 'build_tpk.ps1'
$fetchScript = Join-Path $WorkRoot 'fetch_ffmpeg.ps1'

if (-not (Test-Path -LiteralPath $PkgDir)) {
    throw "Package directory not found (relative to $WorkRoot): $PkgDir"
}
$cfg = Get-Content (Join-Path $PkgDir 'config.ini') -Raw | ConvertFrom-Json
if (-not $cfg.version -or -not $cfg.id -or -not $cfg.platform) {
    throw "config.ini must contain id/version/platform (got id=$($cfg.id), version=$($cfg.version), platform=$($cfg.platform))"
}

# ---- 1. Гарантируем наличие статических ffmpeg/ffprobe --------------------------
$ffTopDir = if ($FFmpegDir) { $FFmpegDir } else { 'ffmpeg' }
$ffDir = [System.IO.Path]::GetFullPath((Join-Path $WorkRoot $ffTopDir))
$ffBin = Join-Path $ffDir 'ffmpeg'
$fpBin = Join-Path $ffDir 'ffprobe'

if (-not (Test-Path -LiteralPath $ffBin) -or -not (Test-Path -LiteralPath $fpBin)) {
    if ($SkipFfmpegFetch -or $FFmpegDir) {
        throw "ffmpeg/ffprobe not found in $ffDir. Run 'pwsh .\tools\fetch_ffmpeg.ps1' first (or pass -FFmpegDir <dir>)."
    }
    Write-Host "==> ffmpeg/ffprobe not found in tools\ffmpeg\ - downloading static builds (one time, ~160 MB) ..."
    & $fetchScript
    if (-not (Test-Path -LiteralPath $ffBin) -or -not (Test-Path -LiteralPath $fpBin)) {
        throw "fetch_ffmpeg.ps1 finished but 'ffmpeg'/'ffprobe' are still missing in $ffDir. Check network access and retry."
    }
}
Write-Host "Using ffmpeg binaries from: $ffDir"

# ---- 2. Сборка обоих вариантов ---------------------------------------------------
function Invoke-Variant {
    param(
        [string]$Name,
        [string]$ReleaseTag,
        [switch]$WithFfmpeg
    )
    $params = @{
        PkgDir      = $PkgDir
        OutDir      = $OutDir
        ReleaseTag  = $ReleaseTag
    }
    if ($XzPath) { $params['XzPath'] = $XzPath }
    if ($WithFfmpeg) { $params['FFmpegDir'] = $ffDir }

    Write-Host ""
    Write-Host "===== Building $Name ====="
    try {
        & $buildScript @params
        return $true
    } catch {
        if ($KeepGoing) {
            Write-Warning "$Name build failed: $_"
            return $false
        }
        throw
    }
}

$baseOk = Invoke-Variant -Name 'base (no ffmpeg)' -ReleaseTag $BaseReleaseTag
$ffOk   = Invoke-Variant -Name 'ffmpeg variant'  -ReleaseTag $FFmpegReleaseTag -WithFfmpeg

# ---- 3. Итоговая сводка ------------------------------------------------------------
$outRoot = [System.IO.Path]::GetFullPath((Join-Path $WorkRoot $OutDir))
$tpkBase = Join-Path $outRoot ("{0}_TOS7_TOS6_{1}-{2}-{3}.tpk" -f $cfg.id, $cfg.version, $BaseReleaseTag, $cfg.platform)
$tpkFf   = Join-Path $outRoot ("{0}_TOS7_TOS6_{1}-{2}-{3}.tpk" -f $cfg.id, $cfg.version, $FFmpegReleaseTag, $cfg.platform)

Write-Host ""
Write-Host "===== Build summary (version from config.ini: $($cfg.version)) ====="
foreach ($pair in @(@('base', $tpkBase, $baseOk), @('ffmpeg', $tpkFf, $ffOk))) {
    $label = $pair[0]
    $path  = $pair[1]
    $ok    = [bool]$pair[2]
    if ($ok -and (Test-Path -LiteralPath $path)) {
        $size = (Get-Item -LiteralPath $path).Length
        Write-Host "  [OK]    $label : $path  ($size bytes)"
    } else {
        Write-Host "  [FAIL]  $label : $path"
    }
}

if (-not ($baseOk -and $ffOk)) {
    exit 1
}