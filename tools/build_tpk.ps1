<#
.SYNOPSIS
    Сборка TPK-пакета FileBrowser Quantum из дерева пакета.

.DESCRIPTION
    Скрипт выполняет полный цикл упаковки TPK для TerraMaster TOS6/TOS7:
      1) пересчитывает контрольные суммы INFO (md5 всех файлов дерева);
      2) собирает payload.tar (GNU tar, root:root, права как в оригинале) утилитой tarmake;
      3) сжимает его xz (preset -9e) в payload.tar.xz;
      4) собирает итоговый .tpk: JSON-заголовок + .lang + payload.tar.xz.

    Все пути по умолчанию — ОТНОСИТЕЛЬНЫЕ и считаются от папки скрипта (tools\).
    Рабочие файлы (payload.tar / payload.tar.xz) создаются во временной подпапке
    tools\_build\ и удаляются после успешной сборки. В %TEMP% ничего не пишется.

    Структура .tpk (проверено на оригинале 1.2.1.0):
      [0..2048)   JSON-заголовок (в поле "md5" — md5 от payload.tar.xz), дополнен нулями
      [2048..10240) содержимое FileBrowserQuantum.lang, дополнено нулями до 8192
      [10240..end) payload.tar.xz (magic FD 37 7A 58 5A 00)

.PARAMETER PkgDir
    Каталог с деревом пакета (относительно папки скрипта).
    По умолчанию ..\FileBrowserQuantum_2.0.1.0_pkg

.PARAMETER OutDir
    Куда положить готовый .tpk (относительно папки скрипта). По умолчанию ..\ (filebrowser_new_build).

.PARAMETER XzPath
    Путь к xz.exe. По умолчанию сначала ищется вложенный tools\xz\xz.exe,
    затем в Git for Windows (mingw64\bin).

.PARAMETER ReleaseTag
    Суффикс версии в имени файла (по умолчанию beta). Пустая строка — без суффикса.

.EXAMPLE
    pwsh .\tools\build_tpk.ps1

.EXAMPLE
    # стабильный релиз, без суффикса
    pwsh .\tools\build_tpk.ps1 -ReleaseTag ''
#>
[CmdletBinding()]
param(
    [string]$PkgDir = '..\FileBrowserQuantum_2.0.1.0_pkg',
    [string]$OutDir = '..',
    [string]$XzPath = '',
    [string]$ReleaseTag = 'beta'
)

$ErrorActionPreference = 'Stop'

# ---- Работаем в собственной папке: всё дальше — относительными путями ----------
$WorkRoot = $PSScriptRoot
Set-Location -LiteralPath $WorkRoot
[Environment]::CurrentDirectory = $WorkRoot

$BuildDir = '.\_build'
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

function Get-MD5([string]$path) {
    $h = [System.Security.Cryptography.MD5]::Create()
    return [Convert]::ToHexString($h.ComputeHash([System.IO.File]::ReadAllBytes($path))).ToLower()
}

if (-not (Test-Path -LiteralPath $PkgDir)) { throw "Package dir not found (relative to $WorkRoot): $PkgDir" }

# ---- 0. Normalize text files to LF (CRLF breaks the #!/bin/bash shebang on TOS) --
$lfFiles = @(
    'FileBrowserQuantum.lang',
    'INFO',
    'bin/filebrowser.yml',
    'bin/filebrowser.migrate.yml',
    'config.ini',
    'functions/dependapps.sh',
    'init.d/service',
    'version'
)
foreach ($rel in $lfFiles) {
    $p = Join-Path $PkgDir ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $b = [System.IO.File]::ReadAllBytes($p)
    if ($b.Contains([byte]13)) {
        $t = [System.Text.Encoding]::UTF8.GetString($b) -replace "`r`n", "`n" -replace "`r", "`n"
        [System.IO.File]::WriteAllText($p, $t, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Normalized LF: $rel"
    }
}

# ---- 1. Regenerate INFO (same layout as the original package) -------------------
$infoLines = @(
    "1:file:FileBrowserQuantum.lang:$(Get-MD5 (Join-Path $PkgDir 'FileBrowserQuantum.lang'))",
    '1:folder:bin:',
    "1:file:bin/filebrowser.yml:$(Get-MD5 (Join-Path $PkgDir 'bin\filebrowser.yml'))",
    "1:file:bin/filebrowser.migrate.yml:$(Get-MD5 (Join-Path $PkgDir 'bin\filebrowser.migrate.yml'))",
    '1:folder:bin/program:',
    "1:file:bin/program/filebrowserquantum:$(Get-MD5 (Join-Path $PkgDir 'bin\program\filebrowserquantum'))",
    '1:folder:functions:',
    "1:file:functions/dependapps.sh:$(Get-MD5 (Join-Path $PkgDir 'functions\dependapps.sh'))",
    '1:folder:images:',
    '1:folder:images/icons:',
    "1:file:images/icons/FileBrowserQuantum.png:$(Get-MD5 (Join-Path $PkgDir 'images\icons\FileBrowserQuantum.png'))",
    '1:folder:init.d:',
    "1:file:init.d/service:$(Get-MD5 (Join-Path $PkgDir 'init.d\service'))",
    "1:file:version:$(Get-MD5 (Join-Path $PkgDir 'version'))",
    "1:file:webui.bz2:$(Get-MD5 (Join-Path $PkgDir 'webui.bz2'))"
)
$infoText = ($infoLines -join "`n") + "`n"
[System.IO.File]::WriteAllText((Join-Path $PkgDir 'INFO'), $infoText, [System.Text.UTF8Encoding]::new($false))
Write-Host "INFO regenerated: $((Get-Item (Join-Path $PkgDir 'INFO')).Length) bytes"

# ---- 2. Locate tools -------------------------------------------------------------
$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) { $go = Get-Command 'C:\Program Files\Go\bin\go.exe' -ErrorAction SilentlyContinue }
if (-not $go) { throw 'Go not found. Install Go 1.26+ (https://go.dev/dl/)' }

