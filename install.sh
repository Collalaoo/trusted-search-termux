#!/usr/bin/env bash
#
# Trusted Search — one-command installer for our (slightly) custom SearXNG.
#
# Supported platforms (auto-detected, then confirmed interactively):
#   1) termux-pkg      vanilla Termux (pkg / apt repositories)
#   2) termux-pacman   Termux with the pacman repository (termux-pacman)
#   3) proxmox         Proxmox VE / Debian-based Linux (apt, optionally systemd)
#
# Usage:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/Collalaoo/trusted-search-termux/main/install.sh)"
#
#   (інший акаунт: GH_OWNER=you bash -c "$(curl -fsSL .../install.sh)"
#   or, if you cloned the repository:
#   bash install.sh
#
# Options:
#   --dry-run                   print the planned actions, change nothing
#   --skip-deps                 skip installing OS packages (deps already present)
#   --force                     re-apply source overlay / regenerate settings
#   --target <termux-pkg|termux-pacman|proxmox>   skip the interactive prompt
#
# Environment overrides:
#   GH_OWNER, GH_REPO, GH_BRANCH   where the assets repository lives
#   TRUSTED_SEARCH_HOME             base directory (default: $HOME)

set -u

# ---------------------------------------------------------------------------
# Repository of the assets (used only when the script is fetched via curl and
# the assets are not already on disk next to it).
# ---------------------------------------------------------------------------
GH_OWNER="${GH_OWNER:-Collalaoo}"
GH_REPO="${GH_REPO:-trusted-search-termux}"
GH_BRANCH="${GH_BRANCH:-main}"
GH_RAW="https://raw.githubusercontent.com/${GH_OWNER}/${GH_REPO}/${GH_BRANCH}"

BASE_HOME="${TRUSTED_SEARCH_HOME:-$HOME}"

SEARXNG_SRC="${SEARXNG_SRC:-$BASE_HOME/searxng-src}"
SEARXNG_VENV="${SEARXNG_VENV:-$BASE_HOME/searxng-pyenv}"
SEARXNG_CONF="${SEARXNG_CONF:-$BASE_HOME/.config/searxng}"
SETTINGS_PATH="$SEARXNG_CONF/settings.yml"
LOG_DIR="${TRUSTED_SEARCH_LOG_DIR:-$BASE_HOME/.logs}"
START_SCRIPT="${TRUSTED_SEARCH_START:-$BASE_HOME/start-searxng.sh}"
STOP_SCRIPT="${TRUSTED_SEARCH_STOP:-$BASE_HOME/stop-searxng.sh}"
SYSTEMD_UNIT="/etc/systemd/system/trusted-searxng.service"

DRY_RUN=0
FORCE=0
SKIP_OS=0
TARGET=""

log()  { printf '\033[1;32m[trusted-search]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[info]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

run() {  # run <cmd...>  (honours --dry-run)
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '\033[2m+ %s\033[0m\n' "$*"
    return 0
  fi
  "$@"
}

for a in "$@"; do
  case "$a" in
    --dry-run)                 DRY_RUN=1 ;;
    --force)                   FORCE=1 ;;
    --skip-deps)               SKIP_OS=1 ;;
    --target=*)                TARGET="${a#--target=}" ;;
    --target)                  die "--target requires a value" ;;
    --help|-h)                 grep -E '^#   ' "$0" | sed 's/^#    //'; exit 0 ;;
    *)                         die "unknown option: $a" ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Platform detection & confirmation (also used by the bootstrap below).
# ---------------------------------------------------------------------------
detect_platform() {
  if [ -d "/data/data/com.termux" ] && [ -n "${PREFIX:-}" ]; then
    if command -v pacman >/dev/null 2>&1; then echo "termux-pacman";
    elif command -v pkg >/dev/null 2>&1; then echo "termux-pkg";
    else echo "termux-pkg"; fi
  elif command -v apt-get >/dev/null 2>&1; then
    echo "proxmox"
  else
    echo "unknown"
  fi
}

# ---------------------------------------------------------------------------
# 0. Bootstrap — if the assets/ folder is not next to this script, make sure
#    the whole repository (install.sh + assets) is on disk and re-run it.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$SCRIPT_DIR/assets/overlay" ]; then
  log "assets not found next to the script — installing git and cloning the repository..."
  case "$(detect_platform)" in
    termux-pkg)     run bash -c 'yes | pkg install -y git curl' ;;
    termux-pacman)  run bash -c 'pacman -S --needed --noconfirm git curl' ;;
    proxmox)        run bash -c 'apt-get update; apt-get install -y git curl' ;;
    *)              die "cannot bootstrap: install git, then either re-run this script or clone the repository and run install.sh from it" ;;
  esac
  BOOTSTRAP_TMP="$(mktemp -d)"
  log "bootstrapping from https://github.com/${GH_OWNER}/${GH_REPO}"
  run git clone --depth 1 --branch "$GH_BRANCH" \
      "https://github.com/${GH_OWNER}/${GH_REPO}.git" "$BOOTSTRAP_TMP/repo" \
      || die "git clone failed for ${GH_OWNER}/${GH_REPO} (is the repository public?)"
  exec bash "$BOOTSTRAP_TMP/repo/install.sh" "$@"
