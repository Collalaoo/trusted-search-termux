#!/data/data/com.termux/files/usr/bin/bash

SEARXNG_VENV="/data/data/com.termux/files/home/searxng-pyenv"
SEARXNG_SRC="/data/data/com.termux/files/home/searxng-src"
SEARXNG_CONF="/data/data/com.termux/files/home/.config/searxng"

# Activate wake lock to prevent SearXNG from being killed in the background
termux-wake-lock

# Activate virtual environment
source "${SEARXNG_VENV}/bin/activate"

sleep 2

cd "${SEARXNG_SRC}"

export SEARXNG_SETTINGS_PATH="${SEARXNG_CONF}/settings.yml"

# Start SearXNG in the background
python "${SEARXNG_SRC}/searx/webapp.py" &

echo -e "\e[32m SearXNG has been started in the background! \e[0m\n"

addr=$(grep -E "^[[:space:]]*bind_address:" "${SEARXNG_CONF}/settings.yml" | head -n 1 | awk -F': *' '{print $2}' | tr -d '"'\'' ')
port=$(grep -E "^[[:space:]]*port:" "${SEARXNG_CONF}/settings.yml" | head -n 1 | awk -F': *' '{print $2}' | tr -d '"'\'' ')

echo -e "\e[32m Address:\e[0m  $addr"
echo -e "\e[32m Port:   \e[0m $port"
echo -e "\e[32m URL:    \e[0m http://$addr:$port/"

sleep 1
echo -e "\e[32m This window will close in 8 seconds... \e[0m"
sleep 8
exit 0
