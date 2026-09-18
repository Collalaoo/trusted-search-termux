#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# SearXNG Termux Android Installer (no root, no proot-distro)
# =============================================================================

set -e

GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

log()    { echo -e "${GREEN}[✓] $1${RESET}"; }
warn()   { echo -e "${YELLOW}[!] $1${RESET}"; }
error()  { echo -e "${RED}[✗] $1${RESET}"; exit 1; }
header() { echo -e "\n${GREEN}========================================${RESET}"; echo -e "${GREEN}  $1${RESET}"; echo -e "${GREEN}========================================${RESET}\n"; }

# =============================================================================
# Path configuration; change SEARXNG_BASE to install somewhere else
# Default is $HOME, override by running: SEARXNG_BASE=/your/path bash install-searxng.sh
# =============================================================================
SEARXNG_BASE="${SEARXNG_BASE:-$HOME}"          # Base directory (default: $HOME)
SEARXNG_SRC="${SEARXNG_BASE}/searxng-src"      # Source code
SEARXNG_VENV="${SEARXNG_BASE}/searxng-pyenv"   # Python virtual environment
SEARXNG_CONF="${HOME}/.config/searxng"         # Config (always stays in ~/.config)
SEARXNG_SHORTCUTS="${HOME}/.shortcuts"         # Termux:Widget (must be in ~/.shortcuts)

header "SearXNG Installer"
echo -e "  Installation path:  ${YELLOW}${SEARXNG_BASE}${RESET}"
echo -e "  Source code:        ${YELLOW}${SEARXNG_SRC}${RESET}"
echo -e "  Virtual env:        ${YELLOW}${SEARXNG_VENV}${RESET}"
echo -e "  Configuration:      ${YELLOW}${SEARXNG_CONF}${RESET}"
echo ""

read -r -p "$(echo -e "${YELLOW}Continue? [y/N]: ${RESET}")" CONFIRM
case "$CONFIRM" in
    [yY]) log "Starting installation..." ;;
    *) warn "Aborted."; exit 0 ;;
esac


# =============================================================================
# Step 00: Update Termux packages & install dependencies
# =============================================================================
header "Step 00: Updating Termux & installing dependencies"

pacman -Syu --noconfirm || error "pacman -Syu failed!"
pacman -S --needed --noconfirm git python libxml2 libxslt clang binutils nano curl openssl-tool \
    || error "Package installation failed!"
log "Packages installed successfully."

# =============================================================================
# Step 1:Python version check (min. 3.10)
# =============================================================================
header "Step 1: Checking Python version"

PYTHON_BIN=$(command -v python3 || command -v python || true)
[ -z "$PYTHON_BIN" ] && error "Python not found! Please run 'pacman -S --needed --noconfirm python' first."

