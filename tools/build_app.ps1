#Requires -Version 5.1
<#
.SYNOPSIS
    Собирает приложение FileBrowser Quantum из исходников (frontend + backend)
    и кладёт готовый linux/amd64-бинарник в дерево TOS-пакета.

.DESCRIPTION
    Полный цикл между "положил исходники в sources\" и "pwsh tools\build_all.ps1":

      1) Применяет правки к исходникам апстрима (идемпотентно, можно повторять).
         Главная правка - i18n:
             import.meta.glob('./!(en).json')  ->  import.meta.glob('./*.json')
         Начиная с v2.1.1 фронтенд собирается Vite 8 (rolldown), который не
         поддерживает extglob "!(...)". Шаблон молча превращается в пустую карту,
         языковые чанки не попадают в бинарник, и интерфейс ВСЕГДА английский.
         Правка возвращает все языки.
      2) Собирает frontend (Vue 3 + Vite) в backend\internal\web\embed.
      3) Собирает backend (Go, linux/amd64, CGO выключен) и копирует бинарник в
         FileBrowserQuantumTOS\bin\program\filebrowserquantum.
      4) Проверяет результат: в сборке frontend должны быть языковые чанки, а
         внутри бинарника - версия из FileBrowserQuantumTOS\version.

    Версия НЕ хардкодится: она всегда берётся из FileBrowserQuantumTOS\version.
    Итоговая версия приложения = "<version>-<VersionSuffix>" (по умолчанию "beta").

    После успешного выполнения соберите пакеты: pwsh .\tools\build_all.ps1

.PARAMETER SourcesDir
    Папка с исходниками (по умолчанию ..\sources).
.PARAMETER PkgDir
    Дерево пакета (по умолчанию ..\FileBrowserQuantumTOS).
.PARAMETER VersionSuffix
    Суффикс версии приложения (по умолчанию "beta"; пустая строка - без суффикса).
.PARAMETER GoRoot
    Корень Go (например E:\go1.27.0). Если не задан - используется go из PATH.
.PARAMETER GoToolchain
    Значение GOTOOLCHAIN (например "local" или "go1.27.0"). По умолчанию не трогаем.
.PARAMETER Npm
    Команда npm (по умолчанию "npm").
.PARAMETER ForceInstall
    Всегда выполнять "npm install", даже если node_modules уже есть.
.PARAMETER SkipFrontend
    Не пересобирать frontend.
.PARAMETER SkipBackend
    Не пересобирать backend.
.PARAMETER PatchOnly
    Только применить правки к исходникам и выйти.

.EXAMPLE
    pwsh .\tools\build_app.ps1 -GoRoot E:\go1.27.0

.EXAMPLE
    pwsh .\tools\build_app.ps1 -PatchOnly
#>
[CmdletBinding()]
param(
    [string]$SourcesDir = (Join-Path $PSScriptRoot '..\sources'),
    [string]$PkgDir = (Join-Path $PSScriptRoot '..\FileBrowserQuantumTOS'),
    [string]$VersionSuffix = 'beta',
    [string]$GoRoot = '',
    [string]$GoToolchain = '',
    [string]$Npm = 'npm',
    [switch]$ForceInstall,
    [switch]$SkipFrontend,
    [switch]$SkipBackend,
    [switch]$PatchOnly
)

$ErrorActionPreference = 'Stop'

# Ожидаемые имена языковых чанков: Vite 8 (rolldown) и Vite 6.
# 'en' отдельным чанком не становится (он статически импортирован), поэтому порог 20.
$LocaleChunkPattern = '^(virtual_intlify-i18n-\d+|ar|bg|cz|de|el|es|fr|he|hu|it|ja|ko|nl|nl-be|pl|pt|pt-br|ro|ru|sk|sv-se|tr|ua|zh-cn|zh-tw)-.*\.js(\.gz)?$'
$MinLocaleChunks = 20

function Write-Head([string]$Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "    $Text" -ForegroundColor Yellow }

