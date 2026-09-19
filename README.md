# Trusted Search Termux

Private SearXNG meta-instance on Android/Termux (termux-pacman, no root).
Бандл скриптів і патчів, зібраних і перевірених на реальному пристрої:

- інсталятор на базі `pacman` (термінальний termux-pacman bootstrap, без `pkg`);
- готові патчі фіч із [privau/searxng](https://github.com/privau/searxng):
  19 тем (стилі), «багатий» автопрогноз запиту, ранні таймаути, опційний
  Authorised API, а також макет форка як окрема тема `privau`;
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
| `patches/add-theme-styles.py` | Додає решта 17 стилів у стандартну тему `simple` (з CSS теми `privau`) |
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

## Теми: стандартна `simple` + окрема `privau`

Стандартна тема SearXNG `simple` лишається за замовчуванням. Збірки форка
(компільований `out/`) оформлені як **окрема тема `privau`**, яку можна
вибрати в `Preferences → Theme` (вибір зберігається в cookie браузера):

```bash
cd ~/searxng-src/searx
cp -r ~/privau-searxng/out/* static/themes/privau/
cp -r templates/simple templates/privau/
```

Між темами можна перемикатися на льоту: Vite-збірка форка резолвить чанки
відносно свого скрипта (`import.meta.url`), тому `themes/privau/` працює
незалежно від `simple`. У `searx/webapp.py` значення `theme_static_path`
у клієнтських налаштуваннях тепер формується від поточної теми, а не
жорстко `themes/simple`.

Усі 20 стилів (`auto, light, dark, black, paulgo, latte, frappe, macchiato,
mocha, kagi, brave, moa, night, dracula, gruvbox, gruvboxmat, everforest,
evergarden, nord, matcha`) доступні для **обох** макетів. Стандартний
`simple` у upstream містить лише `auto/dark/black` — решту блоків
(`:root.theme-*` + стрілки `<select>`) дошиває скрипт
`python3 patches/add-theme-styles.py` з компільованого CSS теми `privau`
(спільна розмітка та спільні `--color-*` змінні, тому перенос чистий).

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

## Відомі зауваження

- **`tzdata`**: інсталятор ставить пакет `tzdata` у venv. Він потрібен, коли
  системна база IANA-часових поясів недоступна для Python (`zoneinfo`) — інакше
  движок `bilibili` не зареєструється (`ZoneInfoNotFoundError`).
  (CPython docs про fallback на `tzdata`: https://docs.python.org/3/library/zoneinfo.html#data-sources)
- **`ahmia` та `torch`** — движки Tor-мережі (категорія `onions`). Без
  Tor-проксі они не працюють і логують помилку при старті; інсталятор позначає
  їх `inactive` у згенерованому `~/.config/searxng/settings.yml`
  (`is_engine_active` у `searx/engines/__init__.py`). Поверни `inactive: false`,
  якщо налаштуєш Tor.
- **`limiter.toml`**: опційний файл botdetection-конфігу; установка створює
  порожній `~/.config/searxng/limiter.toml`, щоб не було попередження в логах.
- **`wikidata` engine**: edge query.wikidata.org повертає `403` для
  User-Agent, що містить `SearXNG`. У `searx/engines/wikidata.py` заголовок
  змінено на браузерний `gen_useragent()` — так само, як у поточному
  searxng master (`searx/wikidata.py`, див. User_Manual#Query_limits). Без
  цього движок не проходить INIT: `HTTP error 403 (suspended_time=180)`.

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