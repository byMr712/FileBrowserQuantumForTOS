# FileBrowser Quantum — TPK package for TerraMaster (TOS6/TOS7)

> **Language:** English · [Русский](README.md)

Built package **FileBrowser Quantum 2.0.0-beta** for TerraMaster x86_64 NAS (TOS6/TOS7).
This folder contains the package tree, build tools, and everything needed to rebuild it.

## Credits

- **Original module author:** [OutkastM](https://tmnascommunity.eu/download/filebrowserquantum/) — TerraMaster Community Place.
- **Updated to 2.0.0-beta by:** [Mr712](https://github.com/byMr712?tab=repositories).
- This package is built solely from the original module **1.2.1-stable** packaging and the
  [FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser) source code.
  **Nothing was removed from or added to the original module** — only the FileBrowser Quantum
  application itself was updated to v2.0.0-beta and its configuration adapted.

## License & attribution

- **FileBrowser Quantum** is released under the **Apache License 2.0**
  (Copyright 2018 File Browser contributors). Full license text: [`LICENSE`](LICENSE).
- Original TPK module (packaging) © OutkastM.
- Change and attribution notices: [`NOTICE`](NOTICE).
- The bundled XZ Utils (`tools/xz/`) are third-party free software — GPL-2.0+ (xz CLI) and
  0BSD (liblzma). See `tools/xz/COPYING*`.

## Folder contents

| Path | Description |
|---|---|
| `FileBrowserQuantum_TOS7_TOS6_2.0.0.0-beta-x86_64.tpk` | Ready package for App Center |
| `FileBrowserQuantum_2.0.0.0_pkg/` | Package tree (payload sources): `config.ini`, `.lang`, `INFO`, `version`, `bin/`, `functions/`, `images/`, `init.d/`, `webui.bz2` |
| `tools/build_tpk.ps1` | Build script for the `.tpk` from the package tree (all paths are relative to `tools\`) |
| `tools/tarmake/` | Go utility: builds a GNU tar with the correct permissions (`root:root`, matching the original) |
| `tools/go.work` | Go workspace so tarmake can be built from the `tools\` folder (`go run ./tarmake ...`) |
| `tools/xz/` | Bundled `xz.exe` + `liblzma-5.dll` + XZ Utils licenses (COPYING, COPYING.0BSD, COPYING.GPLv2, AUTHORS). Used unless xz is found in Git for Windows |
| `README.md` | README in English (default) |
| `README.ru.md` | README in Russian (automatically displayed on GitHub to users with a Russian interface language) |
| `LICENSE` | Apache License 2.0 (FileBrowser Quantum) |
| `NOTICE` | Attribution and modification notices |

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

- **Go 1.26+** (tested with 1.26.5) — to build the backend and the tarmake utility. https://go.dev/dl/
- **Node 20+ / npm** — not required for script-based builds, only for a full frontend rebuild.
- **xz.exe** — bundled in `tools/xz/` (with its licenses); a separate Git for Windows install is not required.
  If xz is missing, the script looks for `C:\Program Files\Git\mingw64\bin\xz.exe`.

### xz.exe license

XZ Utils is free software. The `xz.exe` CLI is distributed under **GNU GPL v2+**, while the
`liblzma-5.dll` library is under **0BSD** (public domain). The license files `COPYING`,
`COPYING.0BSD`, `COPYING.GPLv2` and `AUTHORS` ship next to the binaries. xz is only needed at
build time and never ends up inside the `.tpk`. If you redistribute the `tools/` folder, keep
these files.

## Quick rebuild of the .tpk from the existing tree

Edit files in `FileBrowserQuantum_2.0.0.0_pkg/` (e.g. `bin/filebrowser.yml` — the volume list,
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
`FileBrowserQuantum_TOS7_TOS6_2.0.0.0-beta-x86_64.tpk` (id, version and platform come from `config.ini`).

All default paths are **relative to the script folder** `tools\`: package tree
`..\FileBrowserQuantum_2.0.0.0_pkg`, result `..\FileBrowserQuantum ... .tpk`.
Intermediate files live in a temporary `tools\_build\` subfolder and are removed after the build
(nothing is written to `%TEMP%`). The script can be run from anywhere.

Options: `-PkgDir <path>` (default `..\FileBrowserQuantum_2.0.0.0_pkg`),
`-OutDir <where to put the .tpk>` (default `..`), `-XzPath <path to xz.exe>`,
`-ReleaseTag <version tag in the file name>` (default `beta`; for a stable release use
`-ReleaseTag ''` → `FileBrowserQuantum_TOS7_TOS6_2.0.0.0-x86_64.tpk`).

## Full rebuild from the filebrowser sources

The backend/frontend sources live separately, e.g. `C:\Users\Mr712\Desktop\filebrowser-2.0.0-beta`.
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
$env:GOOS="linux"; $env:GOARCH="amd64"; $env:CGO_ENABLED="0"
go build -trimpath -o filebrowserquantum --ldflags="-w -s -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.CommitSHA=n/a' -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=2.0.0-beta'" .

# 3) Replace the binary in the package tree
Copy-Item backend\filebrowserquantum .\FileBrowserQuantum_2.0.0.0_pkg\bin\program\filebrowserquantum

# 4) Rebuild the TPK
pwsh .\tools\build_tpk.ps1
```

Note: `npm run build` in `package.json` calls `rm -rf` and `cp -r` (Unix commands), so under Windows
it is replaced by the `Remove-Item` / `Copy-Item` steps above.

## Application configuration

- `bin/filebrowser.yml` — working v2 config (FileBrowser Quantum 2.0 format):
  `http.port: 8087`, `server.sources` (volumes), `server.database.path` (SQLite).
  On first start it is copied to the NAS config folder. Default login `admin/admin`.
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
$b=[IO.File]::ReadAllBytes("$pwd\FileBrowserQuantum_TOS7_TOS6_2.0.0.0-beta-x86_64.tpk")
# 2. The payload can be cut out (offset 10240) and inspected: tar -tvf
```
