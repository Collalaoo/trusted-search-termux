# Trusted Search Termux / Trusted Search

Приватний, злегка кастомний SearXNG: метапошук без m3e-оболонки, одна команда
розгортає його з нуля на:

| Платформа | Пакетний менеджер |
|---|---|
| Termux (vanilla) | `pkg` / apt |
| Termux + termux-pacman | `pacman` |
| Proxmox VE / Debian Linux | `apt` (+ опційний systemd) |

## Встановлення (з нуля, одна команда)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Collalaoo/trusted-search-termux/main/install.sh)"
```

На початку скрипт **автовизначає** платформу (termux-pacman / termux-pkg /
proxmox) і питає підтвердження. Якщо акаунт інший — `GH_OWNER=you bash -c "$(curl ...)"`.

Локально з клону:

```bash
bash install.sh
```

## Що робить інсталятор

1. Детекція платформи + запит (або `--target=termux-pkg|termux-pacman|proxmox`).
2. Системні залежності (python, git, curl, збірні інструменти — clang/rust або
   build-essential/libxml2-dev, бо lxml/msgspec на Termux збираються з вихідників).
3. Клон офіційного searxng + checkout зафіксованого коміту `dist/SEARXNG_COMMIT`.
4. Кастомний **overlay** (`assets/overlay/searx/`): теми `advanced` і `privau`,
   19 стилів, `ui.advanced_search`, `default_theme: advanced`, автопрогноз,
   Authorised API, фікс дублювання плагінів, фікс подвійного запуску `init()`.
5. Python venv + `requirements.txt` (pinned) + editable-встановлення searxng.
6. `~/.config/searxng/settings.yml` із шаблона (`settings.yml.tpl`, свіжий
   `secret_key` генерується).
7. **AI Overview плагін** (`assets/ai-overview/`, pip у венв) + локальні
   `overview.yml` і `secrets.env` (`$SEARXNG_CONF`).
8. `start-searxng.sh` / `stop-searxng.sh`; на Proxmox — systemd юніт
   `trusted-searxng.service` з автозапуском. Стартовий скрипт автоматично
   експортує `AI_OVERVIEW_CONFIG` і підвантажує `secrets.env`.
9. Запуск і перевірка `http://127.0.0.1:8888/`.

## AI Overview (відповіді з цитатами на запити з «?»)

Вендорений плагін [searxng-ai-overview](https://github.com/jacobabahn/ai-overview-searxng)
(`dist/AI_OVERVIEW_COMMIT` = зафіксований коміт) додає на сторінку пошуку
панель AI-відповіді з джерелами.

1. Після встановлення впиши свої ключі в `~/.config/searxng/secrets.env`
   (Gemini — https://aistudio.google.com/apikey, NVIDIA — https://build.nvidia.com):
   ```bash
   export GEMINI_API_KEY='AQ.Ab...'
   ```
2. Профіль за замовчуванням — **Google Gemini**, модель `gemini-3.5-flash-lite`
   (стрім через `generativelanguage.googleapis.com/v1beta`). Змінюється в
   `~/.config/searxng/overview.yml`; поряд є профілі `nvidia` (NIM) та
   `ollama`. Інші бекенди: `openrouter`, `openai`, `local`, `opencode_go`.
3. Перезапусти: `bash ~/start-searxng.sh` (або `pkill -f 'searx\.webapp'`).
4. Шукай із знаком «?» — під результатами з'явиться AI Overview. Після відповіді
   під панеллю з'являється поле **Ask a follow-up** — можна ставити питання-продовження
   по діалогу (історія зберігається в токені).

> Заувага: NVIDIA Build на частині моделей для нових особистих акаунтів дає
> 404 «Function not found for account» / обриває з'єднання — це
> недоступність моделі для акаунта (потрібен запит у NVIDIA Support), а не
> проблема плагіна.

## Безпека ключів

- Реальні ключі **ніколи не потрапляють у git**. Вони живуть лише в
  `~/.config/searxng/secrets.env` (у репо — лише плейсхолдери
  `assets/secrets.env.default`; `*.gitignore` ігнорує `secrets.env`).
- Інсталятор зберігає вже існуючий `secrets.env` при повторних установках —
  ключі лишаються робочими без повторного введення.
- У репо є пре-коміт гук `tools/check-secrets.sh` (блокує коміти з підозрілими
  довгими послідовностями). Підключи локально: `ln -sfn "$PWD/tools/check-secrets.sh" .git/hooks/pre-commit`.

## Опції

```text
--dry-run                    показати план дій, нічого не міняти
--skip-deps                  не встановлювати системні пакети
--force                      переписати settings.yml / перекласти overlay
--target=termux-pkg|termux-pacman|proxmox   пропустити інтерактивний запит
```

## Структура

| Шлях | Призначення |
|---|---|
| `install.sh` | Універсальний інсталятор (основний шлях) |
| `assets/overlay/searx/` | Кастомні файли searxng (наш «злегка кастомний» шар) |
| `assets/ai-overview/` | Вендорений AI Overview плагін (pip-installable, з патчами: прямий HTTPX-транспорт, сумісність з нашим форком, увімкнений follow-up чат) |
| `assets/overview.yml.default` | Дефолтний конфіг профілів AI Overview (Gemini дефолт, NVIDIA/ollama поряд) |
| `assets/secrets.env.default` | Шаблон для ключів провайдера (не комітити реальні ключі!) |
| `assets/settings.yml.tpl` | Шаблон користувацького конфіга |
| `dist/SEARXNG_COMMIT` | Базовий коміт upstream searxng |
| `dist/AI_OVERVIEW_COMMIT` | Базовий коміт upstream ai-overview-searxng |
| `patches/` | Архів: `searxng-code.patch`, `apply-patches.sh`, `patches/source/*.py`, `add-theme-styles.py` (контент уже увійшов в overlay) |
| `scripts/` | Архів: старий `install-searxng.sh` (termux-pacman), start/stop |
| `settings/` | Приклад змін конфіга |
| `LICENSE` | Apache-2.0 |

## Оновлення overlay після змін у `~/searxng-src`

```bash
SRC=~/searxng-src  REPO=~/trusted-search-termux
cp -a "$SRC/searx/engines/wikidata.py"                                   "$REPO/assets/overlay/searx/engines/"
cp -a "$SRC/searx/plugins/_core.py"                                      "$REPO/assets/overlay/searx/plugins/"
cp -a "$SRC/searx/search"/google_autocomplete_icons.py "$SRC/searx/search"/supplemental_timeout.py "$REPO/assets/overlay/searx/search/"
cp -a "$SRC/searx"/preferences.py "$SRC/searx"/settings.yml "$SRC/searx"/settings_defaults.py "$SRC/searx"/webapp.py "$SRC/searx"/auth.py "$REPO/assets/overlay/searx/"
cp -a "$SRC/searx/static/themes/simple"/sxng-ltr.min.css "$SRC/searx/static/themes/simple"/sxng-rtl.min.css "$REPO/assets/overlay/searx/static/themes/simple/"
cp -a "$SRC/searx/templates/simple"/base.html "$SRC/searx/templates/simple"/preferences.html "$REPO/assets/overlay/searx/templates/simple/"
cp -a "$SRC/searx/templates/simple/preferences"/theme.html "$SRC/searx/templates/simple/preferences"/advanced_search.html "$REPO/assets/overlay/searx/templates/simple/preferences/"
cp -a "$SRC/searx/templates/advanced" "$SRC/searx/templates/privau"      "$REPO/assets/overlay/searx/templates/"
```