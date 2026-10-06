# AGENTS.md

Инструкции для ИИ-агентов и разработчиков по сборке/обновлению TPK-пакета
**FileBrowser Quantum** для TerraMaster (TOS6/TOS7).

Репозиторий: `E:\GitHub\FileBrowserQuantumForTOS`

> **Важно:** версия пакета в этой инструкции **не захардкожена** — она определяется
> содержимым дерева пакета (см. _Обновление версии_ ниже). Не подставляйте версию "на глаз",
> всегда берите её из `config.ini` / `version`.

---

## Общая структура репозитория

| Путь | Что это |
|---|---|
| `FileBrowserQuantumTOS/` | **Дерево пакета (payload)** — из него собирается `.tpk`. Это «исходные файлы» пакета и единственное, что попадает внутрь `.tpk`. |
| `tools/` | Инструменты сборки: `build_all.ps1` / `build_all.sh` (оба варианта одной командой, Windows / Linux-macOS), `build_tpk.ps1` (Windows) / `build_tpk.sh` (Linux/macOS; один вариант; 4-й аргумент или `FFMPEG_DIR` — ffmpeg-вариант), `tarmake/` (Go-утилита GNU-tar), `xz/` (вложенный xz.exe + liblzma), `fetch_ffmpeg.ps1` / `fetch_ffmpeg.sh` (скачивание статических ffmpeg/ffprobe). |
| `tools/ffmpeg/` | Скачанные статические бинарники `ffmpeg`/`ffprobe` (linux x86_64, John Van Sickle, GPLv3). **Игнорируются git**, в git не коммитятся. Нужны только для сборки `-ffmpeg`-варианта. |
| `sources/` | **Upstream исходники FileBrowser Quantum** (`https://github.com/gtsteffaniak/filebrowser`). Игнорируются git (`sources/`), **в `.tpk` не попадают**. ✅ Удалять можно — для сборки `.tpk` не нужны. |
| `FileBrowserQuantum_TOS7_TOS6_*.tpk` | Готовые пакеты (игнорируются git). Может быть два варианта одной версии: без ffmpeg (`...-beta-x86_64.tpk`) и с ffmpeg (`...-beta-ffmpeg-x86_64.tpk`). |
| `README.md` / `README.en.md` / `NOTICE` | Документация и атрибуция. |
| `AGENTS.md` | Этот файл (игнорируется git — локальные инструкции). |

---

## Двухуровневая модель сборки (ВАЖНО понимать)

1. **Упаковка `.tpk`** — собирается ТОЛЬКО из дерева пакета `FileBrowserQuantumTOS/`
   скриптом `tools/build_tpk.ps1`. **Исходники `sources/` и исходники Go/frontend не нужны.**
   Бинарник `bin/program/filebrowserquantum` уже готов и просто упаковывается.

2. **Пересборка бинарника** — если нужно изменить/пересобрать само приложение, для этого
   требуются исходники (frontend Vue3 + backend Go) из `sources/`
   (или скачанные с upstream). Только потом заменяется бинарник в дереве пакета и собирается `.tpk`.

---

## Дерево пакета (payload): что где

```
FileBrowserQuantumTOS/
├── INFO                     # Пересчитывается скриптом автоматически (md5 всех файлов)
├── config.ini               # JSON: id/version/platform и пр. → версия/имя в App Center и имя файла
├── FileBrowserQuantum.lang  # Локализованные name/version (в каждом блоке локали — своя version)
├── version                  # Простая текстовая строка версии
├── webui.bz2                # PHP-интерфейс "Support & Help" TOS (версия не зависит)
├── bin/
│   ├── filebrowser.yml           # рабочий конфиг v2 (http.port 8087, sources, sqlite)
│   ├── filebrowser.migrate.yml   # конфиг миграции со старой БД
│   ├── ffmpeg/                   # ТОЛЬКО в -ffmpeg-варианте: ffmpeg + ffprobe (статик, GPLv3)
│   └── program/filebrowserquantum  # САМ БИНАРНИК (собран из upstream sources/)
├── functions/dependapps.sh  # TOS-хелперы конфиг-папок
├── images/icons/FileBrowserQuantum.png
└── init.d/service           # start/stop/reload/status (содержит VERSION)
```