function Get-FullDir([string]$Path, [string]$What) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw "$What not found: $full"
    }
    return $full
}

$srcRoot = Get-FullDir $SourcesDir 'Sources dir'
$pkgRoot = Get-FullDir $PkgDir 'Package tree'

$frontendDir = Join-Path $srcRoot 'frontend'
$backendDir = Join-Path $srcRoot 'backend'
$embedDir = Join-Path $backendDir 'internal\web\embed'
$distDir = Join-Path $backendDir 'internal\web\dist'
$i18nFile = Join-Path $frontendDir 'src\i18n\index.ts'
$versionFile = Join-Path $pkgRoot 'version'
$binaryOut = Join-Path $pkgRoot 'bin\program\filebrowserquantum'

# --- 1) Правки исходников апстрима -------------------------------------------------
Write-Head 'Applying upstream source fixes'

if (-not (Test-Path -LiteralPath $i18nFile -PathType Leaf)) {
    throw "i18n source not found: $i18nFile"
}

$brokenGlob = './!(en).json'
$fixedGlob = './*.json'
$i18nText = [System.IO.File]::ReadAllText($i18nFile, [System.Text.Encoding]::UTF8)

if ($i18nText.Contains("'$fixedGlob'")) {
    Write-Ok "i18n already fixed ('$fixedGlob')"
}
elseif ($i18nText.Contains("'$brokenGlob'")) {
    $i18nText = $i18nText.Replace("'$brokenGlob'", "'$fixedGlob'")
    [System.IO.File]::WriteAllText($i18nFile, $i18nText, (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "i18n patched: '$brokenGlob' -> '$fixedGlob'"
}
else {
    throw @"
Cannot patch i18n: neither '$fixedGlob' nor '$brokenGlob' found in
  $i18nFile
Upstream probably changed this file. Open it and check the locales
import.meta.glob(...) pattern: with Vite 8 (rolldown) it must NOT use extglob '!(...)'.
"@
}

if ($PatchOnly) {
    Write-Ok 'PatchOnly: skipping frontend/backend build.'
    return
}

$version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if (-not $version) { throw "Empty version file: $versionFile" }
$appVersion = if ($VersionSuffix) { "$version-$VersionSuffix" } else { $version }

Write-Host ''
Write-Host "    package version : $version"
Write-Host "    app version     : $appVersion" -ForegroundColor Cyan

# --- 2) Frontend -------------------------------------------------------------------
if (-not $SkipFrontend) {
    Write-Head 'Building frontend (Vue 3 + Vite)'

    if (-not (Test-Path -LiteralPath (Join-Path $frontendDir 'package.json') -PathType Leaf)) {
        throw "Frontend sources not found: $frontendDir"
    }

    Push-Location -LiteralPath $frontendDir
    try {
        if ($ForceInstall -or -not (Test-Path -LiteralPath (Join-Path $frontendDir 'node_modules') -PathType Container)) {
            Write-Host "    $Npm install --no-audit --no-fund"
            & $Npm install --no-audit --no-fund
            if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
        }
        else {
            Write-Ok 'node_modules present (use -ForceInstall to reinstall)'
        }

        # npm-скрипт "build" использует rm -rf/cp -r (Unix) - берём build:docker (чистый vite build)
        # и раскладываем результат сами: так одинаково работает и на Windows, и на Linux.
        Write-Host "    $Npm run build:docker"
        & $Npm run build:docker
        if ($LASTEXITCODE -ne 0) { throw "npm run build:docker failed (exit $LASTEXITCODE)" }
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $distDir -PathType Container)) {
        throw "Frontend build produced no dist dir: $distDir"
    }
    if (-not (Test-Path -LiteralPath $embedDir -PathType Container)) {
        New-Item -ItemType Directory -Path $embedDir -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $embedDir -Force | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $distDir '*') -Destination $embedDir -Recurse -Force
    Write-Ok "embed <- dist"

    # Проверка: без правки i18n чанков локалей не будет, и интерфейс будет только английским.
    $assetsDir = Join-Path $embedDir 'assets'
    if (-not (Test-Path -LiteralPath $assetsDir -PathType Container)) {
        throw "No assets dir in the frontend build: $assetsDir"
    }
    $localeChunks = @(Get-ChildItem -LiteralPath $assetsDir -File | Where-Object { $_.Name -match $LocaleChunkPattern })
    Write-Ok "locale chunks in the frontend build: $($localeChunks.Count)"
    if ($localeChunks.Count -lt $MinLocaleChunks) {
        throw @"
Frontend build contains only $($localeChunks.Count) locale chunk(s), expected >= $MinLocaleChunks.
The i18n import.meta.glob pattern is probably broken again (Vite 8 / rolldown does not
support extglob '!(...)'), so the UI would be English-only.
Check: $i18nFile
"@
    }
}

# --- 3) Backend --------------------------------------------------------------------
if (-not $SkipBackend) {
    Write-Head 'Building backend (Go, linux/amd64)'

    if (-not (Test-Path -LiteralPath (Join-Path $backendDir 'go.mod') -PathType Leaf)) {
        throw "Backend sources not found: $backendDir"
    }

    $savedEnv = @{}
    foreach ($name in @('GOOS', 'GOARCH', 'CGO_ENABLED', 'GOROOT', 'PATH', 'GOTOOLCHAIN')) {
        $savedEnv[$name] = [System.Environment]::GetEnvironmentVariable($name)
    }

    $builtBinary = Join-Path $backendDir 'filebrowserquantum'
    try {
        if ($GoRoot) {
            $env:GOROOT = $GoRoot
            $env:PATH = (Join-Path $GoRoot 'bin') + [System.IO.Path]::PathSeparator + $env:PATH
        }
        if ($GoToolchain) { $env:GOTOOLCHAIN = $GoToolchain }
        $env:GOOS = 'linux'
        $env:GOARCH = 'amd64'
        $env:CGO_ENABLED = '0'

        $ldflags = "-w -s -X github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=$appVersion"
        Write-Host "    go build -trimpath -ldflags `"$ldflags`" -o filebrowserquantum ."

        Push-Location -LiteralPath $backendDir
        try {
            & go build -trimpath -ldflags $ldflags -o filebrowserquantum .
            if ($LASTEXITCODE -ne 0) { throw "go build failed (exit $LASTEXITCODE)" }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        foreach ($name in $savedEnv.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, $savedEnv[$name])
        }
    }

    if (-not (Test-Path -LiteralPath $builtBinary -PathType Leaf)) {
        throw "Backend build produced no binary: $builtBinary"
    }
    $binDir = Split-Path -Parent $binaryOut
    if (-not (Test-Path -LiteralPath $binDir -PathType Container)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $builtBinary -Destination $binaryOut -Force
    Write-Ok ("binary -> {0} ({1:N0} bytes)" -f $binaryOut, (Get-Item -LiteralPath $binaryOut).Length)

    # Проверка: внутри бинарника должна быть ожидаемая версия и встроенный frontend.
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($binaryOut))
    if (-not $text.Contains($appVersion)) {
        throw "Version string '$appVersion' not found inside the binary - the build is wrong."
    }
    $assetCount = ([regex]::Matches($text, '\.js\.gz')).Count
    Write-Ok "binary reports version $appVersion; embedded .js.gz assets: $assetCount"
    if ($SkipFrontend -eq $false -and $assetCount -lt $MinLocaleChunks) {
        Write-Warn "Only $assetCount embedded .js.gz assets - check that the frontend was built into embed."
    }
}

# --- Итог --------------------------------------------------------------------------
Write-Head 'Done'
Write-Host "    app version : $appVersion"
if (-not $SkipFrontend) { Write-Host "    frontend    : $embedDir" }
if (-not $SkipBackend) { Write-Host "    binary      : $binaryOut" }
Write-Host ''
Write-Host 'Next: pwsh .\tools\build_all.ps1' -ForegroundColor Cyan
