# FileBrowser Quantum — TPK-пакет для TerraMaster (TOS6/TOS7)

> **Язык:** Русский · [English](README.en.md)

<div align="center">

[![Version](https://img.shields.io/badge/Версия-2.X.Xbeta-blue.svg)]()
[![Platform](https://img.shields.io/badge/Платформа-TOS-blue.svg)]()
[![License](https://img.shields.io/badge/Лицензия-Apache%202.0-blue.svg)](LICENSE)

  <img width="150" alt="FileBrowser Quantum logo" src="https://github.com/user-attachments/assets/c40b22c9-33da-47b7-bc4c-ce69bb5cc174">
  <h3>FileBrowser Quantum</h3>
  Лучший бесплатный веб-файловый менеджер для самостоятельного хостинга.
  <br/><br/>
  <img width="800" alt="Список файлов в FileBrowser Quantum в тёмном режиме" src="/images/FileBrowserForTos.png">
</div>

- Готовый пакет **FileBrowser Quantum 2.X.X-beta** для x86_64 NAS TerraMaster (TOS6/TOS7).
- В этом репозитории — релизы, дерево пакета, инструменты сборки и всё необходимое для пересборки.

## Авторы

- **Автор оригинального модуля:** [OutkastM](https://tmnascommunity.eu/download/filebrowserquantum/) — TerraMaster Community Place.
- **Кем обновлён до 2.X.X-beta:** [Mr712](https://github.com/byMr712?tab=repositories).
- Пакет собран исключительно из упаковки оригинального модуля **1.2.1-stable** и исходников
  [FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser).
- **Ничего не было вырезано и не добавлено** — обновлено только само приложение FileBrowser
  Quantum до v2.X.X-beta и адаптирована его конфигурация.
  
## Отказ от ответственности

Пакет предоставляется **как есть**, без каких-либо гарантий, явных или подразумеваемых,
включая, но не ограничиваясь, подразумеваемыми гарантиями товарной пригодности, пригодности
для конкретной цели и ненарушения прав.

- Пакет — **бета**-сборка (2.X.X-beta) от участника сообщества и **не является** официальным
  релизом TerraMaster или FileBrowser.
- Используйте на свой страх и риск. Автор **не несёт ответственности** за потерю данных, сбои
  системы, простой или любые другие последствия установки и использования этого пакета.
- Всегда делайте резервные копии данных и конфигурации NAS перед установкой или обновлением.
- Нет гарантий, что пакет заработает на вашем конкретном оборудовании или версии TOS.
  Поддержка предоставляется только «по возможности».

## Лицензия и атрибуция

- **FileBrowser Quantum** распространяется под **Apache License 2.0**
  (Copyright 2018 File Browser contributors). Полный текст: [`LICENSE`](LICENSE).
- Оригинальный TPK-модуль (упаковка) © OutkastM.
- Уведомления об изменениях и атрибуция: [`NOTICE`](NOTICE).
- Вложенный XZ Utils (`tools/xz/`) — стороннее свободное ПО — GPL-2.0+ (xz CLI) и
  0BSD (liblzma). См. `tools/xz/COPYING*`.
  
## Требования:

- Для TOS 6 версии: 6.0.420 или выше (не надо устанавливать отдельно PHP)
- Для TOS 7 версии: 7.0.0269 или выше (необходимо доустановить PHP 7.4)
  
## Обновляетесь с версии v1.x?

Шаги обновления:

1. **Остановите** старый FileBrowser.
2. Сделайте копию базы **filebrowser.db** и файла конфига **filebrowser.yml** в безопасное место (желательно вне NAS), но оригинальные файлы также должны остаться в директории для успешной автоматической миграции — не переносите их. При обновлении старый конфиг будет сохранён как **filebrowser.yml.legacy**, база данных конвертируется в **filebrowser.sqlite**, а старая база **filebrowser.db** останется на месте, но больше использоваться не будет.
3. Установите и запустите новую версию через магазин приложений — она автоматически попытается выполнить миграцию вашей прошлой базы **.db** в новую **.sqlite**.
4. После запуска приложения вам может понадобиться добавить в новый конфиг **filebrowser.yml** ваши тома (Volume), если вы кроме стандартных **Volume1** и **Volume2** создавали в конфиге другие тома, затем выдать эти нестандартные тома каждому существующему пользователю вновь.
   Если тома были стандартными — ничего делать не надо!

## Поддержка ffmpeg (вариант `-ffmpeg`)

Пакет выпускается в двух вариантах:

- **Обычный** — `FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-x86_64.tpk`. Превью видео,
  длительность и встроенные субтитры работают, только если на NAS уже установлены
  системные `ffmpeg`/`ffprobe` (и в `filebrowser.yml` указан `integrations.media.ffmpegPath`).
- **С ffmpeg** — `FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-ffmpeg-x86_64.tpk`. Внутри
  пакета лежат статические `ffmpeg`/`ffprobe` (`bin/ffmpeg/`, права 0744, статические сборки
  John Van Sickle, GPLv3 — атрибуция в [`NOTICE`](NOTICE)). Превью видео, длительность
  и встроенные субтитры работают сразу после установки, без настройки на NAS.

### Обновление с обычной версии на `-ffmpeg`

`-ffmpeg`-пакет можно ставить **прямо поверх обычной версии** — удалять её не нужно.
Старый конфиг `filebrowser.yml` при обновлении не перезаписывается (это нормально):
в ffmpeg-варианте в `init.d/service` автоматически прописана env-переменная
`FILEBROWSER_FFMPEG_PATH=/usr/local/FileBrowserQuantum/bin/ffmpeg`, которая читается при
старте и не зависит от конфигурационного файла. Кроме того, сервис при установке сам
перезапускает уже работавший демон, поэтому вручную выполнять `init.d/service reload` не нужно.

### Возврат с `-ffmpeg` на обычную версию

Установка обычной версии поверх `-ffmpeg` **не сломает** FileBrowser: без рабочего ffmpeg
медиа-функции просто отключаются (в логе появится предупреждение `ffmpeg unavailable`).
Но встроенные бинарники могут **остаться** на диске (~160 МБ): установщик TOS не всегда
удаляет файлы, которых нет в новом пакете. Чтобы убрать их:

1. Остановите FileBrowser в App Center (или `service stop`).
2. Вручную удалите:
   - `/usr/local/FileBrowserQuantum/bin/ffmpeg/` — бинарники ffmpeg/ffprobe.
3. Запустите FileBrowser заново.

Либо используйте **чистую переустановку**: удалите пакет через App Center и установите заново.

> ⚠️ **Внимание:** при чистой переустановке **удаляются все данные FileBrowser** —
> конфиг `filebrowser.yml`, база `filebrowser.sqlite` (старые версии — `filebrowser.db`),
> настройки и права пользователей. Перед удалением пакета обязательно сделайте резервную
> копию этих файлов в безопасное место (лучше вне NAS) и действуйте осторожно.

## Содержимое папки

| Путь | Описание |
|---|---|
| `FileBrowserQuantumTOS/` | Дерево пакета (payload): `config.ini`, `.lang`, `INFO`, `version`, `bin/`, `functions/`, `images/`, `init.d/`, `webui.bz2` |
| `tools/build_all.ps1` | Одной командой собирает **оба** TPK — обычный и с ffmpeg (при необходимости сам скачивает ffmpeg) |
| `tools/build_all.sh` | То же для Linux / macOS (Bash): `bash tools/build_all.sh`; скачивание ffmpeg автоматически |
| `tools/build_tpk.ps1` | Сборка одного `.tpk` на Windows PowerShell (`-FFmpegDir` — ffmpeg-вариант) |
| `tools/build_tpk.sh` | Сборка `.tpk` на Linux / macOS (Bash); 4-й аргумент или `FFMPEG_DIR` — ffmpeg-вариант |
| `tools/tarmake/` | Go-утилита: создаёт GNU-tar с нужными правами (`root:root`, права как в оригинале) |
| `tools/go.work` | Go workspace: позволяет собирать tarmake из папки `tools\` (`go run ./tarmake ...`) |
| `tools/xz/` | Вложенный `xz.exe` + `liblzma-5.dll` + лицензии XZ Utils (COPYING, COPYING.0BSD, COPYING.GPLv2, AUTHORS). Используется, если нет xz в Git for Windows |
| `tools/fetch_ffmpeg.ps1` | Автоматическое скачивание статических ffmpeg/ffprobe (linux x86_64) в `tools/ffmpeg/` для сборки `-ffmpeg`-варианта |
| `tools/fetch_ffmpeg.sh` | То же для Linux / macOS (curl или wget) |
| `README.md` | README на русском (по умолчанию) |
| `README.en.md` | README на английском (выбор пользователя) |
| `images/` | Скриншоты для README |
| `LICENSE` | Apache License 2.0 (FileBrowser Quantum) |
| `NOTICE` | Атрибуция и уведомления об изменениях |
| `.gitignore` / `.gitattributes` | Исключения git |

## Структура .tpk

```
[0..2048)      JSON-заголовок; поле "md5" = md5(payload.tar.xz), дополнен нулями
[2048..10240)  содержимое FileBrowserQuantum.lang, дополнено нулями до 8192
[10240..конец) payload.tar.xz (magic FD 37 7A 58 5A 00)
```

Ключевые факты формата (подтверждены разбором оригинального пакета 1.2.1.0):
- md5 в JSON-заголовке — это md5 **всего** payload.tar.xz (не самого tar).
- Payload — tar в формате **GNU** (`ustar `), owner/group `root:root`.
- `INFO` — список `1:file:<путь>:<md5>` / `1:folder:<путь>:`, md5 = md5 содержимого файла.
- `config.ini` присутствует в payload, но **не** перечисляется в `INFO`.

## Что требуется для сборки

- **Go 1.27+** (проверено: 1.27.0) — сборка backend и утилиты tarmake. https://go.dev/dl/
  Если в системе несколько Go и один из них сломан — скрипты перебирают найденные и
  используют первый, который реально собирает tarmake; переопределить явно можно через
  `GO_127_ROOT=<каталог с bin/go>`.
- **Node 20+ / npm** — не нужен для сборки скриптом, только для полной пересборки frontend.
- **Windows:** `xz.exe` вложен в `tools/xz/` (вместе с лицензиями), отдельная установка Git for Windows не нужна.
  Если xz отсутствует, PowerShell-скрипт ищет `C:\Program Files\Git\mingw64\bin\xz.exe`.
- **Linux / macOS:** нужен `xz` из системы (`apt install xz-utils` / `brew install xz`) и `curl` или `wget`
  для авто-скачивания ffmpeg.

## Лицензия xz.exe

XZ Utils — свободное ПО. `xz.exe` (CLI) распространяется под **GNU GPL v2+**, а библиотека
`liblzma-5.dll` — под **0BSD** (public domain). Поэтому рядом с бинарниками лежат файлы лицензий:
`COPYING`, `COPYING.0BSD`, `COPYING.GPLv2` и `AUTHORS`. xz нужен только для сборки и в сам `.tpk`
не попадает. Если будете распространять папку `tools/` дальше — сохраняйте эти файлы.

## Быстрая пересборка .tpk из существующего дерева

Правьте файлы в `FileBrowserQuantumTOS/` (например `bin/filebrowser.yml` — список томов,
`version` — версия пакета, `config.ini` и `.lang` — название/версия в App Center), затем:

```powershell
pwsh .\tools\build_tpk.ps1
```

Скрипт сам:
1. пересчитает `INFO` (md5 всех файлов дерева);
2. соберёт `payload.tar` (tarmake, права root:root);
3. сожмёт `xz -9e` → `payload.tar.xz`;
4. соберёт `.tpk` (заголовок + .lang + payload) в родительскую папку;
5. имя файла и версия в заголовке берутся из `config.ini`.

Имя результата — `<id>_TOS7_TOS6_<версия>[-<суффикс>]-<платформа>.tpk`, например
`FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-x86_64.tpk` (id, версия и платформа — из `config.ini`).

Все пути по умолчанию — **относительные, от папки скрипта** `tools\`: дерево пакета
`..\FileBrowserQuantumTOS`, результат `..\FileBrowserQuantum ... .tpk`.
Промежуточные файлы создаются во временной подпапке `tools\_build\` и удаляются после сборки
(в `%TEMP%` ничего не пишется). Запускать можно из любого места.

Опции: `-PkgDir <путь>` (по умолчанию `..\FileBrowserQuantumTOS`),
`-OutDir <куда положить .tpk>` (по умолчанию `..`), `-XzPath <путь к xz.exe>`,
`-ReleaseTag <суффикс версии в имени файла>` (по умолчанию `beta`; для стабильного релиза
`-ReleaseTag ''` → `FileBrowserQuantum_TOS7_TOS6_2.X.X.X-x86_64.tpk`).

### Сборка обоих вариантов одной командой (рекомендуется)

Обычный пакет и пакет с ffmpeg собираются одним вызовом — статические
ffmpeg/ffprobe при необходимости скачаются автоматически (один раз, в `tools/ffmpeg/`):

```powershell
# Windows
pwsh -NoProfile -Command "& .\tools\build_all.ps1"
```

```bash
# Linux / macOS
bash tools/build_all.sh
```

Результат (имена и версия берутся из `config.ini`):

```
FileBrowserQuantum_TOS7_TOS6_<версия>-beta-x86_64.tpk
FileBrowserQuantum_TOS7_TOS6_<версия>-beta-ffmpeg-x86_64.tpk
```

Опции PowerShell: `-BaseReleaseTag` / `-FFmpegReleaseTag` (суффиксы имён файлов; по умолчанию
`beta` / `beta-ffmpeg`), `-FFmpegDir <путь>` (свои бинарники ffmpeg, без автозагрузки),
`-KeepGoing` (собрать второй вариант, даже если первый упал),
`-SkipFfmpegFetch` (не качать — только уже скачанные бинарники).

То же через переменные окружения в `build_all.sh`:
`BASE_RELEASE_TAG` / `FFMPEG_RELEASE_TAG`, `FFMPEG_DIR=<путь>`, `KEEP_GOING=1`,
`SKIP_FFMPEG_FETCH=1`, `PKG_DIR=<путь>`, `OUT_DIR=<путь>`.

### Сборка с поддержкой ffmpeg (превью видео, длительность, встроенные субтитры)

```powershell
# 1) Скачать статические ffmpeg/ffprobe (linux x86_64) в tools\ffmpeg\
pwsh .\tools\fetch_ffmpeg.ps1

# 2) Собрать .tpk с ffmpeg: staging-дерево создаётся автоматически,
#    исходное FileBrowserQuantumTOS\ не изменяется
pwsh .\tools\build_tpk.ps1 -ReleaseTag 'beta-ffmpeg' -FFmpegDir '.\ffmpeg'
# → FileBrowserQuantum_TOS7_TOS6_<версия>-beta-ffmpeg-x86_64.tpk
```

На Linux / macOS то же самое:

```bash
# 1) Скачать ffmpeg/ffprobe
bash tools/fetch_ffmpeg.sh

# 2) Собрать ffmpeg-вариант (staging-копия, исходное дерево не меняется)
bash tools/build_tpk.sh ../FileBrowserQuantumTOS .. beta-ffmpeg tools/ffmpeg
# → FileBrowserQuantum_TOS7_TOS6_<версия>-beta-ffmpeg-x86_64.tpk
```

В ffmpeg-варианте в payload добавляются `bin/ffmpeg/{ffmpeg,ffprobe}` (права 0744),
а в `bin/filebrowser.yml` прописывается `integrations.media.ffmpegPath`. Дополнительно
патчится `init.d/service` (только в staging-копии): добавляется
`export FILEBROWSER_FFMPEG_PATH=/usr/local/FileBrowserQuantum/bin/ffmpeg` и авто-перезапуск
уже работавшего демона при старте — превью заведутся и при обновлении поверх старого
конфига, без ручного `service reload`. Бинарники — статические сборки John Van Sickle
(GPLv3), детали см. в `NOTICE`.

## Полная пересборка из исходников filebrowser

Исходники backend/frontend лежат отдельно, например в папке `sources/`.
Порядок:

```powershell
# 1) Frontend (Vue3) -> backend/internal/web/embed
cd <src>\frontend
npm install --no-audit --no-fund
Remove-Item -Recurse -Force ..\backend\internal\web\embed\*   # npm-скрипт "build" использует rm -rf (не работает в cmd)
npm run build:docker                                          # vite build -> ../backend/internal/web/dist
Copy-Item -Recurse -Force ..\backend\internal\web\dist\* ..\backend\internal\web\embed\

# 2) Backend (Go) -> linux/amd64 бинарник (без тега mupdf, CGO не нужен)
cd <src>\backend
$env:GOTOOLCHAIN="go1.27.0"
$env:GOOS="linux"; $env:GOARCH="amd64"; $env:CGO_ENABLED="0"
go build -trimpath -o filebrowserquantum --ldflags="-w -s -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.CommitSHA=n/a' -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=2.X.X-beta'" .

# 3) Заменить бинарник в дереве пакета
Copy-Item backend\filebrowserquantum .\FileBrowserQuantumTOS\bin\program\filebrowserquantum

# 4) Пересобрать TPK
pwsh .\tools\build_tpk.ps1
```

Примечание: `npm run build` в `package.json` вызывает `rm -rf` и `cp -r` (Unix-команды),
поэтому под Windows его заменяют шаги с `Remove-Item` / `Copy-Item` выше.

## Конфигурация приложения

- `bin/filebrowser.yml` — рабочий конфиг v2 (формат FileBrowser Quantum 2.0):
  `http.port: 8087`, `server.sources` (тома), `server.database.path` (SQLite).
  При первом запуске копируется в папку конфига NAS.
  Логин по умолчанию — всегда `admin`. Пароль зависит от версии FileBrowser Quantum:
    - **пакеты до 2.0.8 включительно** (в т.ч. все 1.x) — при чистой установке пароль `admin`;
    - **пакеты 2.0.9+** (текущий 2.1.0.1) — на чистой установке пароль `admin` больше не действует:
      при первом старте без базы генерируется случайный пароль администратора (12 hex-символов)
      и **один раз** печатается в лог запуска `/usr/local/FileBrowserQuantum/FileBrowserQuantum_start.log`,
      строка вида `Generated initial admin password for user "admin" (…): …`. Войдите с ним и смените пароль.
    - Пароль хранится в базе SQLite: обновление поверх прежней установки (база уже есть)
      логин/пароль **не меняет**; после сброса приложения (`service reset`, база удаляется)
      генерируется новый пароль.
    - Чтобы задать (или восстановить забытый) известный пароль — пропишите в рабочем конфиге на NAS: `auth.methods.password.adminPassword: <пароль>`
      (значение **не пустое и не `admin`**). Это работает в любой момент — и на чистой установке, и позже:
      пароль применяется при каждом старте демона. Убирать строку не обязательно (по желанию): пока она
      в конфиге, пароль всегда будет таким; чтобы сменить пароль через интерфейс — удалите её из конфига.
- `bin/filebrowser.migrate.yml` — конфиг для апгрейда со старой версии 1.2.1:
  добавляет `server.database.migrateFrom` на старый BoltDB `filebrowser.db`,
  FileBrowser автоматически мигрирует пользователей/шары/правила в SQLite.
- `init.d/service` при старте: если найден старый конфиг v1 (строка `database: /путь`),
  сохраняет его как `filebrowser.yml.legacy` и ставит новый; если есть старый `filebrowser.db`
  и нет нового SQLite — ставит миграционный конфиг.
- `webui.bz2` — PHP-интерфейс «Support & Help» TOS, не зависит от версии, менять не нужно.

## Права файлов в payload (как в оригинале)

| Файл | Права |
|---|---|
| `INFO`, `init.d/service` | 0755 |
| `bin/program/filebrowserquantum`, `functions/dependapps.sh` | 0744 |
| каталоги | 0755 |
| остальные файлы | 0644 |

Все файлы принадлежат `root:root`.

## Проверка результата

```powershell
# 1. md5 в заголовке должен совпадать с md5 payload
$b=[IO.File]::ReadAllBytes("$pwd\FileBrowserQuantum_TOS7_TOS6_2.X.X.X-beta-x86_64.tpk")
# 2. payload извлекается и права/состав совпадают с деревом пакета
tar -xf "$pwd\...tpk" --to-command=... # либо вырезать байты с offset 10240 и tar -tvf
```