Права в payload (как в оригинале, задаёт `tarmake`): каталоги/`INFO`/`init.d/service` = 0755,
`bin/program/filebrowserquantum` + `functions/*.sh` + `bin/ffmpeg/*` = 0744, остальное = 0644. Все `root:root`.
> `bin/ffmpeg/*` (ffmpeg-вариант) обязаны быть 0744 — иначе `exec.LookPath` при старте не найдёт бинарник на NAS.

---

## Go toolchain

Требуется **Go >= 1.27.0** (см. `sources/backend/go.mod`).
Рабочий Go лежит в `E:\go1.27.0` (zip-распаковка, **не MSI**).

Системный `C:\Program Files\Go` **не использовать** — там смешаны файлы от 1.26 и 1.27,
стандартная библиотека повреждена (`internal/strconv`, ошибки вида `uint64pow10 redeclared`,
`undefined: decimalSlice`). Любая сборка на нём падает.

Перед **любой** сборкой Go (backend или `tarmake`) выставить:

    $env:GOROOT = "E:\go1.27.0"
    $env:PATH = "E:\go1.27.0\bin;$env:PATH"
    $env:GOTOOLCHAIN = "local"

Проверка «здоровья»:

    go version        # → go1.27.0 windows/amd64
    go build std      # без ошибок

Перед сборкой `.tpk` (`build_tpk.ps1`) сбрасывать `GOOS`/`GOARCH`/`CGO_ENABLED`
не требуется — скрипт сам их временно удаляет перед `go run ./tarmake` и восстанавливает
после (это защищает от застрявших переменных после сборки linux-бинарника backend).
Ручной сброс (`Remove-Item Env:\GOOS, ...`) всё ещё безвреден.

---

## Сборка `.tpk` из существующего дерева (быстро)

```powershell
cd E:\GitHub\FileBrowserQuantumForTOS
$env:GOROOT = "E:\go1.27.0"
$env:PATH = "E:\go1.27.0\bin;$env:PATH"
$env:GOTOOLCHAIN = "local"
Remove-Item Env:\GOOS, Env:\GOARCH, Env:\CGO_ENABLED -ErrorAction SilentlyContinue
pwsh -NoProfile -Command "& .\tools\build_tpk.ps1"
```

Что делает скрипт:
1. Нормализует текстовые файлы в LF (CRLF ломает shebang на TOS).
2. Пересчитывает `INFO` (md5 каждого файла дерева).
3. Собирает `payload.tar` (GNU tar, root:root, права по таблице) утилитой `tarmake` (Go).
4. Сжимает `xz -9e` → `payload.tar.xz`.
5. Собирает `.tpk`: JSON-заголовок (0..2048) + `.lang` (2048..10240, дополн. до 8192) + payload (10240..end).
6. Имя файла и версия берутся из `config.ini` → `FileBrowserQuantum_TOS7_TOS6_<version>[-tag]-<platform>.tpk`.

Опции: `-PkgDir` (по умолч. `..\FileBrowserQuantumTOS`), `-OutDir`, `-XzPath`, `-ReleaseTag`
(по умолч. `beta`; `''` — стабильный без суффикса), `-FFmpegDir` (каталог с `ffmpeg`/`ffprobe`).

Итоговый файл вида `FileBrowserQuantum_TOS7_TOS6_<версия из config.ini>[-tag]-<platform>.tpk`.

`tools/build_tpk.sh` — то же самое под Linux/macOS (нужен рабочий Go + xz; 4-й аргумент или
`FFMPEG_DIR` — ffmpeg-вариант). PS- и bash-скрипты дают байт-идентичные `.tpk` (проверено).

---

## Два варианта пакета: без ffmpeg и с ffmpeg (`-ffmpeg`)

По умолчанию собирается **обычный** пакет (как раньше): превью видео/длительность/субтитры
работают, только если на NAS уже установлены системные `ffmpeg`/`ffprobe`
(и прописан `integrations.media.ffmpegPath` во `filebrowser.yml`).

