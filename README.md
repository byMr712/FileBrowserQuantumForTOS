# FileBrowser Quantum — TPK-пакет для TerraMaster (TOS6/TOS7)

> **Язык:** Русский · [English](README.en.md)

Готовый пакет **FileBrowser Quantum 2.0.0-beta** для x86_64 NAS TerraMaster (TOS6/TOS7).
В этой папке — дерево пакета, инструменты сборки и всё необходимое для пересборки.

## Авторы

- **Автор оригинального модуля:** [OutkastM](https://tmnascommunity.eu/download/filebrowserquantum/) — TerraMaster Community Place.
- **Кем обновлён до 2.0.0-beta:** [Mr712](https://github.com/byMr712?tab=repositories).
- Пакет собран исключительно из упаковки оригинального модуля **1.2.1-stable** и исходников
  [FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser).
  **Ничего не было вырезано и не добавлено** — обновлено только само приложение FileBrowser
  Quantum до v2.0.0-beta и адаптирована его конфигурация.
  
## Отказ от ответственности

Пакет предоставляется **как есть**, без каких-либо гарантий, явных или подразумеваемых,
включая, но не ограничиваясь, подразумеваемыми гарантиями товарной пригодности, пригодности
для конкретной цели и ненарушения прав.

- Пакет — **бета**-сборка (2.0.0-beta) от участника сообщества и **не является** официальным
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

- Для TOS 6 версии: 6.0.420 или выше.
- Для TOS 7 версии: 7.0.0269 или выше
  
## Обновляетесь с версии v1.x?

Лучше делать чистую установку, но если хотите обновиться:

- **Остановите** старый FileBrowser.
- Сделайте копию **`filebrowser.db`** в безопасное место (желательно вне NAS), но не переносите - файл должен быть в директории, по желанию и файл конфига **`filebrowser.yml`** — но при обновлении не используйте его на версии 2.0.0, структура у них разная!
- Установите и запустите новую версию — она автоматически попытается выполнить миграцию вашей базы.
- После запуска приложения вам может понадобиться добавить в новый конфиг **`filebrowser.yml`** ваши тома (Volume), затем снова выдать эти тома каждому существующему пользователю.

## Содержимое папки

| Путь | Описание |
|---|---|
| `FileBrowserQuantum_TOS7_TOS6_2.0.0.0-beta-x86_64.tpk` | Готовый пакет для установки в App Center |
| `FileBrowserQuantum_2.0.0.0_pkg/` | Дерево пакета (исходники payload): `config.ini`, `.lang`, `INFO`, `version`, `bin/`, `functions/`, `images/`, `init.d/`, `webui.bz2` |
| `tools/build_tpk.ps1` | Скрипт сборки `.tpk` из дерева пакета (все пути — относительные, от папки `tools\`) |
| `tools/tarmake/` | Go-утилита: создаёт GNU-tar с нужными правами (`root:root`, права как в оригинале) |
| `tools/go.work` | Go workspace: позволяет собирать tarmake из папки `tools\` (`go run ./tarmake ...`) |
| `tools/xz/` | Вложенный `xz.exe` + `liblzma-5.dll` + лицензии XZ Utils (COPYING, COPYING.0BSD, COPYING.GPLv2, AUTHORS). Используется, если нет xz в Git for Windows |
| `README.md` | README на русском (по умолчанию) |
| `README.ru.md` | README на английском (выбор пользователя) |
| `LICENSE` | Apache License 2.0 (FileBrowser Quantum) |
| `NOTICE` | Атрибуция и уведомления об изменениях |

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

- **Go 1.26+** (проверено: 1.26.5) — сборка backend и утилиты tarmake. https://go.dev/dl/
- **Node 20+ / npm** — не нужен для сборки скриптом, только для полной пересборки frontend.
- **xz.exe** — вложен в `tools/xz/` (вместе с лицензиями), отдельная установка Git for Windows не нужна.
  Если xz отсутствует, скрипт ищет `C:\Program Files\Git\mingw64\bin\xz.exe`.

## Лицензия xz.exe

XZ Utils — свободное ПО. `xz.exe` (CLI) распространяется под **GNU GPL v2+**, а библиотека
`liblzma-5.dll` — под **0BSD** (public domain). Поэтому рядом с бинарниками лежат файлы лицензий:
`COPYING`, `COPYING.0BSD`, `COPYING.GPLv2` и `AUTHORS`. xz нужен только для сборки и в сам `.tpk`
не попадает. Если будете распространять папку `tools/` дальше — сохраняйте эти файлы.

## Быстрая пересборка .tpk из существующего дерева

Правьте файлы в `FileBrowserQuantum_2.0.0.0_pkg/` (например `bin/filebrowser.yml` — список томов,
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
`FileBrowserQuantum_TOS7_TOS6_2.0.0.0-beta-x86_64.tpk` (id, версия и платформа — из `config.ini`).

Все пути по умолчанию — **относительные, от папки скрипта** `tools\`: дерево пакета
`..\FileBrowserQuantum_2.0.0.0_pkg`, результат `..\FileBrowserQuantum ... .tpk`.
Промежуточные файлы создаются во временной подпапке `tools\_build\` и удаляются после сборки
(в `%TEMP%` ничего не пишется). Запускать можно из любого места.

Опции: `-PkgDir <путь>` (по умолчанию `..\FileBrowserQuantum_2.0.0.0_pkg`),
`-OutDir <куда положить .tpk>` (по умолчанию `..`), `-XzPath <путь к xz.exe>`,
`-ReleaseTag <суффикс версии в имени файла>` (по умолчанию `beta`; для стабильного релиза
`-ReleaseTag ''` → `FileBrowserQuantum_TOS7_TOS6_2.0.0.0-x86_64.tpk`).

## Полная пересборка из исходников filebrowser

Исходники backend/frontend лежат отдельно, например `C:\Users\Mr712\Desktop\filebrowser-2.0.0-beta`.
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
$env:GOOS="linux"; $env:GOARCH="amd64"; $env:CGO_ENABLED="0"
go build -trimpath -o filebrowserquantum --ldflags="-w -s -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.CommitSHA=n/a' -X 'github.com/gtsteffaniak/filebrowser/backend/internal/version.Version=2.0.0-beta'" .

# 3) Заменить бинарник в дереве пакета
Copy-Item backend\filebrowserquantum .\FileBrowserQuantum_2.0.0.0_pkg\bin\program\filebrowserquantum

# 4) Пересобрать TPK
pwsh .\tools\build_tpk.ps1
```

Примечание: `npm run build` в `package.json` вызывает `rm -rf` и `cp -r` (Unix-команды),
поэтому под Windows его заменяют шаги с `Remove-Item` / `Copy-Item` выше.

## Конфигурация приложения

- `bin/filebrowser.yml` — рабочий конфиг v2 (формат FileBrowser Quantum 2.0):
  `http.port: 8087`, `server.sources` (тома), `server.database.path` (SQLite).
  При первом запуске копируется в папку конфига NAS. Логин по умолчанию `admin`, пароль по умолчанию `admin`.
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
$b=[IO.File]::ReadAllBytes("$pwd\FileBrowserQuantum_TOS7_TOS6_2.0.0.0-beta-x86_64.tpk")
# 2. payload извлекается и права/состав совпадают с деревом пакета
tar -xf "$pwd\...tpk" --to-command=... # либо вырезать байты с offset 10240 и tar -tvf
```
