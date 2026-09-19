#!/usr/bin/env bash
# Apply the PrivAU feature patches (themes, rich autocomplete, supplemental
# timeout, authorised API) to a SearXNG checkout.
#
# Usage:
#   SEARXNG_SRC=/path/to/searxng-src bash patches/apply-patches.sh
#   (default SEARXNG_SRC=$HOME/searxng-src)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SEARXNG_SRC="${SEARXNG_SRC:-$HOME/searxng-src}"

if [ ! -d "${SEARXNG_SRC}/.git" ]; then
    echo "[x] SearXNG checkout not found: ${SEARXNG_SRC}" >&2
    echo "    Clone it first: git clone https://github.com/searxng/searxng && git checkout 8456831a04e904afdf3057dcdbe9925e8a37377c" >&2
    exit 1
fi

echo "[ ] Applying patches to: ${SEARXNG_SRC}"

mkdir -p "${SEARXNG_SRC}/searx/search"

cp "${REPO_DIR}/patches/source/supplemental_timeout.py"       "${SEARXNG_SRC}/searx/search/"
cp "${REPO_DIR}/patches/source/google_autocomplete_icons.py"   "${SEARXNG_SRC}/searx/search/"
cp "${REPO_DIR}/patches/source/auth.py"                        "${SEARXNG_SRC}/searx/auth.py"
echo "[x] New modules copied to searx/search/ and searx/auth.py"

cd "${SEARXNG_SRC}"
if git apply --check "${REPO_DIR}/patches/searxng-code.patch" 2>/dev/null; then
    git apply "${REPO_DIR}/patches/searxng-code.patch"
    echo "[x] searxng-code.patch applied"
else
    echo "[!] Code patch did NOT apply cleanly (tree differs from 8456831a0)." >&2
    echo "    Fix manually using the 'Що в патчі' section of the README." >&2
    exit 1
fi

cat <<'MSG'

Done. Recommended follow-up:
  1. optional 'privau' theme (separate selectable theme, standard 'simple'
     stays the default):
       cp -r <privau-searxng>/out/*              searx/static/themes/privau/
       cp -r searx/templates/simple              searx/templates/privau/
     ('privau' then appears in Preferences -> Theme)
  2. settings: search.autocomplete = google, search.autocomplete_min = 0
     (in ~/.config/searxng/settings.yml, else default searx/settings.yml)
  3. restart:  bash ~/.shortcuts/stop-searxng.sh && bash ~/.shortcuts/start-searxng.sh
MSG