**`-ffmpeg`-вариант** кладёт статические `ffmpeg`/`ffprobe` прямо в payload —
всё заработает «из коробки», без настройки на NAS. Бинарники берутся из `tools/ffmpeg/`
(скачиваются скриптом `tools/fetch_ffmpeg.ps1`, John Van Sickle static builds, GPLv3, атрибуция в `NOTICE`).

**Оба варианта одной командой (штатный способ)** — `tools/build_all.ps1`:

```powershell
pwsh -NoProfile -Command "& .\tools\build_all.ps1"
```

Он: (1) при отсутствии `tools/ffmpeg/{ffmpeg,ffprobe}` сам вызывает `fetch_ffmpeg.ps1`;
(2) собирает обычный TPK (`-ReleaseTag beta`); (3) собирает ffmpeg-вариант
(`-ReleaseTag beta-ffmpeg -FFmpegDir tools\ffmpeg`); (4) проверяет, что оба файла созданы.
Опции и детали — в README.

На Linux/macOS — то же одной командой: `bash tools/build_all.sh`
(авто-скачивание ffmpeg — через `tools/fetch_ffmpeg.sh`).

По шагам (то же самое вручную):

```powershell
# 1) один раз скачать бинарники (42 МБ, распакуются в tools\ffmpeg\)
pwsh .\tools\fetch_ffmpeg.ps1

# 2) собрать ffmpeg-вариант (staging-копия дерева создаётся автоматически,
#    исходное FileBrowserQuantumTOS\ не изменяется)
pwsh -NoProfile -Command "& .\tools\build_tpk.ps1 -ReleaseTag 'beta-ffmpeg' -FFmpegDir '.\ffmpeg'"
# → FileBrowserQuantum_TOS7_TOS6_<версия>-beta-ffmpeg-x86_64.tpk
```

Что добавляется в ffmpeg-варианте (только в staging, чистое дерево не трогается):
1. `bin/ffmpeg/ffmpeg` + `bin/ffmpeg/ffprobe` (права 0744).
2. В `bin/filebrowser.yml` секция:
   ```yaml
   integrations:
     media:
       ffmpegPath: /usr/local/FileBrowserQuantum/bin/ffmpeg
   ```
3. В `init.d/service` (staging):
   - `export FILEBROWSER_FFMPEG_PATH=/usr/local/${MOD_NAME}/bin/ffmpeg` после `MOD_NAME=...`
     (env читается до инициализации ffmpeg → работает и при обновлении поверх старого
     конфига, который пакетом не перезаписывается);
   - авто-перезапуск уже работающего демона в `start()` перед `check_already_running`
     → установка/обновление не требуют ручного `service reload`.

Путь `ffmpegPath` = каталог бинарников после установки на NAS (`/usr/local/FileBrowserQuantum/bin/ffmpeg`).
Если секция `integrations:` в исходном `filebrowser.yml` уже существует, скрипт выведет
`WARN` и не будет перезаписывать её автоматически — пропишите `ffmpegPath` вручную.

Возврат с `-ffmpeg` на обычную версию не ломает приложение (без ffmpeg медиа просто
отключается с warning `ffmpeg unavailable`), но бинарники `bin/ffmpeg/` могут остаться
на диске (~160 МБ) — чистить вручную (см. README) или делать чистую переустановку.

Обычный вариант при желании тоже легко собрать с явным путём:
`pwsh -NoProfile -Command "& .\tools\build_tpk.ps1"` (без `-FFmpegDir`).

> Оба варианта одной версии имеют одинаковый `"version"` в `config.ini` (например `2.1.0.0`),
> отличаются только суффиксом в имени файла (`-beta` / `-beta-ffmpeg`). App Center установит
> их параллельно не сможет — версия одна и та же.

---

## Полная пересборка бинарника из исходников

Нужно из папки `sources/` (или свежих исходников с upstream).