PY_VERSION=$("$PYTHON_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MAJOR=$("$PYTHON_BIN" -c "import sys; print(sys.version_info.major)")
PY_MINOR=$("$PYTHON_BIN" -c "import sys; print(sys.version_info.minor)")

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
    error "Python ${PY_VERSION} found — Python 3.10 or higher is required!"
fi

log "Python ${PY_VERSION} found — OK."

# =============================================================================
# Step 2: Remove old files
# =============================================================================
header "Step 2: Removing old SearXNG files"

warn "Removing old installation (if any)..."
rm -rf "${SEARXNG_SRC}" "${SEARXNG_VENV}" "${SEARXNG_CONF}"
log "Cleanup done."



# =============================================================================
# Step 3: Clone SearXNG source code (tested commit)
# =============================================================================
header "Step 3: Cloning SearXNG source code"

mkdir -p "${SEARXNG_BASE}"
git clone "https://github.com/searxng/searxng" "${SEARXNG_SRC}" \
    || error "git clone failed! Please check your internet connection."

cd "${SEARXNG_SRC}"
git checkout 8456831a04e904afdf3057dcdbe9925e8a37377c \
    || error "git checkout failed!"
cd ~
log "SearXNG source ready (tested commit: b5bb27f)."

# =============================================================================
# Step 4: Create & activate Python virtual environment
# =============================================================================
header "Step 4: Creating Python virtual environment"

# Some distro Pythons (notably termux-pacman python 3.14) ship `ensurepip`
# without the bundled pip wheel, so `venv` fails.  In that case patch in the
# missing wheel from PyPI (see CPython zoneinfo/ensurepip docs) and retry.
"$PYTHON_BIN" -m venv "${SEARXNG_VENV}" || {
    warn "Initial venv creation failed; repairing ensurepip bundled wheel..."
    EP="$("$PYTHON_BIN" -c 'import ensurepip, os; print(os.path.join(os.path.dirname(ensurepip.__file__), "_bundled"))')"
    mkdir -p "$EP"
    PIP_VERSION=$("$PYTHON_BIN" -c 'import ensurepip; print(ensurepip._PIP_VERSION)' 2>/dev/null || true)
    [ -n "$PIP_VERSION" ] || PIP_VERSION="26.1.2"
    P_JSON=$(curl -fsSL "https://pypi.org/pypi/pip/${PIP_VERSION}/json") \
        || error "ensurepip repair failed: cannot query PyPI"
    WHL_URL=$("$PYTHON_BIN" -c 'import sys, json; u = [x["url"] for x in json.load(sys.stdin)["urls"] if x["packagetype"] == "bdist_wheel"]; print(u[0])' <<< "$P_JSON")
    curl -fSL -o "$EP/$(basename "$WHL_URL")" "$WHL_URL" || error "ensurepip repair failed: wheel download"
    warn "Retrying venv creation..."
    "$PYTHON_BIN" -m venv "${SEARXNG_VENV}" || error "Failed to create virtual environment!"
}
source "${SEARXNG_VENV}/bin/activate"
log "Virtual environment activated."

# =============================================================================
# Step 5: Install Python build tools & dependencies
# =============================================================================
header "Step 5: Installing Python build tools"

pip install --upgrade pip setuptools wheel pyyaml pybind11 msgspec typing_extensions tzdata \
    || error "pip install (build tools) failed!"
log "Build tools installed."

# =============================================================================
# Step 6: Install SearXNG
# =============================================================================
header "Step 6: Installing SearXNG"

cd "${SEARXNG_SRC}"

# msgspec==0.20.0 cannot be compiled on Android/aarch64 because no prebuilt
# binary is available and the source package has inconsistent metadata.
# We patch the version constraint so pip accepts the already installed 0.21.x.
REQ_FILE="${SEARXNG_SRC}/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    warn "Patching requirements.txt: msgspec==0.20.0 → msgspec>=0.20.0 ..."
    sed -i 's/msgspec==0\.20\.0/msgspec>=0.20.0/' "$REQ_FILE"
    log "requirements.txt patched."
fi

PYPROJECT="${SEARXNG_SRC}/pyproject.toml"
if [ -f "$PYPROJECT" ]; then
    warn "Patching pyproject.toml: msgspec==0.20.0 → msgspec>=0.20.0 ..."
    sed -i 's/msgspec==0\.20\.0/msgspec>=0.20.0/' "$PYPROJECT"
    log "pyproject.toml patched."
fi

pip install --use-pep517 --no-build-isolation -e . \
    || error "SearXNG installation failed! Please retry from step 5."
cd ~
log "SearXNG installed successfully."

# =============================================================================
# Step 7: Create configuration & generate secret key
# =============================================================================
header "Step 7: Configuring SearXNG"

mkdir -p "${SEARXNG_CONF}"
cp "${SEARXNG_SRC}/searx/settings.yml" "${SEARXNG_CONF}/settings.yml" \
    || error "Failed to copy settings.yml!"

# optional botdetection config; empty file silences the "missing limiter.toml" log
: > "${SEARXNG_CONF}/limiter.toml"

python - <<PYEOF
import os, yaml, sys

settings_path = "${SEARXNG_CONF}/settings.yml"
try:
    with open(settings_path, "r") as f:
        settings = yaml.safe_load(f)
    settings["server"]["secret_key"] = os.urandom(24).hex()
    # Tor-only onion engines can't work without a Tor proxy; mark them
    # inactive so startup logs stay clean (re-enable if Tor is configured).
    for engine in settings["engines"]:
        if isinstance(engine, dict) and engine.get("name") in ("ahmia", "torch"):
            engine["inactive"] = True
    with open(settings_path, "w") as f:
        yaml.dump(settings, f, default_flow_style=False, allow_unicode=True)
    print("Secret key generated successfully!")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

log "Configuration created and secret key set."

# =============================================================================
# Step 8: Create Termux:Widget start/stop scripts
# =============================================================================
header "Step 8: Creating Termux:Widget scripts"

if [ ! -d "${SEARXNG_SHORTCUTS}" ]; then
    mkdir -p "${SEARXNG_SHORTCUTS}"
    warn ".shortcuts folder created."
else
    log ".shortcuts folder already exists."
fi

cat > "${SEARXNG_SHORTCUTS}/start-searxng.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash

SEARXNG_VENV="${SEARXNG_VENV}"
SEARXNG_SRC="${SEARXNG_SRC}"
SEARXNG_CONF="${SEARXNG_CONF}"

# Activate wake lock to prevent SearXNG from being killed in the background
termux-wake-lock

# Activate virtual environment
source "\${SEARXNG_VENV}/bin/activate"

sleep 2

cd "\${SEARXNG_SRC}"

export SEARXNG_SETTINGS_PATH="\${SEARXNG_CONF}/settings.yml"

# Start SearXNG in the background
python "\${SEARXNG_SRC}/searx/webapp.py" &

echo -e "\e[32m SearXNG has been started in the background! \e[0m\n"

addr=\$(grep -E "^[[:space:]]*bind_address:" "\${SEARXNG_CONF}/settings.yml" | head -n 1 | awk -F': *' '{print \$2}' | tr -d '"'\'' ')
port=\$(grep -E "^[[:space:]]*port:" "\${SEARXNG_CONF}/settings.yml" | head -n 1 | awk -F': *' '{print \$2}' | tr -d '"'\'' ')

echo -e "\e[32m Address:\e[0m  \$addr"
echo -e "\e[32m Port:   \e[0m \$port"
echo -e "\e[32m URL:    \e[0m http://\$addr:\$port/"

sleep 1
echo -e "\e[32m This window will close in 8 seconds... \e[0m"
sleep 8
exit 0
EOF

cat > "${SEARXNG_SHORTCUTS}/stop-searxng.sh" << EOF
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
EOF

chmod +x "${SEARXNG_SHORTCUTS}/start-searxng.sh" "${SEARXNG_SHORTCUTS}/stop-searxng.sh"
log "Start and stop scripts created and made executable."

# =============================================================================
# Step 9: Deactivate virtual environment
# =============================================================================
deactivate 2>/dev/null || true

# =============================================================================
# Done
# =============================================================================

header "Installation complete!"

echo -e "${GREEN}SearXNG has been installed successfully!${RESET}\n"
echo -e "  Installation path:  ${YELLOW}${SEARXNG_BASE}${RESET}"
echo -e "  Start:              ${YELLOW}${SEARXNG_SHORTCUTS}/start-searxng.sh${RESET}"
echo -e "  Stop:               ${YELLOW}${SEARXNG_SHORTCUTS}/stop-searxng.sh${RESET}"
port=$(grep -E "^[[:space:]]*port:" "${SEARXNG_CONF}/settings.yml" | head -n 1 | awk -F': *' '{print $2}' | tr -d '"'\'' ')
echo -e "  Access:             ${YELLOW}http://localhost:${port}/${RESET}"
echo -e ""
echo -e "  Or manually in the terminal:"
echo -e "    ${YELLOW}termux-wake-lock${RESET}"
echo -e "    ${YELLOW}source ${SEARXNG_VENV}/bin/activate${RESET}"
echo -e "    ${YELLOW}export SEARXNG_SETTINGS_PATH=${SEARXNG_CONF}/settings.yml${RESET}"
echo -e "    ${YELLOW}python ${SEARXNG_SRC}/searx/webapp.py${RESET}"
echo -e ""
echo -e "  Custom install path next time:"
echo -e "    ${YELLOW}cd SearXNG-Termux-Android-noRoot && SEARXNG_BASE=/your/path bash scripts/install-searxng.sh${RESET}"
echo -e ""
echo -e "  Termux:Widget: Refresh the widget to see the scripts."
echo -e "${GREEN}Enjoy your private search engine on Android :) ! ${RESET}\n"
