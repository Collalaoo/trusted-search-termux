# Tused Search Termux

Private SearXNG meta-instance on Android/Termux (termux-pacman, no root).
Бандл скриптів і патчів, зібраних і перевірених на реальному пристрої:

- інсталятор на базі `pacman` (термінальний termux-pacman bootstrap, без `pkg`);
- готові патчі фіч із [privau/searxng](https://github.com/privau/searxng):
  19 тем, «багатий» автопрогноз запиту, ранні таймаути, опційний Authorised API;
- приклади налаштувань.

## Вміст

| Шлях | Призначення |
|---|---|
| `scripts/install-searxng.sh` | Інсталятор SearXNG (termux-pacman), зафіксований на перевіреному коміті `8456831a0` |
| `scripts/start-searxng.sh` | Запуск через Termux:Widget / вручну |
| `scripts/stop-searxng.sh` | Зупинка + `termux-wake-unlock` |
| `patches/searxng-code.patch` | Патч коду SearXNG (теми, автопрогноз, hook webapp) |
| `patches/source/` | Нові модулі: `supplemental_timeout.py`, `google_autocomplete_icons.py`, `auth.py` |
| `patches/apply-patches.sh` | Застосування `patches/source/` + `searxng-code.patch` |
| `settings/searxng-settings.example.yml` | Приклад змін у живому конфігу `~/.config/searxng/settings.yml` |

## Швидкий старт

Потрібен термінальний **termux-pacman** (див. termux-pacman репо). Всередині Termux:

```bash
pacman -Syu --noconfirm
bash scripts/install-searxng.sh
```

Скрипт створює `~/searxng-src`, venv `~/searxng-pyenv`, конфіг
`~/.config/searxng/settings.yml` та start/stop-скрипти в `~/.shortcuts`.

Після інсталяції — застосувати фічі:

```bash
SEARXNG_SRC=~/searxng-src bash patches/apply-patches.sh
```

Патч розрахований на коміт `8456831a0` (`git apply`). На іншому коміті
`searxng/searxng` може не лягти — тоді внось правки вручну (див. нижче).

## Теми (статичні збірки)

Патч коду додає імена тем у селектор, але самі CSS/JS-збірки тем
беруться з форка (компільований `out/`). Щоб темний UI реально
відображався, скопіюй статику форка в дерево SearXNG:

```bash
cd ~/searxng-src/searx/static/themes
cp -r simple simple.org                    # резервна копія
cp -r ~/privau-searxng/out/* simple/
```

## Що в патчі

- **Теми**: списки вибору розширено в `searx/preferences.py`,
  `searx/settings_defaults.py`, `searx/templates/simple/preferences/theme.html`.
  Доступні додаткові теми: `brave, dark, dracula, everforest, evergarden,
  frappe, gruvbox, gruvboxmat, kagi, latte, light, macchiato, matcha, moa,
  mocha, night, nord, paulgo`.
- **Автопрогноз**: `autocomplete: google`, `autocomplete_min: 0`;
  модуль `google_autocomplete_icons.py` повертає підказки з іконками/
  описами/трендами.
- **Supplemental timeout**: `supplemental_timeout.py` — ранній таймаут
  для wikipedia/wikidata/ddg.
- **Authorised API**: `auth.py` — запити лише за ключем з rate-limit;
  активується змінною `AUTHORISED_API` (інакше no-op).
- **Hook**: у `searx/webapp.py` (після `init()`) усі патчі застосовуються
  автоматично.

## Налаштування для запуску з LAN

```yaml
server:
  bind_address: 0.0.0.0   # якщо хочеш заходити з інших пристроїв
  port: 8888
search:
  autocomplete: google
  autocomplete_min: 0
```

IP пристрою: `ip -4 addr show wlan0`. Перезапуск:
`bash ~/.shortcuts/stop-searxng.sh && bash ~/.shortcuts/start-searxng.sh`.

## Ліцензії

- Власний вміст репо (скрипти адаптації, README, приклади) — **Apache-2.0**.
- `patches/source/*.py` — похідні від [privau/searxng](https://github.com/privau/searxng)
  → **AGPL-3.0-or-later** (SPDX-заголовки збережено у файлах).
- `scripts/install-searxng.sh` адаптовано з
  [SearXNG-Termux-Android-noRoot](https://github.com/misterphantom/SearXNG-Termux-Android-noRoot).

Цей репозиторій не пов'язаний безпосередньо з SearXNG та SearXNG-Termux.