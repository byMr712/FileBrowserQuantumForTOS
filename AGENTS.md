# AGENTS.md

Инструкции для ИИ-агентов и разработчиков по сборке/обновлению TPK-пакета
**FileBrowser Quantum** для TerraMaster (TOS6/TOS7).

Репозиторий: `E:\GitHub\FileBrowserQuantumForTOS`

> **Важно:** версия пакета в этой инструкции **не захардкожена** — она определяется
> содержимым дерева пакета (см. _Обновление версии_ ниже). Не подставляйте версию "на глаз",
> всегда берите её из `config.ini` / `version`.
>
> Этот файл отслеживается git и входит в репозиторий (нужен и людям, и ИИ-агентам).

---

## Общая структура репозитория

| Путь | Что это |
|---|---|
| `FileBrowserQuantumTOS/` | **Дерево пакета (payload)** — из него собирается `.tpk`. Единственное, что попадает внутрь `.tpk`. |
| `tools/build_all.ps1` / `build_all.sh` | **Штатная сборка обоих вариантов** (обычный + `-ffmpeg`) одной командой (Windows / Linux-macOS). |
| `tools/build_app.ps1` / `build_app.sh` | **Полная пересборка приложения из `sources/`**: правки апстрима (i18n) → frontend → backend → бинарник в дерево пакета + проверки. |
| `tools/build_tpk.ps1` / `build_tpk.sh` | Сборка **одного** `.tpk` (`-FFmpegDir` / 4-й аргумент — ffmpeg-вариант). |
| `tools/tarmake/` | Go-утилита: GNU-tar с нужными правами (`root:root`, права как в оригинале). |
| `tools/xz/` | Вложенный `xz.exe` + `liblzma-5.dll` + лицензии XZ Utils. |
| `tools/fetch_ffmpeg.ps1` / `.sh` | Скачивание статических `ffmpeg`/`ffprobe` (linux x86_64, John Van Sickle, GPLv3). |
| `tools/ffmpeg/` | Скачанные бинарники ffmpeg/ffprobe. **Игнорируются git.** Нужны только для `-ffmpeg`-варианта. |
| `sources/` | **Upstream-исходники FileBrowser Quantum** (`https://github.com/gtsteffaniak/filebrowser`). Игнорируются git, **в `.tpk` не попадают**. Для сборки `.tpk` не нужны; нужны только для пересборки бинарника. |
| `FileBrowserQuantum_TOS7_TOS6_*.tpk` / `*.zip` | Готовые артефакты (игнорируются git). Два варианта одной версии: `...-beta-x86_64.tpk` и `...-beta-ffmpeg-x86_64.tpk`, к каждому `.tpk` — свой `.zip` (только с этим `.tpk` внутри). |
| `README.md` / `README.en.md` / `NOTICE` | Документация и атрибуция. |
| `AGENTS.md` | Этот файл — инструкции для ИИ-агентов и разработчиков (отслеживается git). |

---

## Двухуровневая модель сборки (ВАЖНО понимать)

1. **Упаковка `.tpk`** — собирается ТОЛЬКО из дерева пакета `FileBrowserQuantumTOS/`
   скриптами `tools/build_all.*` / `build_tpk.*`. **Исходники `sources/`, Go-компилятор и
   Node не нужны.** Бинарник `bin/program/filebrowserquantum` уже готов и просто упаковывается
   (для упаковки нужен только Go — им собирается утилита `tarmake` — и `xz`).

2. **Пересборка бинарника** — если нужно собрать само приложение, нужны исходники
   (frontend Vue3 + backend Go) в `sources/`. Для этого есть `tools/build_app.ps1` / `.sh`
   (рекомендуется) либо ручные шаги. После сборки бинарник кладётся в дерево пакета, и только
   потом собирается `.tpk`.

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

Проверка «здоровья»:

    E:\go1.27.0\bin\go.exe version        # → go1.27.0 windows/amd64

