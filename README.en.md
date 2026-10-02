# FileBrowser Quantum — TPK package for TerraMaster (TOS6/TOS7)

> **Language:** English · [Русский](README.md)

<div align="center">

[![Version](https://img.shields.io/badge/Version-2.X.Xbeta-blue.svg)]()
[![Platform](https://img.shields.io/badge/Platform-TOS-blue.svg)]()
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

  <img width="150" alt="FileBrowser Quantum logo" src="https://github.com/user-attachments/assets/c40b22c9-33da-47b7-bc4c-ce69bb5cc174">
  <h3>FileBrowser Quantum</h3>
  The best free self-hosted web file manager.
  <br/><br/>
  <img width="800" alt="File list in FileBrowser Quantum (dark mode)" src="/images/FileBrowserForTos.png">
</div>

- Ready-to-use **FileBrowser Quantum 2.X.X-beta** package for x86_64 TerraMaster NAS (TOS6/TOS7).
- This repository contains releases, the package tree, build tools, and everything needed to rebuild the package.

## Credits

- **Original module author:** [OutkastM](https://tmnascommunity.eu/download/filebrowserquantum/) — TerraMaster Community Place.
- **Updated to 2.X.X-beta by:** [Mr712](https://github.com/byMr712?tab=repositories).
- This package is built solely from the original module **1.2.1-stable** packaging and the
  [FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser) source code.
- **Nothing was removed from or added to the original module** — only the FileBrowser Quantum
  application itself was updated to v2.X.X-beta and its configuration adapted.
  
## Disclaimer

This package is provided **as is**, without warranties of any kind, either express or implied,
including, but not limited to, the implied warranties of merchantability, fitness for a particular purpose, and non-infringement.

- This package is a **beta** build (2.X.X-beta) from a community member and is **not** an official
release of TerraMaster or FileBrowser.
- Use at your own risk. The author is **not responsible** for data loss, system crashes, downtime, or any other consequences of installing and using this package.
- Always back up your data and NAS configuration before installing or updating.
- There is no guarantee that this package will work on your specific hardware or TOS version.
Support is provided on a "best effort" basis only.

## License & attribution

- **FileBrowser Quantum** is released under the **Apache License 2.0**
  (Copyright 2018 File Browser contributors). Full license text: [`LICENSE`](LICENSE).
- Original TPK module (packaging) © OutkastM.
- Change and attribution notices: [`NOTICE`](NOTICE).
- The bundled XZ Utils (`tools/xz/`) are third-party free software — GPL-2.0+ (xz CLI) and
  0BSD (liblzma). See `tools/xz/COPYING*`.
  
## Requirements:

- For TOS version 6: 6.0.420 or higher (no need to install PHP separately)
- For TOS version 7: 7.0.0269 or higher (PHP 7.4 must be installed)
  
## Upgrading from version v1.x?

Upgrade steps:

1. **Stop** the old FileBrowser.
2. Make a copy of the **filebrowser.db** database and the **filebrowser.yml** config file in a safe place (preferably outside the NAS), but the original files must also remain in the directory for the automatic migration to succeed — do not move them. On upgrade, the old config will be saved as **filebrowser.yml.legacy**, the database will be converted to **filebrowser.sqlite**, and the old **filebrowser.db** will stay in place but will no longer be used.
3. Install and start the new version through the app store — it will automatically attempt to migrate your old **.db** database to the new **.sqlite**.
4. After the app starts, you may need to add your volumes (Volume) to the new **filebrowser.yml** config if you created other volumes besides the standard **Volume1** and **Volume2**, then re-grant these non-standard volumes to each existing user.
   If your volumes were standard — nothing to do!

## FFmpeg support (the `-ffmpeg` variant)

The package is available in two variants:

- **Regular** — `FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-x86_64.tpk`. Video previews,
  durations and embedded subtitles work only if `ffmpeg`/`ffprobe` are already installed
  on the NAS (and `integrations.media.ffmpegPath` is set in `filebrowser.yml`).
- **With ffmpeg** — `FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-ffmpeg-x86_64.tpk`. Static
  `ffmpeg`/`ffprobe` are bundled inside the package (`bin/ffmpeg/`, mode 0744, John Van
  Sickle static builds, GPLv3 — see [`NOTICE`](NOTICE)). Video previews, durations and
  embedded subtitles work right after installation, no NAS-side setup required.

### Upgrading from the regular version to `-ffmpeg`

You can install the `-ffmpeg` package **directly over the regular version** — no need to
remove it first. The existing `filebrowser.yml` is not overwritten on upgrade (that is
normal): the ffmpeg variant sets the `FILEBROWSER_FFMPEG_PATH=/usr/local/FileBrowserQuantum/bin/ffmpeg`
environment variable in `init.d/service`, which is read at startup and does not depend on
the config file. The service also restarts an already-running daemon automatically during
installation, so running `init.d/service reload` manually is not required.

### Going back from `-ffmpeg` to the regular version

Installing the regular version over `-ffmpeg` **will not break** FileBrowser: without a
working ffmpeg the media features are simply disabled (a `ffmpeg unavailable` warning
appears in the log). However, the bundled binaries may **remain** on disk (~160 MB):
the TOS installer does not always delete files that are absent from the new package.
To remove them:

1. Stop FileBrowser in the App Center (or `service stop`).
2. Manually delete:
   - `/usr/local/FileBrowserQuantum/bin/ffmpeg/` — the ffmpeg/ffprobe binaries.
3. Start FileBrowser again.

Alternatively, perform a **clean reinstall**: remove the package via the App Center and
install it again.

> ⚠️ **Warning:** a clean reinstall **deletes all FileBrowser data** — the `filebrowser.yml`
> config, the `filebrowser.sqlite` database (older versions: `filebrowser.db`), settings and
> user permissions. Before removing the package, back these files up to a safe location
> (preferably outside the NAS) and proceed with caution.

## Folder contents

| Path | Description |
|---|---|
| `FileBrowserQuantumTOS/` | Package tree (payload sources): `config.ini`, `.lang`, `INFO`, `version`, `bin/`, `functions/`, `images/`, `init.d/`, `webui.bz2` |
| `tools/build_all.ps1` | Builds **both** TPKs — regular and with ffmpeg — in one call (auto-downloads ffmpeg when missing) |
| `tools/build_all.sh` | Same for Linux / macOS (Bash): `bash tools/build_all.sh`; auto-downloads ffmpeg |
| `tools/build_tpk.ps1` | Builds one `.tpk` on Windows PowerShell (`-FFmpegDir` — ffmpeg variant) |
| `tools/build_tpk.sh` | Builds `.tpk` on Linux / macOS (Bash); 4th argument or `FFMPEG_DIR` — ffmpeg variant |
| `tools/tarmake/` | Go utility: builds a GNU tar with the correct permissions (`root:root`, matching the original) |
| `tools/go.work` | Go workspace so tarmake can be built from `tools\` (`go run ./tarmake ...`) |
| `tools/xz/` | Bundled `xz.exe` + `liblzma-5.dll` + XZ Utils licenses (COPYING, COPYING.0BSD, COPYING.GPLv2, AUTHORS). Used unless xz is found in Git for Windows |
| `tools/fetch_ffmpeg.ps1` | Automatically downloads static ffmpeg/ffprobe (linux x86_64) into `tools/ffmpeg/` for the `-ffmpeg` variant |
| `tools/fetch_ffmpeg.sh` | Same for Linux / macOS (curl or wget) |
| `README.md` | README in Russian (default) |
| `README.en.md` | README in English (user choice) |
| `images/` | Screenshots for the README |
| `LICENSE` | Apache License 2.0 (FileBrowser Quantum) |
| `NOTICE` | Attribution and modification notices |
| `.gitignore` / `.gitattributes` | Git excludes |

## .tpk structure

```
[0..2048)      JSON header; "md5" field = md5(payload.tar.xz), zero-padded
[2048..10240)  contents of FileBrowserQuantum.lang, zero-padded to 8192
[10240..end)   payload.tar.xz (magic FD 37 7A 58 5A 00)
```

Key facts (verified against the original 1.2.1.0 package):
- The `md5` in the JSON header is the md5 of the **whole** payload.tar.xz (not of the tar itself).
- The payload is a **GNU** tar (`ustar `), owner/group `root:root`.
- `INFO` is a list of `1:file:<path>:<md5>` / `1:folder:<path>:`, where md5 is the md5 of the file contents.
- `config.ini` is present in the payload but is **not** listed in `INFO`.

## Build requirements

- **Go 1.27+** (tested with 1.27.0) — to build the backend and the tarmake utility. https://go.dev/dl/
  If several Go installs exist and one is broken, the scripts try each found Go and use the
  first one that actually compiles tarmake; override explicitly with
  `GO_127_ROOT=<dir containing bin/go>`.
- **Node 20+ / npm** — not required for script-based builds, only for a full frontend rebuild.
- **Windows:** `xz.exe` is bundled in `tools/xz/` (with its licenses); a separate Git for Windows
  install is not required. If xz is missing, the PowerShell script looks for
  `C:\Program Files\Git\mingw64\bin\xz.exe`.
- **Linux / macOS:** a system `xz` is required (`apt install xz-utils` / `brew install xz`) and
  `curl` or `wget` for the ffmpeg auto-download.

## xz.exe license

XZ Utils is free software. The `xz.exe` CLI is distributed under **GNU GPL v2+**, while the
`liblzma-5.dll` library is under **0BSD** (public domain). The license files `COPYING`,
`COPYING.0BSD`, `COPYING.GPLv2` and `AUTHORS` ship next to the binaries. xz is only needed at
build time and never ends up inside the `.tpk`. If you redistribute the `tools/` folder, keep
these files.

## Quick rebuild of the .tpk from the existing tree

Edit files in `FileBrowserQuantumTOS/` (e.g. `bin/filebrowser.yml` — the volume list,
`version` — package version, `config.ini` and `.lang` — name/version shown in App Center), then:

```powershell
pwsh .\tools\build_tpk.ps1
```

The script will:
1. regenerate `INFO` (md5 of every file in the tree);
2. build `payload.tar` (tarmake, root:root permissions);
3. compress it with `xz -9e` → `payload.tar.xz`;
4. assemble the `.tpk` (header + .lang + payload) into the parent folder;
5. take the file name and the header version from `config.ini`.

Result name — `<id>_TOS7_TOS6_<version>[-<tag>]-<platform>.tpk`, e.g.
`FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-x86_64.tpk` (id, version and platform come from `config.ini`).

All default paths are **relative to the script folder** `tools\`: package tree
`..\FileBrowserQuantumTOS`, result `..\FileBrowserQuantum ... .tpk`.
Intermediate files live in a temporary `tools\_build\` subfolder and are removed after the build
(nothing is written to `%TEMP%`). The script can be run from anywhere.

Options: `-PkgDir <path>` (default `..\FileBrowserQuantumTOS`),
`-OutDir <where to put the .tpk>` (default `..`), `-XzPath <path to xz.exe>`,
`-ReleaseTag <version tag in the file name>` (default `beta`; for a stable release use
`-ReleaseTag ''` → `FileBrowserQuantum_TOS7_TOS6_2.X.X.X-x86_64.tpk`).

### Building both variants with a single command (recommended)

The regular package and the ffmpeg package are built in one call — the static
ffmpeg/ffprobe are downloaded automatically (once, into `tools/ffmpeg/`) if missing:

```powershell
# Windows
pwsh -NoProfile -Command "& .\tools\build_all.ps1"
```

```bash
# Linux / macOS
bash tools/build_all.sh
```

Result (names and version come from `config.ini`):

```
FileBrowserQuantum_TOS7_TOS6_<version>-beta-x86_64.tpk
FileBrowserQuantum_TOS7_TOS6_<version>-beta-ffmpeg-x86_64.tpk
```

Options: `-BaseReleaseTag` / `-FFmpegReleaseTag` (file-name tags; default
`beta` / `beta-ffmpeg`), `-FFmpegDir <path>` (use your own ffmpeg binaries, no auto
download), `-KeepGoing` (still build the second variant if the first fails),
`-SkipFfmpegFetch` (do not download — require already-downloaded binaries).

The same via environment variables in `build_all.sh`:
`BASE_RELEASE_TAG` / `FFMPEG_RELEASE_TAG`, `FFMPEG_DIR=<path>`, `KEEP_GOING=1`,
`SKIP_FFMPEG_FETCH=1`, `PKG_DIR=<path>`, `OUT_DIR=<path>`.

### Building with ffmpeg support (video previews, durations, embedded subtitles)

```powershell
# 1) Download static ffmpeg/ffprobe (linux x86_64) into tools\ffmpeg\
pwsh .\tools\fetch_ffmpeg.ps1

# 2) Build the ffmpeg .tpk: a staging tree is created automatically,
#    the source FileBrowserQuantumTOS\ tree is not modified
pwsh .\tools\build_tpk.ps1 -ReleaseTag 'beta-ffmpeg' -FFmpegDir '.\ffmpeg'
# → FileBrowserQuantum_TOS7_TOS6_<version>-beta-ffmpeg-x86_64.tpk
```

On Linux / macOS the same steps:

```bash
# 1) Download ffmpeg/ffprobe
bash tools/fetch_ffmpeg.sh

# 2) Build the ffmpeg variant (staging copy; source tree untouched)
bash tools/build_tpk.sh ../FileBrowserQuantumTOS .. beta-ffmpeg tools/ffmpeg
# → FileBrowserQuantum_TOS7_TOS6_<version>-beta-ffmpeg-x86_64.tpk
```

The ffmpeg variant adds `bin/ffmpeg/{ffmpeg,ffprobe}` (mode 0744) to the payload
and sets `integrations.media.ffmpegPath` in `bin/filebrowser.yml`. It also patches
`init.d/service` (in the staging copy only): adds
`export FILEBROWSER_FFMPEG_PATH=/usr/local/FileBrowserQuantum/bin/ffmpeg` and an
auto-restart of any already-running daemon on start — so previews activate even when
upgrading over an old config, without a manual `service reload`. The binaries are
John Van Sickle static builds (GPLv3), see `NOTICE` for details.

## Full rebuild from the filebrowser sources

The backend/frontend sources live separately, e.g. in the `sources/` folder.
Steps:

```powershell
# 1) Frontend (Vue3) -> backend/internal/web/embed
cd <src>\frontend
npm install --no-audit --no-fund
Remove-Item -Recurse -Force ..\backend\internal\web\embed\*   # npm "build" script uses rm -rf (does not work in cmd)
npm run build:docker                                          # vite build -> ../backend/internal/web/dist
Copy-Item -Recurse -Force ..\backend\internal\web\dist\* ..\backend\internal\web\embed\

# 2) Backend (Go) -> linux/amd64 binary (no mupdf tag, CGO not needed)
cd <src>\backend
$env:GOTOOLCHAIN="go1.27.0"
$env:GOOS="linux"; $env:GOARCH="amd64"; $env:CGO_ENABLED="0"
go build -trimpath -o filebrowserquantum --ldflags="-w -s -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.CommitSHA=n/a' -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=2.X.X-beta'" .

# 3) Replace the binary in the package tree
Copy-Item backend\filebrowserquantum .\FileBrowserQuantumTOS\bin\program\filebrowserquantum

# 4) Rebuild the TPK
pwsh .\tools\build_tpk.ps1
```

Note: `npm run build` in `package.json` calls `rm -rf` and `cp -r` (Unix commands), so under Windows
it is replaced by the `Remove-Item` / `Copy-Item` steps above.

## Application configuration

- `bin/filebrowser.yml` — working v2 config (FileBrowser Quantum 2.0 format):
  `http.port: 8087`, `server.sources` (volumes), `server.database.path` (SQLite).
Upon the first launch, it is copied to the NAS configuration folder.
The default username is always `admin`. What the password is depends on the FileBrowser Quantum version:
  - **packages up to 2.0.8 (inclusive)** (including all 1.x) — on a clean install the default password is `admin`;
  - **packages 2.0.9+** (current 2.1.0.0) — on a clean install `admin` no longer works: when the app
    starts with no existing database, a random admin password (12 hex characters) is generated and
    **printed once** to the startup log `/usr/local/FileBrowserQuantum/FileBrowserQuantum_start.log`,
    as a line like `Generated initial admin password for user "admin" (…): …`. Log in with it and change the password.
  - The password lives in the SQLite database: upgrading over an existing install (database already
    present) does **not** change the credentials; after a factory reset (`service reset`, database
    deleted) a new password is generated.
  - To set (or recover) a known password, add to the working config on the NAS: `auth.methods.password.adminPassword: <password>`
    (must be **non-empty and not `admin`**). It works at any time — on a clean install and later:
    the password is applied on every daemon start. Removing the line is optional: while it stays in the
    config the password is always this one; to change the password via the UI, delete the line.
- `bin/filebrowser.migrate.yml` — config for upgrading from the old 1.2.1 version:
  adds `server.database.migrateFrom` pointing at the old BoltDB `filebrowser.db`;
  FileBrowser migrates users/shares/rules to SQLite automatically.
- `init.d/service` on startup: if an old v1 config is found (line `database: /path`),
  it is saved as `filebrowser.yml.legacy` and the new one is installed; if the old `filebrowser.db`
  exists but the new SQLite does not, the migration config is installed.
- `webui.bz2` — TOS "Support & Help" PHP frontend, version-independent, no changes needed.

## File permissions in the payload (matching the original)

| File | Permissions |
|---|---|
| `INFO`, `init.d/service` | 0755 |
| `bin/program/filebrowserquantum`, `functions/dependapps.sh` | 0744 |
| directories | 0755 |
| all other files | 0644 |

All files are owned by `root:root`.

## Verifying the result

```powershell
# 1. The md5 in the header must equal the md5 of the payload
$b=[IO.File]::ReadAllBytes("$pwd\FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-x86_64.tpk")
# 2. The payload can be cut out (offset 10240) and inspected: tar -tvf
```
