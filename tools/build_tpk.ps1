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
    По умолчанию ..\FileBrowserQuantum_2.0.2.0_pkg

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
    [string]$PkgDir = '..\FileBrowserQuantum_2.0.2.0_pkg',
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

# ---- 1. Regenerate INFO dynamically (same format as TOS standard) --------------
$infoLines = [System.Collections.Generic.List[string]]::new()
$allFiles = Get-ChildItem -LiteralPath $PkgDir -Recurse | Sort-Object { $_.FullName.Replace('\', '/') }

foreach ($item in $allFiles) {
    $rel = [System.IO.Path]::GetRelativePath($PkgDir, $item.FullName).Replace('\', '/')
    if ($rel -eq 'INFO' -or $rel -eq 'config.ini' -or $rel.StartsWith('.')) { continue }
    if ($item.PSIsContainer) {
        $infoLines.Add("1:folder:${rel}:")
    } else {
        $fileMd5 = Get-MD5 $item.FullName
        $infoLines.Add("1:file:${rel}:${fileMd5}")
    }
}
$infoText = ($infoLines -join "`n") + "`n"
[System.IO.File]::WriteAllText((Join-Path $PkgDir 'INFO'), $infoText, [System.Text.UTF8Encoding]::new($false))
Write-Host "INFO regenerated: $((Get-Item (Join-Path $PkgDir 'INFO')).Length) bytes ($($infoLines.Count) entries)"

# ---- 2. Locate tools -------------------------------------------------------------
$go = Get-Command go -ErrorAction SilentlyContinue
if (-not $go) { $go = Get-Command 'C:\Program Files\Go\bin\go.exe' -ErrorAction SilentlyContinue }

$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }

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

# ---- 3. Build payload.tar (GNU tar via Go tool or Python fallback) -----------------
$tarPath = Join-Path $BuildDir 'payload.tar'
$xzOut   = Join-Path $BuildDir 'payload.tar.xz'

$builtTar = $false
if ($go) {
    Write-Host "Building payload.tar with tarmake (Go) ..."
    try {
        & $go.Source run ./tarmake $PkgDir $tarPath
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $tarPath)) {
            $builtTar = $true
        }
    } catch {
        Write-Warning "Go tarmake failed: $_"
    }
}

if (-not $builtTar) {
    if ($py) {
        Write-Host "Building payload.tar via Python fallback ..."
        $pyCode = @'
import tarfile, os, sys

src_dir = sys.argv[1]
out_tar = sys.argv[2]
mtime = 1785542400 # 2026-08-01 00:00:00 UTC

def filter_tar(tarinfo):
    tarinfo.uid = 0
    tarinfo.gid = 0
    tarinfo.uname = "root"
    tarinfo.gname = "root"
    tarinfo.mtime = mtime
    rel = tarinfo.name
    if tarinfo.isdir():
        tarinfo.mode = 0o755
    elif rel in ("INFO", "init.d/service") or rel.startswith("init.d/"):
        tarinfo.mode = 0o755
    elif rel in ("bin/program/filebrowserquantum", "functions/dependapps.sh") or rel.startswith("bin/program/") or rel.endswith(".sh"):
        tarinfo.mode = 0o744
    else:
        tarinfo.mode = 0o644
    return tarinfo

with tarfile.open(out_tar, "w", format=tarfile.GNU_FORMAT) as tar:
    entries = []
    for root, dirs, files in os.walk(src_dir):
        for d in dirs:
            full = os.path.join(root, d)
            rel = os.path.relpath(full, src_dir).replace("\\", "/")
            if rel.startswith(".") or os.path.basename(rel) in (".git", "Thumbs.db"):
                continue
            entries.append((rel, full, True))
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, src_dir).replace("\\", "/")
            if rel.startswith(".") or os.path.basename(rel) in (".git", "Thumbs.db", "Desktop.ini"):
                continue
            entries.append((rel, full, False))
    entries.sort(key=lambda x: x[0])
    for rel, full, is_dir in entries:
        tar.add(full, arcname=rel, recursive=False, filter=filter_tar)
'@
        $absPkg = (Resolve-Path $PkgDir).Path
        $absTar = [System.IO.Path]::GetFullPath($tarPath)
        & $py.Source -c $pyCode $absPkg $absTar
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tarPath)) {
            throw "Python tar builder failed (exit $LASTEXITCODE)"
        }
        $builtTar = $true
    } else {
        throw "Neither Go nor Python available to create GNU payload.tar"
    }
}


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

$headerObj = [ordered]@{
    id          = $cfg.id
    md5         = $md5
    icon        = $cfg.icon
    path        = $cfg.path
    name        = $cfg.name
    publisher   = $cfg.publisher
    exec        = [bool]$cfg.exec
    open_path   = [bool]$cfg.open_path
    resize      = [bool]$cfg.resize
    maxmin      = [bool]$cfg.maxmin
    state       = [bool]$cfg.state
    type        = $cfg.type
    help        = $cfg.help
    version     = $cfg.version
    recommend   = [bool]$cfg.recommend
    beta        = [bool]$cfg.beta
    category    = $cfg.category
    depend      = @($cfg.depend)
    relation    = $null
    platform    = $cfg.platform
    low_version = $cfg.low_version
    reset       = [bool]$cfg.reset
    official    = $cfg.official
}
$header = ($headerObj | ConvertTo-Json -Compress)
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