`tools/build_app.ps1` при передаче `-GoRoot E:\go1.27.0` сам выставляет `GOROOT`/`PATH`
на время сборки backend и восстанавливает окружение после.

`tools/build_tpk.ps1` сам пробует системный Go и, если он сломан, **повторяет сборку
tarmake с `E:\go1.27.0`** (ошибки `internal/strconv` в логе — косметика, скрипт завершается 0).
Перед сборкой `.tpk` сбрасывать `GOOS`/`GOARCH`/`CGO_ENABLED` не требуется — скрипт сам их
временно удаляет перед `go run ./tarmake` и восстанавливает после.

---

## Сборка `.tpk` из существующего дерева (быстро)

Штатно — оба варианта одной командой:

```powershell
cd E:\GitHub\FileBrowserQuantumForTOS
pwsh -NoProfile -Command "& .\tools\build_all.ps1"      # → оба .tpk
```

Одиночный вариант (обычный / ffmpeg):

```powershell
pwsh -NoProfile -Command "& .\tools\build_tpk.ps1"                                    # обычный
pwsh -NoProfile -Command "& .\tools\build_tpk.ps1" -ReleaseTag 'beta-ffmpeg' -FFmpegDir '.\ffmpeg'
```

Что делает `build_tpk`:
1. Нормализует текстовые файлы в LF (CRLF ломает shebang на TOS).
2. Пересчитывает `INFO` (md5 каждого файла дерева).
3. Собирает `payload.tar` (GNU tar, root:root, права по таблице) утилитой `tarmake` (Go).
4. Сжимает `xz -9e` → `payload.tar.xz`.
5. Собирает `.tpk`: JSON-заголовок (0..2048) + `.lang` (2048..10240, дополн. до 8192) + payload (10240..end).
6. Имя файла и версия берутся из `config.ini` → `FileBrowserQuantum_TOS7_TOS6_<version>[-tag]-<platform>.tpk`.

Опции: `-PkgDir` (по умолч. `..\FileBrowserQuantumTOS`), `-OutDir`, `-XzPath`, `-ReleaseTag`
(по умолч. `beta`; `''` — стабильный без суффикса), `-FFmpegDir` (каталог с `ffmpeg`/`ffprobe`).

`tools/build_tpk.sh` — то же самое под Linux/macOS. PS- и bash-скрипты дают байт-идентичные `.tpk` (проверено).

**Артефакты:** каждый `.tpk` дублируется своим `.zip` (внутри — только этот `.tpk`), оба кладутся
в корень репозитория и прикрепляются к GitHub Release. И `.tpk`, и `.zip` в `.gitignore`.

---

## Два варианта пакета: без ffmpeg и с ffmpeg (`-ffmpeg`)

По умолчанию собирается **обычный** пакет: превью видео/длительность/субтитры работают,
только если на NAS уже установлены системные `ffmpeg`/`ffprobe` (и прописан
`integrations.media.ffmpegPath` во `filebrowser.yml`).

**`-ffmpeg`-вариант** кладёт статические `ffmpeg`/`ffprobe` прямо в payload — всё заработает
«из коробки», без настройки на NAS. Бинарники берутся из `tools/ffmpeg/`
(`tools/fetch_ffmpeg.ps1`, John Van Sickle static builds, GPLv3, атрибуция в `NOTICE`).

`tools/build_all.ps1` (или `.sh`): (1) при отсутствии `tools/ffmpeg/{ffmpeg,ffprobe}` сам
вызывает `fetch_ffmpeg`; (2) собирает обычный TPK (`-ReleaseTag beta`); (3) собирает
ffmpeg-вариант (`-ReleaseTag beta-ffmpeg -FFmpegDir tools\ffmpeg`); (4) проверяет, что оба файла
созданы.

