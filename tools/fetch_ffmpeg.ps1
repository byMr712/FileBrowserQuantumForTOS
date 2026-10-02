<#
.SYNOPSIS
    Скачивает и распаковывает статические сборки ffmpeg/ffprobe (linux x86_64)
    для сборки .tpk с поддержкой ffmpeg (FileBrowserQuantum_...-beta-ffmpeg-...).

.DESCRIPTION
    Использует официальные статические сборки John Van Sickle
    (https://johnvansickle.com/ffmpeg/) - glibc x86_64, работают на TOS6/TOS7.
    Кладёт только два бинарника ffmpeg и ffprobe в tools\ffmpeg\
    (эта папка в .gitignore).

    Bинарники распространяются под GPLv3 (см. NOTICE).
#>
[CmdletBinding()]
param(
    [string]$Url = 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz',
    [string]$OutDir = (Join-Path $PSScriptRoot 'ffmpeg')
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$archive = Join-Path $OutDir 'ffmpeg-release-amd64-static.tar.xz'
$extract = Join-Path $OutDir '_extract'

Write-Host "Downloading ffmpeg static build..."
Invoke-WebRequest -Uri $Url -OutFile $archive

Write-Host "Extracting..."
if (Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
New-Item -ItemType Directory -Force -Path $extract | Out-Null

# tar.xz -> tar (Linux/macOS style). Под Windows используем tar из Git for Windows
# или встроенный C:\Windows\System32\tar.exe (bsdtar умеет xz через libarchive).
& tar.exe -xf $archive -C $extract 2>$null
if ($LASTEXITCODE -ne 0) {
    # Fallback: сначала распаковать xz вручную (xz.exe из tools\xz), затем tar
    $tarFile = Join-Path $extract 'ffmpeg.tar'
    & (Join-Path $PSScriptRoot 'xz\xz.exe') -d -k -c $archive | Set-Content -Path $tarFile -AsByteStream
    & tar.exe -xf $tarFile -C $extract
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed" }
}

$srcBin = Get-ChildItem -Path $extract -Recurse -Filter ffmpeg | Select-Object -First 1
if (-not $srcBin) { throw "ffmpeg binary not found in archive" }
$srcDir = $srcBin.DirectoryName

foreach ($name in @('ffmpeg', 'ffprobe')) {
    $src = Join-Path $srcDir $name
    if (-not (Test-Path $src)) { throw "missing $name in static build" }
    Copy-Item -Force $src (Join-Path $OutDir $name)
    Write-Host "  $name -> $(Join-Path $OutDir $name) ($((Get-Item $src).Length) bytes)"
}

Remove-Item -LiteralPath $extract -Recurse -Force
Remove-Item -LiteralPath $archive -Force
Write-Host "Done. ffmpeg/ffprobe ready in $OutDir"