fi
# Redirect to the repository dir so assets resolve consistently.
cd "$SCRIPT_DIR" || die "cannot cd into $SCRIPT_DIR"
SEARXNG_COMMIT="$(cat "$SCRIPT_DIR/dist/SEARXNG_COMMIT" 2>/dev/null || echo 8456831a04e904afdf3057dcdbe9925e8a37377c)"

DETECTED="$(detect_platform)"
PLATFORM="$TARGET"

if [ -z "$PLATFORM" ]; then
  case "$DETECTED" in
    termux-pkg)     LABEL="Termux (пакетний менеджер: pkg/apt)";;
    termux-pacman)  LABEL="Termux (пакетний менеджер: pacman / termux-pacman)";;
    proxmox)        LABEL="Proxmox VE / Debian Linux (apt)";;
    *)              LABEL="unknown (не впізнано)";;
  esac

  if [ -t 0 ] && [ -z "${CI:-}" ]; then
    echo
    echo "=============================================="
    echo " Trusted Search installer"
    echo "=============================================="
    echo "Автовизначено: ${LABEL}"
    echo
    echo "1) termux-pacman   Termux з pacman"
    echo "2) termux-pkg      Vanilla Termux (pkg)"
    echo "3) proxmox         Proxmox VE / Debian Linux"
    echo
    printf 'Це Termux 1-3? [порожньо = %s] ' "$LABEL"
    read -r ans || ans=""
    case "$ans" in
      ""|"0") PLATFORM="$DETECTED" ;;
      1) PLATFORM="termux-pacman" ;;
      2) PLATFORM="termux-pkg" ;;
      3) PLATFORM="proxmox" ;;
      *) die "невірний вибір: $ans" ;;
    esac
  else
    [ "$DETECTED" = "unknown" ] && die "cannot auto-detect the platform; pass --target=termux-pkg|termux-pacman|proxmox"
    PLATFORM="$DETECTED"
  fi
fi

case "$PLATFORM" in
  termux-pkg|termux-pacman|proxmox) ;;
  *) die "unsupported platform: $PLATFORM" ;;
esac
log "platform: $PLATFORM"

# ---------------------------------------------------------------------------
# 2. OS level dependencies.
# ---------------------------------------------------------------------------
install_os_pkgs() {
  case "$PLATFORM" in
    termux-pkg)
      # python already bundles venv/pip; the rest is for pip building wheels
      # (lxml, msgspec, ...) when no binary wheel is available.
      run bash -c 'yes | pkg install -y python git curl binutils clang make pkg-config rust \
                            openssl libxml2 libxslt'
      ;;
    termux-pacman)
      run bash -c 'pacman -Syu --noconfirm'
      run bash -c 'pacman -S --needed --noconfirm python git curl base-devel clang make \
                            pkg-config rust openssl libxml2 libxslt'
      ;;
    proxmox)
      run bash -c 'apt-get update'
      run bash -c 'apt-get install -y git curl ca-certificates \
          python3 python3-venv python3-pip \
          build-essential pkg-config libxml2-dev libxslt1-dev \
          libffi-dev libssl-dev cargo'
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 3. SearXNG source: pinned upstream + custom overlay + advanced theme copy.
# ---------------------------------------------------------------------------
setup_searxng_src() {
  if [ ! -d "$SEARXNG_SRC/.git" ]; then
    log "cloning upstream searxng"
    run git clone https://github.com/searxng/searxng "$SEARXNG_SRC"
  fi

  run git -C "$SEARXNG_SRC" fetch --tags --quiet || run git -C "$SEARXNG_SRC" fetch origin --quiet
  if ! run git -C "$SEARXNG_SRC" checkout --detach "$SEARXNG_COMMIT" 2>/dev/null; then
    run git -C "$SEARXNG_SRC" checkout --detach 8456831a04e904afdf3057dcdbe9925e8a37377c
  fi

  local actual
  actual="$(git -C "$SEARXNG_SRC" rev-parse HEAD)"
  if [ "$actual" != "$SEARXNG_COMMIT" ]; then
    info "warning: searxng HEAD ($actual) != pinned commit ($SEARXNG_COMMIT)"
  fi

  log "applying custom overlay"
  run cp -a "$SCRIPT_DIR/assets/overlay/searx/." "$SEARXNG_SRC/searx/"
  # the 'advanced' theme reuses the 'simple' assets
  run cp -a "$SEARXNG_SRC/searx/static/themes/simple" "$SEARXNG_SRC/searx/static/themes/advanced"
}

# ---------------------------------------------------------------------------
# 4. Python virtual environment (searxng).
# ---------------------------------------------------------------------------
setup_venv() {
  if [ ! -x "$SEARXNG_VENV/bin/python" ]; then
    log "creating virtual environment"
    run python3 -m venv "$SEARXNG_VENV"
  fi
  log "upgrading pip"
  run "$SEARXNG_VENV/bin/python" -m pip install --upgrade pip
  log "installing searxng dependencies (pinned)"
  run "$SEARXNG_VENV/bin/python" -m pip install -r "$SEARXNG_SRC/requirements.txt"
  log "installing searxng in editable mode"
  run "$SEARXNG_VENV/bin/python" -m pip install -e "$SEARXNG_SRC"
}