Что добавляется в ffmpeg-варианте (только в staging-копии, чистое дерево не трогается):
1. `bin/ffmpeg/ffmpeg` + `bin/ffmpeg/ffprobe` (права 0744).
2. В `bin/filebrowser.yml` секция `integrations.media.ffmpegPath: /usr/local/FileBrowserQuantum/bin/ffmpeg`.
3. В `init.d/service`: `export FILEBROWSER_FFMPEG_PATH=/usr/local/${MOD_NAME}/bin/ffmpeg` и
   авто-перезапуск уже работающего демона → обновление не требует ручного `service reload`.

Путь `ffmpegPath` = каталог бинарников после установки на NAS. **Не хардкодить** — он всегда
`/usr/local/FileBrowserQuantum/bin/ffmpeg` (общий APP_ROOT для этого пакета на TOS).

Возврат с `-ffmpeg` на обычную версию не ломает приложение, но бинарники `bin/ffmpeg/` могут
остаться на диске (~160 МБ) — чистить вручную (см. README).

> Оба варианта одной версии имеют одинаковый `"version"` в `config.ini`; отличаются только
> суффиксом в имени файла (`-beta` / `-beta-ffmpeg`).

---

## Полная пересборка бинарника из исходников (РЕКОМЕНДУЕТСЯ)

Исходники берутся из `sources/` (в `.gitignore`; положить туда релиз апстрима самому).

```powershell
# Windows: Go 1.27+ обязателен
pwsh -NoProfile -File .\tools\build_app.ps1 -GoRoot E:\go1.27.0

# Linux / macOS
bash tools/build_app.sh
```

Скрипт делает всё сам:
1. **Применяет правки к исходникам апстрима** (идемпотентно — повторный запуск безопасен).
2. Собирает frontend (Vue3 + Vite) → `sources/backend/internal/web/embed`.
3. Собирает backend (Go, linux/amd64, CGO=0) и копирует бинарник в
   `FileBrowserQuantumTOS/bin/program/filebrowserquantum`.
4. **Проверяет результат** и падает с ошибкой, если что-то не так:
   - в сборке frontend должно быть **>= 20 языковых чанков** (сейчас 25);
   - внутри бинарника должна присутствовать строка версии.

Версия **никогда не хардкодится**: берётся из `FileBrowserQuantumTOS/version`,
версия приложения в бинарнике = `<версия>-beta` (суффикс меняется `-VersionSuffix`).

Опции `build_app.ps1`: `-SourcesDir`, `-PkgDir`, `-VersionSuffix` (по умолч. `beta`),
`-GoRoot`, `-GoToolchain` (`GOTOOLCHAIN`), `-Npm`, `-ForceInstall`, `-SkipFrontend`,
`-SkipBackend`, `-PatchOnly` (только применить правки и выйти).
`build_app.sh` — те же настройки через переменные окружения (`SOURCES_DIR`, `PKG_DIR`,
`VERSION_SUFFIX`, `GO_ROOT`, `GO_TOOLCHAIN`, `NPM`, `FORCE_INSTALL=1`, `SKIP_FRONTEND=1`,
`SKIP_BACKEND=1`, `PATCH_ONLY=1`).

Порядок релиза: `build_app` → `build_all` → zip-ы → проверка (см. ниже).

Сборка **детерминирована**: повторный прогон даёт побайтово идентичные `embed/` и бинарник.
Бинарник linux/amd64 c `-w -s`, 2.1.1: **47 526 048 байт** (для 2.0.x было ≈44–45 МБ).

### Правка i18n (обязательно знать!)

Начиная с апстрима **v2.1.1** frontend собирается **Vite 8 (rolldown)**, а его
`import.meta.glob` **не поддерживает extglob** `!(...)`. Апстрим использует
`import.meta.glob('./!(en).json')` → карта локалей получается **пустой**, языковые чанки не
попадают в бинарник, и интерфейс **всегда английский** (баг воспроизводится у всех, не только TOS).

`build_app` (шаг 1) меняет шаблон на `'./*.json'` в `sources/frontend/src/i18n/index.ts`
и возвращает все 25 языков. Правка идемпотентна и применяется заново после каждого
обновления `sources/`. Если апстрим перепишет этот файл иначе — скрипт упадёт с понятной
ошибкой (не соберёт «английский» бинарник молча).