### Frontend (Vue3) → embed
```powershell
cd sources\frontend
npm install --no-audit --no-fund
Remove-Item -Recurse -Force ..\backend\internal\web\embed\*   # предварительно очистить
npm run build:docker                                          # vite build → ../backend/internal/web/dist
Copy-Item -Recurse -Force ..\backend\internal\web\dist\* ..\backend\internal\web\embed\
```
> `npm run build` в package.json использует Unix-команды `rm -rf`/`cp -r` (не работают в cmd) —
> поэтому под Windows делаем шаги вручную, как выше. Если `embed/` уже заполнен — frontend
> пересобирать не обязательно, бинарник и так соберётся с встроенным UI.

Проверка, что frontend вшился:

    # embed/ должна быть непустой
    Get-ChildItem sources\backend\internal\web\embed -Recurse | Measure-Object
    Test-Path sources\backend\internal\web\embed\public\index.html

    # бинарник должен содержать UI-строки (после сборки backend)
    $bytes = [System.IO.File]::ReadAllBytes("sources\backend\filebrowserquantum")
    $text  = [System.Text.Encoding]::ASCII.GetString($bytes)
    $text.Contains("<!DOCTYPE html>")   # → True
    $text.Contains("material-symbols")  # → True

### Backend (Go) → linux/amd64 бинарник
Версию для `-ldflags` берите из `FileBrowserQuantumTOS/version` (или `config.ini`) — подставляйте
актуальную, не хардкодьте.
```powershell
cd sources\backend
$env:GOROOT = "E:\go1.27.0"
$env:PATH = "E:\go1.27.0\bin;$env:PATH"
$env:GOTOOLCHAIN = "local"
$env:GOOS = "linux"; $env:GOARCH = "amd64"; $env:CGO_ENABLED = "0"
go build -trimpath -o filebrowserquantum `
  --ldflags="-w -s -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.CommitSHA=n/a' -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=<ВЕРСИЯ>-beta'" .
```

### Замена бинарника и сборка TPK
```powershell
Copy-Item -Force sources\backend\filebrowserquantum `
          FileBrowserQuantumTOS\bin\program\filebrowserquantum
$env:GOROOT = "E:\go1.27.0"
$env:PATH = "E:\go1.27.0\bin;$env:PATH"
$env:GOTOOLCHAIN = "local"
Remove-Item Env:\GOOS, Env:\GOARCH, Env:\CGO_ENABLED -ErrorAction SilentlyContinue
pwsh -NoProfile -Command "& .\tools\build_tpk.ps1"
```
> **ВСЕГДА** после `go build` копировать свежий бинарник в дерево пакета.
> Если этого не сделать, App Center покажет версию из `config.ini`, а приложение —
> старую версию из старого бинарника. Проверка:
>     Get-Item sources\backend\filebrowserquantum, FileBrowserQuantumTOS\bin\program\filebrowserquantum |
>       Select-Object FullName, Length, LastWriteTime
> Размер и дата должны совпадать.
> Проверка версии внутри бинарника:
>     $text = [System.Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes("FileBrowserQuantumTOS\bin\program\filebrowserquantum"))
>     $text.Contains("<новая версия>")   # → True

---

## Обновление версии пакета

При любом обновлении версии нужно синхронно менять **все** места. **Сначала определите
новую версию**, затем обновите её в каждом файле:

| Файл | Что менять |
|---|---|
| `FileBrowserQuantumTOS/version` | само число (простая текстовая строка) |
| `config.ini` | поле `"version"` (главное — определяет имя `.tpk` и версию в App Center) |
| `FileBrowserQuantum.lang` | `version = "..."` в **каждом** языковом блоке (`[en-us]`...`[tr-tr]`) |
| `init.d/service` | `VERSION="..."` |
| `tools/build_tpk.ps1` | путь по умолчанию `..\FileBrowserQuantumTOS` (если папка переименована) |
| `tools/build_tpk.sh` | `PKG_DIR` по умолчанию (то же) |
| `README.md` / `README.en.md` | **не требуют правок версии**: в тексте и именах `.tpk` стоят плейсхолдеры `2.X.X.X` / `2.X.X-beta` (редактировать не нужно). `NOTICE` — проверить при изменении атрибуции/версии |

