#!/data/data/com.termux/files/usr/bin/bash

# Stop SearXNG process
pkill -f searx/webapp.py

unset SEARXNG_SETTINGS_PATH

termux-wake-unlock

echo -e '\e[33m SearXNG and wake lock have been stopped! \e[0m'
sleep 1
echo -e '\e[33m This window will close in 2 seconds... \e[0m'
sleep 2
exit 0