Признаки сломанной сборки: в интерфейсе только английский; в `embed/assets` нет чанков локалей
(в Vite 8 они называются `virtual_intlify-i18n-<N>-<hash>.js.gz`, в Vite 6 было `<locale>-<hash>.js.gz`);
в бандле `localeModules` вырождается в `Object.assign({})`.

Патч живёт **в `build_app.*`**, а не в `sources/` — потому что `sources/` gitignore-ится и
перезаписывается при обновлении апстрима. Новые правки апстрима добавлять туда же (шаг 1),
идемпотентно, с громкой ошибкой, если ожидаемый текст не найден.

### Ручной вариант (если без скрипта)

```powershell
# 1) Frontend (Vue3) -> embed
cd sources\frontend
npm install --no-audit --no-fund
# ВАЖНО: применить правку i18n (см. выше) — иначе бинарник будет только с английским
Remove-Item -Recurse -Force ..\backend\internal\web\embed\*
npm run build:docker                                          # vite build -> ../backend/internal/web/dist
Copy-Item -Recurse -Force ..\backend\internal\web\dist\* ..\backend\internal\web\embed\

# 2) Backend (Go) -> linux/amd64
cd sources\backend
$env:GOROOT = "E:\go1.27.0"; $env:PATH = "E:\go1.27.0\bin;$env:PATH"; $env:GOTOOLCHAIN = "local"
$env:GOOS = "linux"; $env:GOARCH = "amd64"; $env:CGO_ENABLED = "0"
# <ВЕРСИЯ> взять из FileBrowserQuantumTOS\version
go build -trimpath -o filebrowserquantum `
  --ldflags="-w -s -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=<ВЕРСИЯ>-beta'" .

# 3) Бинарник в дерево пакета
Copy-Item -Force sources\backend\filebrowserquantum FileBrowserQuantumTOS\bin\program\filebrowserquantum