Совет: при переименовании папки пакета используйте `git mv`, а затем обновите содержимое —
git покажет rename отдельно от правок содержимого (не путать). Имя папки пакета **не обязано**
содержать версию — имена `FileBrowserQuantumTOS/` и `sources/` версии не несут.

---

## Проверка готового `.tpk`

```powershell
# Подставьте фактическое имя файла: FileBrowserQuantum_TOS7_TOS6_<версия>-beta-x86_64.tpk
$b = [IO.File]::ReadAllBytes("$pwd\FileBrowserQuantum_TOS7_TOS6_<ВЕРСИЯ>-beta-x86_64.tpk")
# 1) md5 в JSON-заголовке == md5(payload из байт 10240..end)
$nullIdx = [Array]::IndexOf($b[0..2047], [byte]0)
$hdr = $b[0..2047] | Select-Object -First $nullIdx | ForEach-Object { [char]$_ } | Join-String
$payload = $b[10240..($b.Length-1)]
([Security.Cryptography.MD5]::Create()).ComputeHash($payload) | ... # сравнить с hdr.md5
# 2) Извлечь payload.tar.xz (offset 10240) и tar -tvf — состав/права должны совпадать с деревом
```
Полезные контрольные маркеры собранного бинарника в строковых данных (зависят от версии):
версия-строка, которую подставили в `-ldflags` (есть), старая версия (нет), фичи конкретного
релиза. Ориентировочный размер бинарника (linux/amd64, с `-w -s`): **≈ 44–45 МБ** для 2.0.x.

---

## Свод правил для агента

1. **Использовать Go >= 1.27.0** (`E:\go1.27.0`), `GOTOOLCHAIN=local`, перед любой сборкой Go
   (backend или tarmake) на этой машине. Системный `C:\Program Files\Go` не использовать —
   там смешаны файлы 1.26/1.27, стандартная библиотека повреждена.
2. Не включать папку `sources/` в `.tpk` и в git (она уже в `.gitignore`).
3. **Не хардкодить версию** — всегда брать из `FileBrowserQuantumTOS/version` / `config.ini`,
   и при обновлении менять её во ВСЕХ местах таблицы выше, иначе App Center покажет неверную версию.
4. Перед пересборкой бинарника из исходников — очищать `backend/internal/web/embed/`.
5. `build_tpk.ps1` сам пересчитывает `INFO` и делает всё остальное; вручную `INFO` не править.
6. После сборки проверять: md5 заголовка == md5 payload, версия/платформа в заголовке, состав payload.
7. Штатно собирать **оба** варианта одной командой: на Windows
   `pwsh -NoProfile -Command "& .\tools\build_all.ps1"`, на Linux/macOS —
   `bash tools/build_all.sh` (ffmpeg при необходимости скачается сам). Одиночный
   `-ffmpeg`-вариант — через `-FFmpegDir '.\ffmpeg'` (staging копия дерева, исходное
   `FileBrowserQuantumTOS/` не изменяется); бинарники в `tools/ffmpeg/` не коммитить
   (в `.gitignore`), вся атрибуция ffmpeg — в `NOTICE`. Не хардкодить `ffmpegPath` — он всегда
   `/usr/local/FileBrowserQuantum/bin/ffmpeg` (общий APP_ROOT для этого пакета на TOS).
8. Все `.ps1` в `tools/` хранить в кодировке **UTF-8 с BOM** и без символов
   `—`/`“”`/`‘’` (эм-тире/умные кавычки): под Windows PowerShell 5.1 UTF-8 без BOM
   читается как cp1251 и `—` (байты E2 80 94) превращается в «умную» кавычку `”`,
   ломая парсинг скрипта. BOM заставляет и pwsh, и powershell читать файл как UTF-8.
9. Все `.sh` в `tools/` хранить в **UTF-8 без BOM** и **LF** (без CRLF): bash на Linux/macOS
   и Git Bash не понимают BOM в первой строке `#!/usr/bin/env bash`. Внутри `.sh` не
   использовать ничего Windows-специфичного (пути `E:\`, `xz.exe`): для Linux это Linux,
   для «наших» windows-приёмов есть `.ps1`. `.sh` должны быть исполняемыми
   (`git update-index --chmod=+x tools/*.sh`).