# ---------------------------------------------------------------------------
# 5. User settings (from template, fresh secret each install).
# ---------------------------------------------------------------------------
setup_settings() {
  run mkdir -p "$SEARXNG_CONF"
  if [ -f "$SETTINGS_PATH" ] && [ "$FORCE" -eq 0 ]; then
    info "settings.yml already exists — keeping it"
    return 0
  fi
  local secret
  secret="$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
  log "writing $SETTINGS_PATH"
  run bash -c "sed 's/__INSTALL_GENERATE_SECRET__/$secret/' '$SCRIPT_DIR/assets/settings.yml.tpl' > '$SETTINGS_PATH'"
}

# ---------------------------------------------------------------------------
# 6. start / stop helpers (Termux-friendly, linux/systemd-friendly).
# ---------------------------------------------------------------------------
write_start_script() {
  run bash -c "cat > '$START_SCRIPT' <<'EOF'
#!/usr/bin/env bash
# Trusted Search — start custom SearXNG on :8888
export SEARXNG_SETTINGS_PATH='$SETTINGS_PATH'
BIN='$SEARXNG_VENV/bin/python'
SRC='$SEARXNG_SRC'
LOG='$LOG_DIR'
mkdir -p \"\$LOG\"
up() { curl -s -o /dev/null -w '%{http_code}' --max-time 3 \"\$1\" 2>/dev/null; }
if [ \"\$(up http://127.0.0.1:8888/)\" != \"200\" ]; then
  cd \"\$SRC\" || exit 1
  setsid \"\$BIN\" -m searx.webapp </dev/null >\"\$LOG/searxng.log\" 2>&1 &
  echo 'SearXNG starting on http://127.0.0.1:8888/'
else
  echo 'SearXNG already running'
fi
EOF"
  run chmod +x "$START_SCRIPT"

  run bash -c "cat > '$STOP_SCRIPT' <<'EOF'
#!/usr/bin/env bash
echo 'Stopping SearXNG (:8888)...'
pkill -f 'searx\\.webapp' 2>/dev/null && echo '  searxng stopped' || echo '  searxng not running'
sleep 1
echo 'Done.'
EOF"
  run chmod +x "$STOP_SCRIPT"
}

setup_systemd() {
  if [ "$PLATFORM" != "proxmox" ]; then return 0; fi
  if ! command -v systemctl >/dev/null 2>&1; then return 0; fi
  run bash -c "cat > '$SYSTEMD_UNIT' <<EOF
[Unit]
Description=Trusted Search custom SearXNG
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$START_SCRIPT
ExecStop=$STOP_SCRIPT

[Install]
WantedBy=multi-user.target
EOF"
  run systemctl daemon-reload
  run systemctl enable trusted-searxng.service
}

# ---------------------------------------------------------------------------
# 7. Start & verify.
# ---------------------------------------------------------------------------
start_and_verify() {
  if [ "$DRY_RUN" -eq 1 ]; then
    info "dry-run finished, nothing was started"
    return 0
  fi
  if [ "$PLATFORM" = "proxmox" ] && command -v systemctl >/dev/null 2>&1; then
    run systemctl restart trusted-searxng.service
  else
    run bash "$START_SCRIPT"
  fi

  echo
  local tries=0
  until curl -s -o /dev/null --max-time 2 http://127.0.0.1:8888/ 2>/dev/null; do
    tries=$((tries+1)); [ "$tries" -ge 40 ] && break; sleep 1
  done
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8888/ 2>/dev/null)"
  echo "------------------------------------------------------------"
  if [ "$code" = "200" ]; then
    echo " Готово! Кастомний SearXNG працює:"
  else
    echo " УВАГА: SearXNG не відповів (http $code). Дивись лог:"
  fi
  echo "   http://127.0.0.1:8888/"
  echo
  echo "   logs:      $LOG_DIR/searxng.log"
  echo "   restart:   bash $START_SCRIPT"
  echo "   stop:      bash $STOP_SCRIPT"
  if [ "$PLATFORM" = "proxmox" ] && command -v systemctl >/dev/null 2>&1; then
    echo "   systemd:   systemctl {start,stop,restart} trusted-searxng"
  fi
  echo "------------------------------------------------------------"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
info "target dirs:"
info "  searxng source  -> $SEARXNG_SRC"
info "  searxng venv    -> $SEARXNG_VENV"
info "  settings        -> $SETTINGS_PATH"
echo

log "I/ install OS packages ($PLATFORM)";       [ "$SKIP_OS" -eq 0 ] && install_os_pkgs || info "skipping OS packages (--skip-deps)"
log "II/ fetch & patch searxng source";         setup_searxng_src
log "III/ create python venv";                   setup_venv
log "IV/ write user settings";                   setup_settings
log "V/ install start/stop helpers";             write_start_script
log "VI/ register systemd (proxmox only)";       setup_systemd
log "VII/ start services";                        start_and_verify

log "all done."