# 4) Пакеты
Remove-Item Env:\GOOS, Env:\GOARCH, Env:\CGO_ENABLED -ErrorAction SilentlyContinue
pwsh -NoProfile -Command "& .\tools\build_all.ps1"
```

> `npm run build` в `package.json` использует Unix-команды `rm -rf`/`cp -r` — под Windows
> берём `npm run build:docker` (чистый `vite build`) и копируем `dist` в `embed` вручную.
>
> **ВСЕГДА** после `go build` копировать свежий бинарник в дерево пакета: иначе App Center
> покажет версию из `config.ini`, а приложение — старую версию из старого бинарника.

---

## Обновление версии пакета

Сначала определить новую версию (upstream `2.1.1` → пакет `2.1.1.0`, приложение `2.1.1.0-beta`),
затем синхронно обновить **все** места:

| Файл | Что менять |
|---|---|
| `FileBrowserQuantumTOS/version` | само число (простая текстовая строка) |
| `config.ini` | поле `"version"` (главное — определяет имя `.tpk` и версию в App Center) |
| `FileBrowserQuantum.lang` | `version = "..."` в **каждом** языковом блоке (`[en-us]`...`[tr-tr]`) |
| `init.d/service` | `VERSION="..."` |
| `README.md` / `README.en.md` | **не требуют правок версии**: стоят плейсхолдеры `2.X.X.X` / `2.X.X-beta`. `NOTICE` — проверить при изменении атрибуции |

`tools/build_app.ps1` / `.sh` версию **не содержат** — читают из `version`, ничего править не надо.
`tools/build_tpk.*` берут дефолтный путь к дереву; менять нужно только при переименовании папки.

---

## Проверка готового `.tpk` (обязательна после сборки)

```powershell
# Подставьте фактическое имя файла
$f = "FileBrowserQuantum_TOS7_TOS6_<ВЕРСИЯ>-beta-x86_64.tpk"
$b = [IO.File]::ReadAllBytes("$pwd\$f")
# 1) md5 в JSON-заголовке (0..2048) == md5(payload из байт 10240..end)
# 2) байты 2048..10240 == FileBrowserQuantum.lang + добивка нулями до 8192
# 3) payload начинается с magic FD 37 7A 58 5A 00 (xz), извлекается, tar -tvf даёт состав/права дерева
```

Чек-лист (всё это уже делалось, повторять каждый релиз):

1. `header.md5 == md5(payload)` для **обоих** вариантов.
2. В заголовке `version`/`platform`/`low_version` — ожидаемые (`2.1.1.0` / `x86_64` / `6.0.420`).
3. Блок `.lang` в `.tpk` совпадает с `FileBrowserQuantumTOS/FileBrowserQuantum.lang` + нули.
4. `tar -tvf`: все `root root`; права: бинарник и `functions/*.sh` и `bin/ffmpeg/*` = 0744,
   `INFO`/`init.d/service` = 0755, каталоги 0755, остальное 0644.
5. Бинарник внутри payload побайтово равен `FileBrowserQuantumTOS/bin/program/filebrowserquantum`.
6. **Все** md5 из `INFO` совпадают с реальными файлами (0 расхождений).
7. ffmpeg-вариант: есть `bin/ffmpeg/{ffmpeg,ffprobe}`, в `bin/filebrowser.yml` есть
   `ffmpegPath`, в `init.d/service` есть `FILEBROWSER_FFMPEG_PATH`.
8. Бинарники в base- и ffmpeg-варианте **идентичны** (различие только в доп. файлах/конфиге).
9. В бинарнике есть строка `<версия>-beta` и **нет** строки предыдущей версии;
   встроенных `.js.gz` ≈ 48 (в т.ч. 25 чанков локалей).
10. Каждый `.zip` содержит ровно один свой `.tpk`.
11. Временные файлы/каталоги (`.zip`-распаковки, `tools\_build\`, копии payload) — удалить.

Полезные контрольные маркеры в строковых данных бинарника: строка версии из `-ldflags` (есть),
старая версия (нет), наличие `<html`/`material-symbols` (UI вшился).

---

## Свод правил для агента

1. **Go >= 1.27.0** (`E:\go1.27.0`), `GOTOOLCHAIN=local`, `C:\Program Files\Go` не использовать
   (там смешаны 1.26/1.27, stdlib повреждена).
2. Не включать `sources/` в `.tpk` и в git (уже в `.gitignore`).
3. **Не хардкодить версию** — брать из `FileBrowserQuantumTOS/version` / `config.ini` и при
   обновлении менять во ВСЕХ местах таблицы выше, иначе App Center покажет неверную версию.
4. Перед пересборкой frontend — очищать `backend/internal/web/embed/`; **не забывать правку i18n**
   (в `build_app.*` она автоматическая + есть проверка языковых чанков; при ручной сборке — применить вручную).
5. `build_tpk`/`build_all` сами пересчитывают `INFO` — вручную не править.
6. После сборки проверять `.tpk` по чек-листу выше.
7. Штатно собирать **оба** варианта одной командой (`build_all.ps1` / `build_all.sh`), к каждому
   `.tpk` делать `.zip`. Бинарники `tools/ffmpeg/` не коммитить; `ffmpegPath` не хардкодить.
8. Все `.ps1` в `tools/` — **UTF-8 с BOM** и без длинных тире/умных кавычек (`—`/`“”`/`‘’`):
   иначе PowerShell 5.1 может неверно декодировать файл. Все `.sh` — **UTF-8 без BOM, LF**,
   исполняемые (`git update-index --chmod=+x tools/*.sh`); внутри `.sh` ничего Windows-специфичного.
9. **Коммиты не делать** без явной просьбы пользователя.
10. Изменения в `sources/` не считать постоянными: они теряются при обновлении апстрима,
    поэтому все правки оформлять в `tools/` (как i18n в `build_app.*`).
