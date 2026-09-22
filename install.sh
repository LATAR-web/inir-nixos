#!/usr/bin/env bash
#
# Automated installer for LATAR-web/inir-nixos
# https://github.com/LATAR-web/inir-nixos
#
# Usage:
#   ./install.sh              interactive (asks before each risky step)
#   ./install.sh --yes        non-interactive, assumes yes to everything
#   ./install.sh --dry-run    print what would happen, touch nothing
#   ./install.sh --skip-rebuild   do everything except nixos-rebuild
#   ./install.sh --help
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/inir-nixos-install-${TIMESTAMP}.log"

# --- flags ---
ASSUME_YES=0
DRY_RUN=0
SKIP_REBUILD=0

for arg in "$@"; do
    case "$arg" in
        --yes|-y)      ASSUME_YES=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --skip-rebuild) SKIP_REBUILD=1 ;;
        --help|-h)
            grep '^#' "${BASH_SOURCE[0]}" | sed '1d;s/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown flag: $arg (see --help)"; exit 1 ;;
    esac
done

# --- colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
    C_RESET=''; C_BOLD=''; C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''
fi

log()   { echo "$1" >> "$LOG_FILE"; }
info()  { echo "${C_BLUE}→${C_RESET} $1"; log "INFO: $1"; }
ok()    { echo "  ${C_GREEN}✅${C_RESET} $1"; log "OK: $1"; }
warn()  { echo "  ${C_YELLOW}⚠️${C_RESET}  $1"; log "WARN: $1"; }
fail()  { echo "  ${C_RED}❌${C_RESET} $1"; log "FAIL: $1"; }
step()  { echo; echo "${C_BOLD}$1${C_RESET}"; log "STEP: $1"; }

run() {
    # run "description" cmd args...
    local desc="$1"; shift
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  ${C_YELLOW}[dry-run]${C_RESET} $desc: $*"
        return 0
    fi
    log "RUN: $*"
    if "$@" >> "$LOG_FILE" 2>&1; then
        ok "$desc"
    else
        fail "$desc (see $LOG_FILE)"
        exit 1
    fi
}

confirm() {
    local prompt="$1"
    [[ $ASSUME_YES -eq 1 ]] && return 0
    read -rp "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "  ${C_YELLOW}[dry-run]${C_RESET} would back up $target"
        else
            cp -a "$target" "$target.bak.$TIMESTAMP"
            warn "backed up existing $target → $target.bak.$TIMESTAMP"
        fi
    fi
}

trap 'echo; fail "Install aborted (line $LINENO). Full log: $LOG_FILE"; exit 1' ERR

echo "${C_BOLD}═══════════════════════════════════════════"
echo "  iNiR + niri + NixOS — automated installer"
echo "═══════════════════════════════════════════${C_RESET}"
[[ $DRY_RUN -eq 1 ]] && echo "${C_YELLOW}(dry-run mode — nothing will actually change)${C_RESET}"
echo "Log: $LOG_FILE"
echo

# --- 0. Pre-flight checks ---
step "0/6 — Pre-flight checks"

[[ -d /etc/nixos ]] || { fail "/etc/nixos does not exist — is this NixOS?"; exit 1; }
ok "/etc/nixos exists"

command -v git >/dev/null || { fail "git not found — install it first (nix-shell -p git)"; exit 1; }
ok "git available"