if (-not $XzPath) {
    $candidates = @(
        '.\xz\xz.exe',
        "$env:ProgramFiles\Git\mingw64\bin\xz.exe",
        "${env:ProgramFiles(x86)}\Git\mingw64\bin\xz.exe",
        "$env:LOCALAPPDATA\Programs\Git\mingw64\bin\xz.exe"
    )
    $XzPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $XzPath) { throw 'xz.exe not found. Put xz.exe into tools\xz\ or pass -XzPath' }
Write-Host "Using xz: $XzPath"

# ---- 3. Build payload.tar (GNU tar via Go tool, relative to this folder) ----------
$tarPath = Join-Path $BuildDir 'payload.tar'
$xzOut   = Join-Path $BuildDir 'payload.tar.xz'

Write-Host "Building payload.tar with tarmake ..."
& $go.Source run ./tarmake $PkgDir $tarPath
if ($LASTEXITCODE -ne 0) { throw "tarmake failed (exit $LASTEXITCODE)" }

# ---- 4. Compress payload.tar -> payload.tar.xz (binary-safe) ---------------------
Write-Host "Compressing with xz -9e ..."
$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $XzPath
$psi.Arguments = "-k -9e -c `"$tarPath`""
$psi.RedirectStandardOutput = $true
$psi.UseShellExecute = $false
$psi.WorkingDirectory = $WorkRoot
$p = [System.Diagnostics.Process]::Start($psi)
$fs = [System.IO.File]::Create($xzOut)
$p.StandardOutput.BaseStream.CopyTo($fs)
$fs.Close()
$p.WaitForExit()
if ($p.ExitCode -ne 0) { throw "xz failed (exit $($p.ExitCode))" }
Remove-Item -LiteralPath $tarPath
Write-Host "payload.tar.xz: $((Get-Item $xzOut).Length) bytes"

# ---- 5. Assemble the .tpk ---------------------------------------------------------
$cfg = Get-Content (Join-Path $PkgDir 'config.ini') -Raw | ConvertFrom-Json
$version = $cfg.version
$id = $cfg.id
$platform = $cfg.platform
$md5 = Get-MD5 $xzOut
$langBytes = [System.IO.File]::ReadAllBytes((Join-Path $PkgDir 'FileBrowserQuantum.lang'))
$payloadBytes = [System.IO.File]::ReadAllBytes($xzOut)

if ($langBytes.Length -gt 8192) { throw "FileBrowserQuantum.lang too large: $($langBytes.Length) > 8192" }

$header = '{"id":"FileBrowserQuantum","md5":"' + $md5 + '","icon":"/images/icons/FileBrowserQuantum.png","path":"/FileBrowserQuantum/","name":"FileBrowser Quantum","publisher":"OutkastM","exec":true,"open_path":false,"resize":true,"maxmin":true,"state":false,"type":"iframe","help":"/FileBrowserQuantum/","version":"' + $version + '","recommend":false,"beta":false,"category":"Utilities","depend":[],"relation":null,"platform":"x86_64","low_version":"6.0.420","reset":false,"official":"/FileBrowserQuantum/"}'
if ($header.Length -gt 2048) { throw "Header too large: $($header.Length) > 2048" }

$ms = [System.IO.MemoryStream]::new()
$hb = [System.Text.Encoding]::UTF8.GetBytes($header)
$ms.Write($hb, 0, $hb.Length)
$ms.Write([byte[]]::new(2048 - $hb.Length), 0, 2048 - $hb.Length)
$ms.Write($langBytes, 0, $langBytes.Length)
$ms.Write([byte[]]::new(8192 - $langBytes.Length), 0, 8192 - $langBytes.Length)
$ms.Write($payloadBytes, 0, $payloadBytes.Length)

$verPart = if ($ReleaseTag) { "$version-$ReleaseTag" } else { $version }
$tpk = Join-Path $OutDir "${id}_TOS7_TOS6_${verPart}-${platform}.tpk"
[System.IO.File]::WriteAllBytes($tpk, $ms.ToArray())
Write-Host "TPK written: $tpk ($((Get-Item $tpk).Length) bytes)"
Write-Host "payload md5: $md5"

# ---- 6. Cleanup transient build files --------------------------------------------
Remove-Item -LiteralPath $xzOut -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $BuildDir -Force -ErrorAction SilentlyContinue