if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null && \
   ! grep -q "nix-command flakes" /etc/nixos/*.nix 2>/dev/null; then
    warn "flakes may not be enabled — this setup requires them"
fi

if [[ -f /etc/nixos/flake.nix ]] && ! confirm "/etc/nixos/flake.nix already exists. Overwrite (with backup)?"; then
    fail "Aborted by user — existing config left untouched"
    exit 1
fi
ok "Pre-flight checks passed"

# --- 1. System config ---
step "1/6 — System config → /etc/nixos"

for f in configuration.nix flake.nix; do
    if [[ $DRY_RUN -eq 0 ]]; then
        [[ -e "/etc/nixos/$f" ]] && sudo cp -a "/etc/nixos/$f" "/etc/nixos/$f.bak.$TIMESTAMP" 2>/dev/null || true
    fi
    run "copy $f" sudo cp -a "$REPO_DIR/$f" "/etc/nixos/$f"
done
run "copy modules/" sudo cp -a "$REPO_DIR/modules" /etc/nixos/

if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    info "Generating your own hardware-configuration.nix..."
    if [[ $DRY_RUN -eq 0 ]]; then
        sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix > /dev/null
        ok "hardware-configuration.nix generated"
    else
        echo "  [dry-run] would generate hardware-configuration.nix"
    fi
else
    ok "keeping your existing hardware-configuration.nix"
fi

# --- 2. Niri config ---
step "2/6 — Niri config"

mkdir -p "$HOME/.config/niri"
backup_if_exists "$HOME/.config/niri/config.kdl"
run "install config.kdl" cp "$REPO_DIR/niri/config.kdl" "$HOME/.config/niri/config.kdl"

# --- 3. Color sync ---
step "3/6 — Wallpaper → niri color sync"

mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
if [[ ! -w "$HOME/.local/bin" ]]; then
    warn "~/.local/bin is not writable — fixing permissions"
    run "chmod ~/.local/bin writable" chmod u+w "$HOME/.local/bin"
fi
run "install niri-sync-colors" cp "$REPO_DIR/scripts/niri-sync-colors" "$HOME/.local/bin/"
run "chmod niri-sync-colors" chmod +x "$HOME/.local/bin/niri-sync-colors"
run "install service" cp "$REPO_DIR/systemd/niri-sync-colors.service" "$HOME/.config/systemd/user/"

# --- 4. Optional extras ---
step "4/6 — Optional extras"

INSTALL_NOTIFIER=0
if confirm "Install the optional update-notification timer? (checks daily, never applies anything)"; then
    INSTALL_NOTIFIER=1
    run "install update notifier script" cp "$REPO_DIR/scripts/check-config-updates.sh" "$HOME/.local/bin/"
    run "chmod update notifier" chmod +x "$HOME/.local/bin/check-config-updates.sh"
    run "install notifier units" cp "$REPO_DIR/systemd/check-config-updates.service" "$REPO_DIR/systemd/check-config-updates.timer" "$HOME/.config/systemd/user/"
fi

# --- 5. Enable services ---
step "5/6 — Enable services"

run "daemon-reload" systemctl --user daemon-reload
run "enable niri-sync-colors" systemctl --user enable --now niri-sync-colors.service
[[ $INSTALL_NOTIFIER -eq 1 ]] && run "enable update notifier" systemctl --user enable --now check-config-updates.timer

# --- 6. Rebuild ---
step "6/6 — Apply configuration"

if [[ $SKIP_REBUILD -eq 1 ]]; then
    warn "Skipping rebuild (--skip-rebuild). Run manually when ready:"
    echo "    sudo nixos-rebuild switch --flake /etc/nixos#nixos"
elif confirm "Run 'sudo nixos-rebuild switch' now? (can take a while on first run)"; then
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  [dry-run] would run: sudo nixos-rebuild switch --flake /etc/nixos#nixos"
    else
        info "Building — this can take several minutes on first run..."
        if sudo nixos-rebuild switch --flake /etc/nixos#nixos 2>&1 | tee -a "$LOG_FILE"; then
            ok "Rebuild successful"
        else
            fail "Rebuild failed — your PREVIOUS system generation is still active and untouched."
            echo "  Check the log: $LOG_FILE"
            exit 1
        fi
    fi
else
    warn "Skipped — run this yourself when ready:"
    echo "    sudo nixos-rebuild switch --flake /etc/nixos#nixos"
fi

echo
echo "${C_BOLD}${C_GREEN}═══════════════════════════════════════════"
echo "  Install steps complete."
echo "═══════════════════════════════════════════${C_RESET}"
echo "  Verify everything:  bash $REPO_DIR/scripts/verify-setup.sh"
echo "  Full log:           $LOG_FILE"
