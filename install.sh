#!/usr/bin/env bash
#
#   ██╗███╗   ██╗██╗██████╗
#   ██║████╗  ██║██║██╔══██╗      ❄  iNiR + Niri on NixOS
#   ██║██╔██╗ ██║██║██████╔╝      Automated Modular Installer [EXPERIMENTAL]
#   ██║██║╚██╗██║██║██╔══██╗
#   ██║██║ ╚████║██║██║  ██║      https://github.com/LATAR-web/inir-nixos
#   ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
#
# Usage:
#   ./install.sh              Interactive install
#   ./install.sh --yes        Skip confirmations
#   ./install.sh --dry-run    Preview everything, change nothing
#   ./install.sh --skip-rebuild
#   ./install.sh --check      Run diagnostics and exit
#   ./install.sh --help
#
set -Eeuo pipefail

# ============================================================
# Paths & globals
# ============================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SCRIPT_START_SEC="$(date +%s)"
LOG_FILE="/tmp/inir-nixos-install-${TIMESTAMP}.log"
BACKUPS_DIR="/tmp/inir-nixos-backups-${TIMESTAMP}"

ASSUME_YES=0
DRY_RUN=0
SKIP_REBUILD=0
CHECK_ONLY=0
NO_AI=0
UPDATE_ONLY=0
ENABLE_MASCOT=""

# ============================================================
# Options
# ============================================================

usage() {
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}"
    cat <<'HELP'

Options:

  -y, --yes
      Automatically answer yes to confirmations.

  --dry-run
      Show what would happen without modifying the system.

  --skip-rebuild
      Install files and services but do not run nixos-rebuild.

  --update
      Non-interactive sync: updates iNiR modules and rebuilds system.

  --mascot
      Enable the Kira mascot companion and art pack without prompting.

  --no-mascot
      Skip the Kira mascot companion without prompting.

  --no-ai
      Skip the optional AI configuration review (if available).

  --check
      Run scripts/verify-setup.sh and exit. Installs nothing.

  -h, --help
      Show this help message.

Examples:

  ./install.sh
  ./install.sh --yes
  ./install.sh --dry-run
  ./install.sh --mascot
  ./install.sh --update
  ./install.sh --skip-rebuild
HELP
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y)         ASSUME_YES=1 ;;
        --dry-run)        DRY_RUN=1 ;;
        --skip-rebuild)   SKIP_REBUILD=1 ;;
        --update)         UPDATE_ONLY=1; ASSUME_YES=1 ;;
        --mascot)         ENABLE_MASCOT=1 ;;
        --no-mascot)      ENABLE_MASCOT=0 ;;
        --no-ai)          NO_AI=1 ;;
        --check)          CHECK_ONLY=1 ;;
        --help|-h)        usage; exit 0 ;;
        *)
            echo "Unknown option: $arg"
            echo "Run './install.sh --help' for usage."
            exit 1
            ;;
    esac
done

# ============================================================
# Colors / terminal UI
# ============================================================

COLOR=1
if [[ ! -t 1 ]]; then COLOR=0; fi
if [[ "${NO_COLOR:-}" != "" ]]; then COLOR=0; fi
if [[ "${TERM:-}" == "dumb" ]]; then COLOR=0; fi

if [[ "$COLOR" -eq 1 ]]; then
    RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; ITALIC=$'\033[3m'
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
    WHITE=$'\033[97m'
    ORANGE=$'\033[38;5;208m'
    BG_RED=$'\033[41m'; BG_GREEN=$'\033[42m'; BG_BLUE=$'\033[44m'
    BG_YELLOW=$'\033[43m'; BG_CYAN=$'\033[46m'
else
    RESET=''; BOLD=''; DIM=''; ITALIC=''
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; WHITE=''; ORANGE=''
    BG_RED=''; BG_GREEN=''; BG_BLUE=''; BG_YELLOW=''; BG_CYAN=''
fi

# ============================================================
# Logging
# ============================================================

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log()  { printf '%s\n' "$1" >> "$LOG_FILE"; }
info() { printf '  %s➜%s %s\n' "$CYAN" "$RESET" "$1";    log "INFO: $1"; }
ok()   { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$1";   log "OK: $1"; }
warn() { printf '  %s▲%s %s\n' "$YELLOW" "$RESET" "$1";  log "WARN: $1"; }
err()  { printf '  %s✘%s %s\n' "$RED" "$RESET" "$1" >&2; log "ERROR: $1"; }
debug() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET";      log "DEBUG: $1"; }

step() {
    echo
    printf '%s%s━━ %s %s━━%s\n' "$BOLD" "$ORANGE" "$1" "" "$RESET"
    log "STEP: $1"
}

banner() {
    echo
    printf '%s' "$CYAN$BOLD"
    cat <<'BANNER'
   ██╗███╗   ██╗██╗██████╗
   ██║████╗  ██║██║██╔══██╗     ❄ iNiR + Niri on NixOS
   ██║██╔██╗ ██║██║██████╔╝     Automated Modular Installer
   ██║██║╚██╗██║██║██╔══██╗
   ██║██║ ╚████║██║██║  ██║
   ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
BANNER
    printf '%s\n' "$RESET"
}

section_note() {
    echo
    printf '  %s%s%s\n' "$DIM" "$1" "$RESET"
}

dry_run_msg() {
    printf '  %s[dry-run]%s %s\n' "$YELLOW" "$RESET" "$1"
    log "DRY-RUN: $1"
}

# ============================================================
# Error handling
# ============================================================

FAILED=0

on_error() {
    local line="$1"
    if [[ "$FAILED" -eq 1 ]]; then exit 1; fi
    FAILED=1
    echo
    err "Installation failed at line $line."
    err "Full log: $LOG_FILE"
    exit 1
}

trap 'on_error "$LINENO"' ERR
trap 'echo; warn "Installation cancelled by user."; exit 130' INT TERM

# ============================================================
# Helpers
# ============================================================

run() {
    local description="$1"; shift
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "$description"
        debug "Command: $*"
        return 0
    fi
    log "RUN: $*"
    if "$@" >>"$LOG_FILE" 2>&1; then
        ok "$description"
    else
        err "$description failed."
        err "Check: $LOG_FILE"
        return 1
    fi
}

confirm() {
    local prompt="$1"
    if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
    if [[ "$DRY_RUN" -eq 1 ]]; then return 0; fi
    printf '  %s?%s %s %s[y/N]%s ' "$CYAN" "$RESET" "$prompt" "$BOLD" "$RESET"
    local reply
    read -r reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

backup_if_exists() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    local backup="${BACKUPS_DIR}/$(echo "$target" | sed 's|^/||; s|/|_|g').bak"
    # Never overwrite a backup created earlier in the same run (preserves original pristine file)
    [[ -e "$backup" ]] && return 0
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would backup: $target"
        return 0
    fi
    mkdir -p "$BACKUPS_DIR"
    local copy_cmd=(cp -a)
    if [[ "$target" == "/etc/nixos" || "$target" == /etc/nixos/* ]]; then
        copy_cmd=(sudo cp -a)
    fi
    if "${copy_cmd[@]}" "$target" "$backup"; then
        warn "Backup: $target → $backup"
        log "BACKUP: $target -> $backup"
    else
        err "Could not backup $target"
        return 1
    fi
}

# Insert a block of Nix code into /etc/nixos/configuration.nix before the
# last top-level closing brace. $1: path to a file containing the block.
inject_into_configuration_nix() {
    local block_file="$1"
    backup_if_exists "/etc/nixos/configuration.nix" || return 1
    local tmp_in tmp_out
    tmp_in="$(mktemp)"; tmp_out="$(mktemp)"
    sudo cat /etc/nixos/configuration.nix > "$tmp_in"
    awk -v block_file="$block_file" '
        { lines[NR] = $0 }
        END {
            ins = NR + 1
            for (i = NR; i >= 1; i--) { if (lines[i] ~ /^[ \t]*\}/) { ins = i; break } }
            for (i = 1; i <= NR; i++) {
                if (i == ins) {
                    print ""
                    while ((getline line < block_file) > 0) print line
                    close(block_file)
                }
                print lines[i]
            }
        }
    ' "$tmp_in" > "$tmp_out"
    if sudo cp "$tmp_out" /etc/nixos/configuration.nix; then
        rm -f "$tmp_in" "$tmp_out"
        return 0
    fi
    rm -f "$tmp_in" "$tmp_out"
    return 1
}

# Offer to inject a Nix block into configuration.nix (respects --dry-run/--yes).
# $1: feature name for messages; $2: file containing the Nix block.
offer_nix_injection() {
    local feature="$1" block_file="$2"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would inject into configuration.nix ($feature):"
        local line
        while IFS= read -r line; do printf '      %s\n' "$line"; done < "$block_file"
        return 0
    fi
    if ! confirm "Add $feature to configuration.nix?"; then
        warn "$feature not added — you can add it manually later."
        return 0
    fi
    if inject_into_configuration_nix "$block_file"; then
        ok "$feature added to configuration.nix"
    else
        warn "Could not inject $feature automatically."
    fi
    return 0
}

require_command() {
    local command="$1"
    local package_hint="${2:-}"
    if command -v "$command" >/dev/null 2>&1; then
        ok "$command available"
        return 0
    fi
    err "$command is not installed."
    if [[ -n "$package_hint" ]]; then
        echo "      Suggested package: $package_hint"
    fi
    return 1
}

# ============================================================
# Banner
# ============================================================

banner

printf '  Repo:    %shttps://github.com/LATAR-web/inir-nixos%s\n' "$BLUE" "$RESET"
printf '  Source:  %s%s%s\n' "$DIM" "$REPO_DIR" "$RESET"
printf '  Log:     %s%s%s\n' "$DIM" "$LOG_FILE" "$RESET"
echo
printf '  %s%s ⚠ EXPERIMENTAL %s\n' "$BG_YELLOW" "$WHITE" "$RESET"
printf '  Your existing configuration is backed up before any change.\n'
printf '  Modules are installed %snon-destructively%s: your own files in\n' "$BOLD" "$RESET"
printf '  /etc/nixos/modules (packages.nix, etc.) are preserved.\n'

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    printf '  %s%s DRY-RUN MODE — no changes will be made %s\n' "$BG_BLUE" "$WHITE" "$RESET"
fi

# ============================================================
# 0. Pre-flight
# ============================================================

step "0/7 · Pre-flight checks"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    exec bash "$REPO_DIR/scripts/verify-setup.sh"
fi

if [[ ! -d /etc/nixos ]]; then
    err "/etc/nixos does not exist."
    err "This installer requires NixOS."
    exit 1
fi
ok "NixOS detected"

# Disk space: the first rebuild fills /nix/store with Qt, KDE libs, etc.
NIX_FREE_GB="$(df -BG --output=avail /nix 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
if [[ "$NIX_FREE_GB" -gt 0 && "$NIX_FREE_GB" -lt 5 ]]; then
    err "Only ${NIX_FREE_GB}GB free in /nix — the first rebuild needs roughly 10GB."
    if [[ "$DRY_RUN" -eq 0 ]] && ! confirm "Continue anyway?"; then
        exit 1
    fi
    warn "Continuing with low disk space."
elif [[ "$NIX_FREE_GB" -gt 0 && "$NIX_FREE_GB" -lt 10 ]]; then
    warn "Low disk space in /nix (${NIX_FREE_GB}GB free); the first rebuild may need ~10GB."
else
    ok "Disk space OK (${NIX_FREE_GB}GB free in /nix)"
fi

# Network connectivity check
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || curl -s --connect-timeout 2 -I https://cache.nixos.org >/dev/null 2>&1; then
    ok "Network connectivity OK (Nix binary cache reachable)"
else
    warn "No network connectivity detected. Downloading dependencies might fail."
fi

# Battery power check on laptops
if [[ -d /sys/class/power_supply ]]; then
    for bat in /sys/class/power_supply/BAT*; do
        [[ -e "$bat" ]] || continue
        bat_status="$(cat "$bat/status" 2>/dev/null || echo "Unknown")"
        bat_cap="$(cat "$bat/capacity" 2>/dev/null || echo "100")"
        if [[ "$bat_status" == "Discharging" ]] && (( bat_cap < 30 )); then
            warn "Laptop is on battery (${bat_cap}%). Connecting AC power is strongly recommended for NixOS builds."
        fi
    done
fi

require_command git "git"
require_command nix "nix"
require_command sudo "sudo"

for required in configuration.nix flake.nix niri/config.kdl scripts/niri-sync-colors alacritty/alacritty.toml; do
    if [[ ! -f "$REPO_DIR/$required" ]]; then
        err "Missing $required in repository."
        exit 1
    fi
done
ok "Repository structure looks valid"

info "Validating Nix flake..."
if nix --extra-experimental-features "nix-command flakes" \
    flake check --no-write-lock-file "$REPO_DIR" >>"$LOG_FILE" 2>&1; then
    ok "Nix flake validation passed"
else
    err "Nix flake validation failed. See $LOG_FILE"
    tail -20 "$LOG_FILE" | sed 's/^/      /' >&2 || true
    exit 1
fi

# ============================================================
# 1. Detect environment
# ============================================================

step "1/7 · Detecting environment"

if [[ "$EUID" -eq 0 && -z "${SUDO_USER:-}" ]]; then
    warn "Running directly as root. Recommended: run as your normal user."
fi

TARGET_USER="${SUDO_USER:-$(whoami)}"
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    TARGET_HOME="$HOME"
fi

DETECTED_USER="$TARGET_USER"
DETECTED_HOSTNAME="$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo nixos)"
DETECTED_TZ="$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")"
DETECTED_LAYOUT="$(localectl status 2>/dev/null | grep 'X11 Layout' | awk -F': ' '{print $2}' | tr -d ' ')"
DETECTED_LOCALE="$(localectl status 2>/dev/null | grep 'System Locale' | awk -F'LANG=' '{print $2}' | tr -d ' ')"
DETECTED_GPU="unknown"
HAS_NVIDIA=0; HAS_INTEL=0; HAS_AMD=0
if command -v lspci >/dev/null 2>&1; then
    PCI_VGA="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)"
    if echo "$PCI_VGA" | grep -qi "nvidia"; then HAS_NVIDIA=1; fi
    if echo "$PCI_VGA" | grep -qi "intel"; then HAS_INTEL=1; fi
    if echo "$PCI_VGA" | grep -qiE "amd|advanced micro|ati"; then HAS_AMD=1; fi
elif [[ -d /sys/bus/pci/devices ]]; then
    if grep -qs "0x10de" /sys/bus/pci/devices/*/vendor 2>/dev/null; then HAS_NVIDIA=1; fi
    if grep -qs "0x8086" /sys/bus/pci/devices/*/vendor 2>/dev/null; then HAS_INTEL=1; fi
    if grep -qs "0x1002" /sys/bus/pci/devices/*/vendor 2>/dev/null; then HAS_AMD=1; fi
fi
if lsmod 2>/dev/null | grep -qE '^(nvidia|nouveau)'; then HAS_NVIDIA=1; fi
if lsmod 2>/dev/null | grep -qE '^(i915|xe)'; then HAS_INTEL=1; fi
if lsmod 2>/dev/null | grep -qE '^amdgpu'; then HAS_AMD=1; fi

if [[ "$HAS_NVIDIA" -eq 1 ]]; then
    DETECTED_GPU="nvidia"
elif [[ "$HAS_AMD" -eq 1 ]]; then
    DETECTED_GPU="amd"
elif [[ "$HAS_INTEL" -eq 1 ]]; then
    DETECTED_GPU="intel"
fi
IS_VM="no"
VIRT_TYPE="$(systemd-detect-virt 2>/dev/null || true)"
if [[ -z "$VIRT_TYPE" ]]; then VIRT_TYPE="none"; fi
if [[ "$VIRT_TYPE" != "none" ]]; then
    IS_VM="yes ($VIRT_TYPE)"
fi

# Respect values already present in the user's configuration.nix
if [[ -f /etc/nixos/configuration.nix ]]; then
    CONF_TZ="$(grep -E '^\s*time\.timeZone\s*=' /etc/nixos/configuration.nix | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    [[ -n "$CONF_TZ" ]] && DETECTED_TZ="$CONF_TZ"
    CONF_HOST="$(grep -E '^\s*networking\.hostName\s*=' /etc/nixos/configuration.nix | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    [[ -n "$CONF_HOST" ]] && DETECTED_HOSTNAME="$CONF_HOST"
    CONF_LOC="$(grep -E '^\s*i18n\.defaultLocale\s*=' /etc/nixos/configuration.nix | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    [[ -n "$CONF_LOC" ]] && DETECTED_LOCALE="$CONF_LOC"
fi

[[ -z "$DETECTED_TZ" ]] && DETECTED_TZ="UTC"
[[ -z "$DETECTED_LAYOUT" ]] && DETECTED_LAYOUT="us"
[[ -z "$DETECTED_LOCALE" ]] && DETECTED_LOCALE="en_US.UTF-8"

info "User:     $DETECTED_USER ($TARGET_HOME)"
info "Hostname: $DETECTED_HOSTNAME"
info "Timezone: $DETECTED_TZ · Locale: $DETECTED_LOCALE"
info "Keyboard: $DETECTED_LAYOUT · GPU: $DETECTED_GPU · VM: $IS_VM"

if [[ "$ASSUME_YES" -ne 1 && "$DRY_RUN" -ne 1 ]]; then
    if ! confirm "Confirm detected settings?"; then
        read -rp "  Username [$DETECTED_USER]: " _u
        read -rp "  Hostname [$DETECTED_HOSTNAME]: " _h
        read -rp "  Timezone [$DETECTED_TZ]: " _t
        read -rp "  Locale [$DETECTED_LOCALE]: " _loc
        read -rp "  Keyboard layout [$DETECTED_LAYOUT]: " _l
        [[ -n "$_u" ]] && DETECTED_USER="$_u"
        [[ -n "$_h" ]] && DETECTED_HOSTNAME="$_h"
        [[ -n "$_t" ]] && DETECTED_TZ="$_t"
        [[ -n "$_loc" ]] && DETECTED_LOCALE="$_loc"
        [[ -n "$_l" ]] && DETECTED_LAYOUT="$_l"
    fi
fi

# ============================================================
# 2. Display manager recommendation (niri-in-GDM fix)
# ============================================================

step "2/7 · Display manager"

# GDM can hide Wayland sessions (VMs without 3D accel, some NVIDIA setups,
# stale AccountsService state). greetd+tuigreet always lists every session.
RECOMMEND_GREETD=0
RECOMMEND_REASON=""
if [[ "$VIRT_TYPE" == "kvm" || "$VIRT_TYPE" == "qemu" || "$VIRT_TYPE" == "vmware" || "$VIRT_TYPE" == "oracle" || "$VIRT_TYPE" == "microsoft" || "$VIRT_TYPE" == "bochs" ]]; then
    RECOMMEND_GREETD=1
    RECOMMEND_REASON="you are in a VM ($VIRT_TYPE — GDM hides Wayland sessions without 3D acceleration)"
elif [[ "$DETECTED_GPU" == "nvidia" ]]; then
    RECOMMEND_GREETD=1
    RECOMMEND_REASON="NVIDIA GPU (GDM may hide Wayland sessions on some driver combos)"
fi

STALE_ACCOUNTSSERVICE=0
AS_FILE="$TARGET_HOME/.cache/AccountService*"
for f in $AS_FILE; do
    [[ -e "$f" ]] || continue
    if ! grep -q "niri" "$f" 2>/dev/null && grep -q "Session\|XSession" "$f" 2>/dev/null; then
        STALE_ACCOUNTSSERVICE=1
    fi
done
if [[ "$STALE_ACCOUNTSSERVICE" -eq 1 && "$RECOMMEND_GREETD" -eq 0 ]]; then
    RECOMMEND_GREETD=1
    RECOMMEND_REASON="stale AccountsService state (remembers an old session; GDM trusts it)"
fi

DEFAULT_DM="gdm"
if [[ "$RECOMMEND_GREETD" -eq 1 ]]; then
    DEFAULT_DM="greetd"
    warn "greetd recommended: $RECOMMEND_REASON."
    warn "With GDM, niri may not appear in the session list after a reboot."
fi

CHOSEN_DM="$DEFAULT_DM"
if [[ "$ASSUME_YES" -eq 1 ]]; then
    CHOSEN_DM="$DEFAULT_DM"
    info "Display manager: $CHOSEN_DM (auto-selected)"
else
    echo
    printf '    %s1)%s gdm     — GNOME Display Manager (default, full-featured)\n' "$BOLD" "$RESET"
    printf '    %s2)%s greetd  — minimal Wayland greeter; ALWAYS lists niri\n' "$BOLD" "$RESET"
    echo
    if [[ "$DEFAULT_DM" == "greetd" ]]; then
        printf '  %s?%s Choose display manager %s[2=greetd recommended]%s: ' "$CYAN" "$RESET" "$BOLD" "$RESET"
    else
        printf '  %s?%s Choose display manager %s[1=gdm]%s: ' "$CYAN" "$RESET" "$BOLD" "$RESET"
    fi
    if [[ "$DRY_RUN" -eq 0 ]]; then
        read -r _dm
        case "$_dm" in
            2|greetd) CHOSEN_DM="greetd" ;;
            1|gdm)    CHOSEN_DM="gdm" ;;
            "")       CHOSEN_DM="$DEFAULT_DM" ;;
            *)        CHOSEN_DM="$DEFAULT_DM" ;;
        esac
    fi
    info "Display manager: $CHOSEN_DM"
fi

# ============================================================
# 3. Stray / obsolete services cleanup
# ============================================================

step "3/7 · Cleaning up stray and obsolete user services"

STRAY_SERVICE="$TARGET_HOME/.config/systemd/user/inir.service"
if [[ -e "$STRAY_SERVICE" ]]; then
    warn "$STRAY_SERVICE exists — it overrides the declarative NixOS service"
    warn "and silently breaks iNiR (usually created by running 'inir doctor')."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would remove: $STRAY_SERVICE"
    elif confirm "Remove stray inir.service now?"; then
        rm -f "$STRAY_SERVICE"
        rm -f "$TARGET_HOME/.config/systemd/user/inir.service.d/"*.conf 2>/dev/null || true
        ok "Stray service file removed"
    else
        warn "Left in place — expect iNiR service conflicts."
    fi
else
    ok "No stray inir.service"
fi

# A REAL (non-symlink) ~/.config/quickshell/inir directory shadows the packaged
# runtime: the `inir` launcher looks for scripts/lib/config-path.sh next to the
# script first and finds none, failing with "Unable to locate config-path
# helper". modules/inir.nix deploys a tmpfiles rule that symlinks this path to
# the Nix store, but tmpfiles (and the NixOS activation) refuse to replace an
# existing non-empty directory — so it must be cleared here.
QS_REAL_DIR="$TARGET_HOME/.config/quickshell/inir"
if [[ -d "$QS_REAL_DIR" && ! -L "$QS_REAL_DIR" ]]; then
    warn "$QS_REAL_DIR is a real directory — it will shadow the packaged iNiR runtime."
    warn "(Typical symptom: 'Unable to locate config-path helper' when running `inir run`.)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would back up and remove: $QS_REAL_DIR"
    elif confirm "Back it up and remove it now? (recreate it with 'systemd-tmpfiles --user --create' after the rebuild)"; then
        mkdir -p "$BACKUPS_DIR"
        cp -a "$QS_REAL_DIR" "$BACKUPS_DIR/home_.config_quickshell_inir" || true
        rm -rf "$QS_REAL_DIR"
        ok "Real quickshell/inir directory backed up and removed (NixOS will symlink it after the rebuild)"
    else
        warn "Left in place — expect 'Unable to locate config-path helper' and a broken shell."
    fi
fi

# Reset stale AccountsService session (fixes GDM not offering niri)
if [[ "$STALE_ACCOUNTSSERVICE" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would remove stale AccountsService state for $TARGET_USER"
    else
        sudo rm -f "/var/lib/AccountsService/users/$TARGET_USER" 2>/dev/null || true
        ok "Stale AccountsService state cleared for $TARGET_USER (niri will be offered fresh)"
    fi
fi

# Clean up obsolete services from older revisions of this installer
OLD_COLOR_SERVICE="$TARGET_HOME/.config/systemd/user/niri-color-sync.service"
if [[ -e "$OLD_COLOR_SERVICE" ]]; then
    systemctl --user stop niri-color-sync.service 2>/dev/null || true
    systemctl --user disable niri-color-sync.service 2>/dev/null || true
    rm -f "$OLD_COLOR_SERVICE" "$TARGET_HOME/.local/bin/sync-niri-colors.sh" 2>/dev/null || true
    ok "Removed obsolete niri-color-sync service"
fi

OLD_XWAYLAND_SERVICE="$TARGET_HOME/.config/systemd/user/xwayland-satellite.service"
if [[ -e "$OLD_XWAYLAND_SERVICE" || -e "$TARGET_HOME/.config/systemd/user/graphical-session.target.wants/xwayland-satellite.service" ]]; then
    systemctl --user stop xwayland-satellite.service 2>/dev/null || true
    systemctl --user disable xwayland-satellite.service 2>/dev/null || true
    rm -f "$OLD_XWAYLAND_SERVICE" "$TARGET_HOME/.config/systemd/user/graphical-session.target.wants/xwayland-satellite.service" 2>/dev/null || true
    ok "Removed obsolete xwayland-satellite service"
fi

for obsolete_unit in check-config-updates.timer check-config-updates.service auto-update.timer auto-update.service; do
    if [[ -e "$TARGET_HOME/.config/systemd/user/$obsolete_unit" || -e "$TARGET_HOME/.config/systemd/user/timers.target.wants/$obsolete_unit" ]]; then
        systemctl --user stop "$obsolete_unit" 2>/dev/null || true
        systemctl --user disable "$obsolete_unit" 2>/dev/null || true
        rm -f "$TARGET_HOME/.config/systemd/user/$obsolete_unit" "$TARGET_HOME/.config/systemd/user/timers.target.wants/$obsolete_unit" 2>/dev/null || true
        rm -f "$TARGET_HOME/.local/bin/check-config-updates.sh" "$TARGET_HOME/.local/bin/auto-update.sh" 2>/dev/null || true
        ok "Removed obsolete $obsolete_unit"
    fi
done

# ============================================================
# 4. System configuration (non-destructive merge)
# ============================================================

step "4/7 · Installing iNiR modules → /etc/nixos (non-destructive)"

section_note "iNiR modules are updated, your own files in modules/ are kept."
section_note "modules/default.nix auto-imports every .nix in that directory."

if [[ "$DRY_RUN" -eq 0 ]]; then
    sudo mkdir -p /etc/nixos/modules
    # 1) Update only the iNiR-owned module files (never touch user files)
    for f in audio.nix desktop.nix fonts.nix inir-deps.nix inir.nix mascot.nix runtime.nix default.nix; do
        # Backup only when the installed file actually differs from the repo one
        if [[ -f "/etc/nixos/modules/$f" ]] && ! cmp -s "$REPO_DIR/modules/$f" "/etc/nixos/modules/$f"; then
            backup_if_exists "/etc/nixos/modules/$f"
        fi
        sudo cp -a "$REPO_DIR/modules/$f" /etc/nixos/modules/"$f"
    done
    if [[ -d "$REPO_DIR/modules/patches" ]]; then
        [[ -d /etc/nixos/modules/patches ]] && backup_if_exists "/etc/nixos/modules/patches"
        sudo rm -rf /etc/nixos/modules/patches
        sudo cp -a "$REPO_DIR/modules/patches" /etc/nixos/modules/patches
    fi
    ok "iNiR modules updated (user files untouched)"
    # Show what was preserved
    local_preserved=()
    for f in /etc/nixos/modules/*.nix; do
        base="$(basename "$f")"
        case "$base" in
            audio.nix|desktop.nix|fonts.nix|inir-deps.nix|inir.nix|mascot.nix|runtime.nix|default.nix) ;;
            *) local_preserved+=("$base") ;;
        esac
    done
    if [[ ${#local_preserved[@]} -gt 0 ]]; then
        info "Preserved your own modules: ${local_preserved[*]}"
    fi
else
    dry_run_msg "Would update iNiR-owned modules in /etc/nixos/modules (keeping user files)"
fi

if [[ -f /etc/nixos/configuration.nix ]]; then
    info "Existing configuration.nix detected — adapting instead of replacing."
    if [[ "$DRY_RUN" -eq 0 ]]; then
        if grep -Eq '^[^#]*\./modules' /etc/nixos/configuration.nix; then
            ok "./modules already imported in configuration.nix"
        else
            # Robust injection: handles the three common import spellings
            #   imports = [ ./hw.nix ];          (inline closed list)
            #   imports = [                      (multi-line list)
            #   imports =\n[ ./hw.nix ];         (bracket on next line)
            TMP_CONF="$(mktemp)"
            sudo cat /etc/nixos/configuration.nix | awk '
                /^\s*imports\s*=\s*\[.*\];/ { sub(/\[/, "[ ./modules"); print; next }
                /^\s*imports\s*=\s*\[/       { print; print "  ./modules"; next }
                /^\s*imports\s*=\s*$/         { span=1; print; next }
                span && /^\s*\[/              { print; print "  ./modules"; span=0; next }
                { print }
            ' > "$TMP_CONF"
            if grep -Eq '^[^#]*\./modules' "$TMP_CONF"; then
                sudo cp "$TMP_CONF" /etc/nixos/configuration.nix
                ok "Added ./modules to imports in configuration.nix"
            else
                warn "Could not inject ./modules into imports automatically."
                info "This is the start of your /etc/nixos/configuration.nix:"
                sudo sed -n '1,30p' /etc/nixos/configuration.nix | sed 's/^/      /'
                info "Add './modules' inside the imports list, then re-run this installer."
            fi
            rm -f "$TMP_CONF"
        fi

    else
        dry_run_msg "Would ensure ./modules is imported in configuration.nix"
    fi
    # Hard guarantee: without this import the whole installer is a no-op.
    if [[ "$DRY_RUN" -eq 0 ]] && ! grep -Eq '^[^#]*\./modules' /etc/nixos/configuration.nix; then
        err "./modules is NOT imported in /etc/nixos/configuration.nix — the rebuild would apply NOTHING."
        err "Add it inside the imports list and re-run this installer."
        exit 1
    fi
else
    info "No configuration.nix — installing reference configuration..."
    backup_if_exists "/etc/nixos/configuration.nix"
    run "Install configuration.nix" sudo cp -a "$REPO_DIR/configuration.nix" /etc/nixos/configuration.nix
    if [[ "$DRY_RUN" -eq 0 ]]; then
        sudo sed -i \
            -e "s/\"YOUR_USERNAME\"/\"$DETECTED_USER\"/g" \
            -e "s/networking.hostName = \"nixos\";/networking.hostName = \"$DETECTED_HOSTNAME\";/" \
            -e "s#time.timeZone = \"America/Mexico_City\";#time.timeZone = \"$DETECTED_TZ\";#" \
            -e "s/i18n.defaultLocale = \"es_MX.UTF-8\";/i18n.defaultLocale = \"$DETECTED_LOCALE\";/" \
            /etc/nixos/configuration.nix
        ok "Reference configuration personalized for $DETECTED_USER"
    fi
fi

# ------------------------------------------------------------
# Unfree / proprietary software permission (NVIDIA, Steam, ...)
# ------------------------------------------------------------
info "Checking proprietary (unfree) software permission..."
UNFREE_STATUS="absent"
for unfree_file in /etc/nixos/configuration.nix /etc/nixos/flake.nix /etc/nixos/modules/*.nix; do
    [[ -f "$unfree_file" ]] || continue
    if grep -Eq 'allowUnfree[[:space:]]*=[[:space:]]*true|allowUnfreePredicate' "$unfree_file" 2>/dev/null; then
        UNFREE_STATUS="true"
        ok "Proprietary software allowed (allowUnfree = true in $unfree_file)"
        break
    fi
done
if [[ "$UNFREE_STATUS" != "true" ]]; then
    # Explicitly set to false somewhere?
    UNFREE_FALSE_FILE=""
    for unfree_file in /etc/nixos/configuration.nix /etc/nixos/flake.nix /etc/nixos/modules/*.nix; do
        if [[ -f "$unfree_file" ]] && grep -Eq 'allowUnfree[[:space:]]*=[[:space:]]*false' "$unfree_file" 2>/dev/null; then
            UNFREE_FALSE_FILE="$unfree_file"
            break
        fi
    done
    warn "Proprietary software is NOT enabled (nixpkgs.config.allowUnfree)."
    warn "Without it, unfree packages (NVIDIA drivers, Steam, VS Code, ...) fail to build."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        if [[ -n "$UNFREE_FALSE_FILE" ]]; then
            dry_run_msg "Would set allowUnfree = true in $UNFREE_FALSE_FILE"
        else
            dry_run_msg "Would add nixpkgs.config.allowUnfree = true to /etc/nixos/configuration.nix"
        fi
    elif confirm "Enable proprietary (unfree) software now?"; then
        if [[ -n "$UNFREE_FALSE_FILE" ]]; then
            backup_if_exists "$UNFREE_FALSE_FILE"
            sudo sed -i -E 's/allowUnfree[[:space:]]*=[[:space:]]*false/allowUnfree = true/g' "$UNFREE_FALSE_FILE"
            if grep -Eq 'allowUnfree[[:space:]]*=[[:space:]]*true' "$UNFREE_FALSE_FILE"; then
                ok "Unfree software enabled in $UNFREE_FALSE_FILE"
            else
                err "Could not flip allowUnfree to true in $UNFREE_FALSE_FILE."
                info "Set it manually: nixpkgs.config.allowUnfree = true;"
            fi
        else
            backup_if_exists "/etc/nixos/configuration.nix"
            TMP_CONF="$(mktemp)"
            # Insert before the last top-level closing brace of configuration.nix
            sudo cat /etc/nixos/configuration.nix | awk '
                { lines[NR] = $0 }
                END {
                    ins = NR + 1
                    for (i = NR; i >= 1; i--) { if (lines[i] ~ /^[ \t]*\}/) { ins = i; break } }
                    for (i = 1; i <= NR; i++) {
                        if (i == ins) {
                            print ""
                            print "  # Allow proprietary (unfree) software: NVIDIA, Steam, VS Code, etc."
                            print "  nixpkgs.config.allowUnfree = true;"
                        }
                        print lines[i]
                    }
                }
            ' > "$TMP_CONF"
            if grep -Eq 'allowUnfree[[:space:]]*=[[:space:]]*true' "$TMP_CONF"; then
                sudo cp "$TMP_CONF" /etc/nixos/configuration.nix
                ok "Unfree software enabled: nixpkgs.config.allowUnfree = true added to configuration.nix"
            else
                warn "Could not inject allowUnfree automatically."
                info "Add this inside the main { ... } block of /etc/nixos/configuration.nix:"
                printf '      %s\n' 'nixpkgs.config.allowUnfree = true;'
            fi
            rm -f "$TMP_CONF"
        fi
    else
        warn "Unfree software left disabled — proprietary packages will fail to evaluate."
    fi
fi

# Niri session file must exist for display managers to list it
if [[ "$DRY_RUN" -eq 0 ]]; then
    if ! grep -q "programs.niri.enable" /etc/nixos/configuration.nix /etc/nixos/modules/inir.nix 2>/dev/null; then
        warn "programs.niri.enable not found — it is enabled by modules/inir.nix (installed above)."
    fi
fi

# i2c udev rule: ddcutil needs i2c-dev character devices accessible to the user.
if [[ "$DRY_RUN" -eq 0 ]]; then
    if ! grep -q 'i2c-dev' /etc/nixos/modules/inir.nix /etc/nixos/modules/runtime.nix /etc/nixos/configuration.nix 2>/dev/null; then
        info "Tip: 'hardware.i2c.enable = true;' in configuration.nix enables external-monitor brightness."
    fi
fi

# ------------------------------------------------------------
# Unstable channel check (iNiR/Niri need it)
# ------------------------------------------------------------
info "Checking NixOS channel..."
IS_UNSTABLE=0
DETECTED_VER="$(nixos-version 2>/dev/null || echo "unknown")"
if [[ -f /etc/nixos/flake.nix ]] && grep -Eq 'nixpkgs\.url\s*=.*(unstable)' /etc/nixos/flake.nix; then
    IS_UNSTABLE=1
    ok "flake.nix already targets nixos-unstable"
elif [[ "$DETECTED_VER" =~ (unstable|pre) ]]; then
    IS_UNSTABLE=1
    ok "System version ($DETECTED_VER) is on unstable"
else
    warn "Stable NixOS detected ($DETECTED_VER); iNiR needs nixos-unstable."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would update flake.nix to nixos-unstable"
    elif [[ -f /etc/nixos/flake.nix ]]; then
        backup_if_exists "/etc/nixos/flake.nix"
        sudo sed -i -E 's|(github:)?[nN]ix[oO][sS]/nixpkgs/nixos-[0-9]{2}\.[0-9]{2}|github:nixos/nixpkgs/nixos-unstable|g' /etc/nixos/flake.nix
        ok "flake.nix switched to nixos-unstable"
    fi
fi

# iNiR flake input check (or offer to install reference flake.nix)
if [[ -f /etc/nixos/flake.nix ]]; then
    if grep -q "snowarch/inir" /etc/nixos/flake.nix; then
        ok "iNiR flake input present"
    else
        warn "iNiR input missing in /etc/nixos/flake.nix. Required:"
        printf '      %s\n' 'inputs.inir.url = "github:snowarch/inir";'
        printf '      %s\n' 'specialArgs = { inherit inir; };'
    fi

    # Auto-repair: ensure flake.nix provides nixosConfigurations.nixos and default
    if ! grep -q 'nixosConfigurations\.nixos' /etc/nixos/flake.nix 2>/dev/null; then
        if grep -q 'systemConfig' /etc/nixos/flake.nix 2>/dev/null; then
            backup_if_exists "/etc/nixos/flake.nix"
            sudo sed -i -E '0,/(nixosConfigurations\.[^=]+=[^;]+;)/s//\1\n      nixosConfigurations.nixos = systemConfig;/' /etc/nixos/flake.nix 2>/dev/null || true
            ok "Added nixosConfigurations.nixos fallback to /etc/nixos/flake.nix"
        fi
    fi
    if ! grep -q 'nixosConfigurations\.default' /etc/nixos/flake.nix 2>/dev/null; then
        if grep -q 'systemConfig' /etc/nixos/flake.nix 2>/dev/null; then
            sudo sed -i -E '0,/(nixosConfigurations\.[^=]+=[^;]+;)/s//\1\n      nixosConfigurations.default = systemConfig;/' /etc/nixos/flake.nix 2>/dev/null || true
            ok "Added nixosConfigurations.default fallback to /etc/nixos/flake.nix"
        fi
    fi
else
    info "No flake.nix found in /etc/nixos (required for iNiR modules)."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would install reference flake.nix to /etc/nixos/flake.nix"
    elif confirm "Install reference flake.nix into /etc/nixos?"; then
        backup_if_exists "/etc/nixos/flake.nix"
        sudo cp "$REPO_DIR/flake.nix" /etc/nixos/flake.nix
        if [[ "$DETECTED_HOSTNAME" != "nixos" && -n "$DETECTED_HOSTNAME" ]]; then
            sudo sed -i -E "s/nixosConfigurations\.nixos[[:space:]]*=/nixosConfigurations.\"$DETECTED_HOSTNAME\" = systemConfig;\n      nixosConfigurations.nixos =/g" /etc/nixos/flake.nix 2>/dev/null || true
        fi
        ok "Reference flake.nix installed in /etc/nixos (configured for $DETECTED_HOSTNAME + nixos/default)"
    else
        warn "flake.nix not installed — you will need to configure the iNiR flake input manually."
    fi
fi

if [[ "$DRY_RUN" -eq 0 && -d /etc/nixos/.git ]]; then
    sudo git -C /etc/nixos add -A >/dev/null 2>&1 || true
    debug "Staged changes in /etc/nixos git repo"
fi

if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    info "No hardware-configuration.nix found."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would generate hardware-configuration.nix"
    elif confirm "Generate hardware-configuration.nix for this machine?"; then
        if sudo nixos-generate-config --show-hardware-config |
            sudo tee /etc/nixos/hardware-configuration.nix >/dev/null; then
            ok "hardware-configuration.nix generated"
        else
            err "Could not generate hardware-configuration.nix"
            exit 1
        fi
    else
        warn "Hardware configuration generation skipped."
    fi
else
    ok "Existing hardware-configuration.nix preserved"
fi

# ------------------------------------------------------------
# Machine-specific adaptation: make the config fit THIS machine.
# The display manager chosen in step 2, GPU drivers, CPU microcode,
# VM guest agents, keyboard layout and user groups are written into
# configuration.nix. Every change is guarded (settings already present
# in the user's config are never duplicated) and backed up.
# ------------------------------------------------------------
MAIN_CONF="/etc/nixos/configuration.nix"

if [[ -f "$MAIN_CONF" ]]; then
    info "Adapting configuration to this machine (GPU, CPU, VM, keyboard)..."

    # 1) Display manager chosen in step 2 (greetd is never the module default)
    if [[ "$CHOSEN_DM" == "greetd" ]] && ! grep -q "displayManager" "$MAIN_CONF" 2>/dev/null; then
        DM_BLOCK="$(mktemp)"
        {
            echo "  # greetd was chosen during install: it always lists the niri session."
            echo '  programs.inir.desktop.displayManager = "greetd";'
        } > "$DM_BLOCK"
        offer_nix_injection "greetd as display manager" "$DM_BLOCK"
        rm -f "$DM_BLOCK"
    fi

    # 2) Keyboard layout (modules default to "us"; only inject non-US layouts)
    if [[ -n "$DETECTED_LAYOUT" && "$DETECTED_LAYOUT" != "us" ]]; then
        KB_LINES=()
        if ! grep -Eq 'services\.xserver(\.xkb)?\.layout|xserver\.xkb\.layout|services\.xserver\.layout|layout\s*=\s*"[^"]+"' "$MAIN_CONF" 2>/dev/null; then
            KB_LINES+=("  services.xserver.xkb.layout = \"$DETECTED_LAYOUT\";")
        fi
        if ! grep -q "console.keyMap" "$MAIN_CONF" 2>/dev/null; then
            KB_LINES+=("  console.keyMap = \"$DETECTED_LAYOUT\";")
        fi
        if [[ ${#KB_LINES[@]} -gt 0 ]]; then
            KB_BLOCK="$(mktemp)"
            {
                echo "  # Keyboard layout detected by install.sh"
                printf '%s\n' "${KB_LINES[@]}"
            } > "$KB_BLOCK"
            offer_nix_injection "keyboard layout ($DETECTED_LAYOUT)" "$KB_BLOCK"
            rm -f "$KB_BLOCK"
        fi
    fi

    # 3) NVIDIA GPU: driver + Wayland-safe environment
    if [[ "$DETECTED_GPU" == "nvidia" ]]; then
        if grep -Eq 'hardware\.nvidia' "$MAIN_CONF" 2>/dev/null; then
            ok "NVIDIA configuration already present"
        elif grep -Eq 'services\.xserver\.videoDrivers' "$MAIN_CONF" 2>/dev/null; then
            warn "GPU is NVIDIA but videoDrivers is already set in your config — left untouched."
        else
            NV_BLOCK="$(mktemp)"
            cat > "$NV_BLOCK" <<'EOF'
  # NVIDIA GPU detected by install.sh
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelParams = [ "nvidia_drm.modeset=1" ];
  hardware.nvidia = {
    modesetting.enable = true;
    # open = true works on Turing+ (GTX 16xx/RTX and newer); set false for older GPUs.
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  };
EOF
            offer_nix_injection "NVIDIA driver configuration" "$NV_BLOCK"
            rm -f "$NV_BLOCK"
        fi
    fi

    # 4) CPU microcode + redistributable firmware
    CPU_VENDOR="$(awk -F': *' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
    MC_LINE=""
    if ! grep -q "updateMicrocode" "$MAIN_CONF" 2>/dev/null; then
        case "$CPU_VENDOR" in
            *GenuineIntel*) MC_LINE="  hardware.cpu.intel.updateMicrocode = true;" ;;
            *AuthenticAMD*) MC_LINE="  hardware.cpu.amd.updateMicrocode = true;" ;;
        esac
    fi
    FW_NEEDED=0
    grep -q "enableRedistributableFirmware" "$MAIN_CONF" 2>/dev/null || FW_NEEDED=1
    if [[ -n "$MC_LINE" || "$FW_NEEDED" -eq 1 ]]; then
        FW_BLOCK="$(mktemp)"
        {
            echo "  # CPU microcode + firmware (detected vendor: ${CPU_VENDOR:-unknown})"
            if [[ -n "$MC_LINE" ]]; then echo "$MC_LINE"; fi
            if [[ "$FW_NEEDED" -eq 1 ]]; then echo "  hardware.enableRedistributableFirmware = true;"; fi
        } > "$FW_BLOCK"
        offer_nix_injection "CPU microcode/firmware updates" "$FW_BLOCK"
        rm -f "$FW_BLOCK"
    fi

    # 5) VM guest agents (only inside an actual VM)
    case "$VIRT_TYPE" in
        kvm|qemu)
            if ! grep -q "qemuGuest" "$MAIN_CONF" 2>/dev/null; then
                VM_BLOCK="$(mktemp)"
                {
                    echo "  # QEMU/KVM guest agent (VM detected by install.sh)"
                    echo "  services.qemuGuest.enable = true;"
                } > "$VM_BLOCK"
                offer_nix_injection "QEMU guest agent" "$VM_BLOCK"
                rm -f "$VM_BLOCK"
            fi
            ;;
        virtualbox)
            if ! grep -q "virtualbox.guest" "$MAIN_CONF" 2>/dev/null; then
                VM_BLOCK="$(mktemp)"
                {
                    echo "  # VirtualBox guest additions (VM detected by install.sh)"
                    echo "  virtualisation.virtualbox.guest.enable = true;"
                } > "$VM_BLOCK"
                offer_nix_injection "VirtualBox guest additions" "$VM_BLOCK"
                rm -f "$VM_BLOCK"
            fi
            ;;
        vmware)
            if ! grep -q "vmware.guest" "$MAIN_CONF" 2>/dev/null; then
                VM_BLOCK="$(mktemp)"
                {
                    echo "  # VMware guest tools (VM detected by install.sh)"
                    echo "  virtualisation.vmware.guest.enable = true;"
                } > "$VM_BLOCK"
                offer_nix_injection "VMware guest tools" "$VM_BLOCK"
                rm -f "$VM_BLOCK"
            fi
            ;;
    esac

    # 6) i2c/video groups for external-monitor brightness (ddcutil)
    # NOTE: extraGroups is a list — never define it twice for the same user inside configuration.nix.
    # Clean up duplicate injection from previous buggy runs if present:
    if grep -Eq 'users\.users\."?'"$DETECTED_USER"'"?\.extraGroups[[:space:]]*=[[:space:]]*\[[[:space:]]*"video"[[:space:]]*"i2c"[[:space:]]*\];' "$MAIN_CONF" 2>/dev/null; then
        if [[ $(grep -c "extraGroups" "$MAIN_CONF" 2>/dev/null || echo 0) -gt 1 ]]; then
            sudo sed -i \
                -e '/# Brightness groups (video, i2c) for/d' \
                -e '/users\.users\..*\.extraGroups = \[ "video" "i2c" \];/d' \
                "$MAIN_CONF" 2>/dev/null || true
            ok "Cleaned up duplicate extraGroups definition from $MAIN_CONF"
        fi
    fi

    user_declared=0
    if grep -Eq "users\.users(\.$DETECTED_USER|\.\"$DETECTED_USER\"|[[:space:]]*=[[:space:]]*\{[^}]*\"?$DETECTED_USER\"?)" "$MAIN_CONF" 2>/dev/null; then
        user_declared=1
    fi

    if id -nG "$DETECTED_USER" 2>/dev/null | grep -qw i2c || grep -q '"i2c"' "$MAIN_CONF" 2>/dev/null; then
        ok "User $DETECTED_USER brightness groups (video, i2c) already configured"
    elif [[ "$user_declared" -eq 1 ]]; then
        to_add=""
        if ! grep -q '"video"' "$MAIN_CONF" 2>/dev/null; then to_add="$to_add \"video\""; fi
        if ! grep -q '"i2c"' "$MAIN_CONF" 2>/dev/null; then to_add="$to_add \"i2c\""; fi

        if [[ -n "$to_add" ]] && grep -Eq 'extraGroups[[:space:]]*=[[:space:]]*\[' "$MAIN_CONF" 2>/dev/null; then
            if confirm "Add brightness groups ($to_add) to $DETECTED_USER's extraGroups in configuration.nix?"; then
                backup_if_exists "$MAIN_CONF"
                sudo sed -i -E "s/(extraGroups[[:space:]]*=[[:space:]]*\[)/\1$to_add/" "$MAIN_CONF"
                ok "Added$to_add to extraGroups in $MAIN_CONF"
            else
                warn "Brightness groups not added — you can add them manually to extraGroups."
            fi
        else
            warn "User $DETECTED_USER is declared in your configuration but not in the i2c group."
            info "Add \"video\" and \"i2c\" to their extraGroups for external-monitor brightness (ddcutil)."
        fi
    else
        GRP_BLOCK="$(mktemp)"
        cat > "$GRP_BLOCK" <<EOF
  # User declared by install.sh — 'video' and 'i2c' enable monitor brightness (ddcutil)
  users.users."$DETECTED_USER" = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" "i2c" ];
  };
EOF
        offer_nix_injection "user $DETECTED_USER (with brightness groups)" "$GRP_BLOCK"
        rm -f "$GRP_BLOCK"
    fi

    # 7) Optional Kira mascot art pack and desktop companion
    if ! grep -q "programs.inir.mascot.enable" "$MAIN_CONF" 2>/dev/null; then
        echo
        info "Kira is the official iNiR desktop companion mascot."
        info "She peeks from screen edges, reacts to music/volume/battery events, and has mini-games."
        want_mascot=0
        if [[ "$ENABLE_MASCOT" == "1" ]]; then
            want_mascot=1
        elif [[ "$ENABLE_MASCOT" == "0" ]]; then
            want_mascot=0
        elif confirm "Download and enable Kira mascot (animated companion & widgets)?"; then
            want_mascot=1
        fi

        if [[ "$want_mascot" -eq 1 ]]; then
            MASCOT_BLOCK="$(mktemp)"
            cat > "$MASCOT_BLOCK" <<'EOF'
  # Official iNiR Kira mascot art pack & companion
  programs.inir.mascot.enable = true;
EOF
            if [[ "$DRY_RUN" -eq 1 ]]; then
                dry_run_msg "Would inject into configuration.nix (Kira mascot art pack):"
                while IFS= read -r line; do printf '      %s\n' "$line"; done < "$MASCOT_BLOCK"
            else
                if inject_into_configuration_nix "$MASCOT_BLOCK"; then
                    ok "Kira mascot enabled in configuration.nix"
                else
                    warn "Could not inject mascot configuration automatically."
                fi
            fi
            rm -f "$MASCOT_BLOCK"
        else
            info "Kira mascot skipped (you can enable it later with 'programs.inir.mascot.enable = true;')"
        fi
    fi
fi

# ============================================================
# 5. Niri & user configs
# ============================================================

step "5/7 · Niri configuration and user scripts"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$TARGET_HOME/.config/niri" \
             "$TARGET_HOME/.config/alacritty" \
             "$TARGET_HOME/.local/bin" \
             "$TARGET_HOME/.config/systemd/user" \
             "$TARGET_HOME/Pictures/Wallpapers" \
             "$TARGET_HOME/.local/state/quickshell/user/generated"
fi

backup_if_exists "$TARGET_HOME/.config/niri/config.kdl"
run "Install Niri config" \
    cp "$REPO_DIR/niri/config.kdl" "$TARGET_HOME/.config/niri/config.kdl"

if [[ "$DRY_RUN" -eq 0 && -n "$DETECTED_LAYOUT" ]]; then
    if [[ "$DETECTED_LAYOUT" == "us" ]]; then
        sed -i 's/layout "latam,us"/layout "us"/' "$TARGET_HOME/.config/niri/config.kdl" 2>/dev/null || true
        debug "Adapted Niri keyboard layout to: us"
    elif [[ "$DETECTED_LAYOUT" != "latam" ]]; then
        sed -i "s/layout \"latam,us\"/layout \"$DETECTED_LAYOUT,us\"/" \
            "$TARGET_HOME/.config/niri/config.kdl" 2>/dev/null || true
        debug "Adapted Niri keyboard layout to: $DETECTED_LAYOUT,us"
    fi
fi

if [[ -f "$REPO_DIR/alacritty/alacritty.toml" ]]; then
    if [[ ! -f "$TARGET_HOME/.config/alacritty/alacritty.toml" ]]; then
        run "Install default Alacritty configuration" \
            cp "$REPO_DIR/alacritty/alacritty.toml" "$TARGET_HOME/.config/alacritty/alacritty.toml"
    else
        debug "Preserving existing ~/.config/alacritty/alacritty.toml"
    fi
fi

run "Install niri-sync-colors" \
    cp "$REPO_DIR/scripts/niri-sync-colors" "$TARGET_HOME/.local/bin/niri-sync-colors"
run "Make niri-sync-colors executable" \
    chmod +x "$TARGET_HOME/.local/bin/niri-sync-colors"

# Seed initial colors into Niri and Alacritty immediately so the desktop is ready
if [[ "$DRY_RUN" -eq 0 ]]; then
    "$TARGET_HOME/.local/bin/niri-sync-colors" >>"$LOG_FILE" 2>&1 || true
    ok "Initial color theme seeded (Niri + Alacritty + GTK)"
fi

if [[ -f "$REPO_DIR/systemd/niri-sync-colors.service" ]]; then
    run "Install color-sync systemd service" \
        cp "$REPO_DIR/systemd/niri-sync-colors.service" \
           "$TARGET_HOME/.config/systemd/user/niri-sync-colors.service"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        systemctl --user daemon-reload >>"$LOG_FILE" 2>&1 || true
    fi
    # Do NOT start it here: before the rebuild the prerequisites (inir,
    # inotifywait) do not exist yet and the service would crash-loop.
    info "Color-sync service installed — it activates after the rebuild."
fi

if [[ -f "$REPO_DIR/scripts/record-screen" ]]; then
    run "Install record-screen (recording with audio)" \
        cp "$REPO_DIR/scripts/record-screen" "$TARGET_HOME/.local/bin/record-screen"
    run "Make record-screen executable" \
        chmod +x "$TARGET_HOME/.local/bin/record-screen"

    if [[ "$DRY_RUN" -eq 0 ]]; then
        for rc_file in "$TARGET_HOME/.bashrc" "$TARGET_HOME/.zshrc" "$TARGET_HOME/.config/fish/config.fish"; do
            [[ -f "$rc_file" ]] || continue
            if [[ "$rc_file" == *fish ]]; then
                grep -q "record-screen" "$rc_file" 2>/dev/null || \
                    printf '\n# Screen recording with audio\nalias record="record-screen"\nalias record-fullscreen="record-screen --fullscreen"\nalias record-stop="record-screen --stop"\n' >> "$rc_file"
            else
                grep -q "record-screen" "$rc_file" 2>/dev/null || cat >> "$rc_file" <<'EOF'

# Grabación de pantalla con audio permanente
alias record='record-screen'
alias record-fullscreen='record-screen --fullscreen'
alias record-stop='record-screen --stop'
EOF
            fi
            debug "Recording aliases ensured in $rc_file"
        done
    else
        dry_run_msg "Would add record aliases to shell configs"
    fi

    # Ensure pactl is available for wf-recorder audio mixing
    if [[ "$DRY_RUN" -eq 0 ]] && ! command -v pactl >/dev/null 2>&1; then
        PACTL_STORE="$(find /nix/store -maxdepth 3 -name "pactl" -type f -perm -111 2>/dev/null | grep -E 'pulseaudio-[0-9]' | head -n1 || true)"
        [[ -n "$PACTL_STORE" ]] && ln -sf "$PACTL_STORE" "$TARGET_HOME/.local/bin/pactl" 2>/dev/null || true
    fi

    # Prefer software encoding to avoid VAAPI crashes on some GPUs
    if [[ "$DRY_RUN" -eq 0 ]]; then
        USER_CONFIG="$TARGET_HOME/.config/illogical-impulse/config.json"
        if [[ -f "$USER_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
            if [[ "$(jq -r '.screenRecord.accelerationMode // empty' "$USER_CONFIG" 2>/dev/null)" == "auto" ]]; then
                jq '.screenRecord.accelerationMode = "software"' "$USER_CONFIG" > "${USER_CONFIG}.tmp" \
                    && mv "${USER_CONFIG}.tmp" "$USER_CONFIG"
                debug "screenRecord.accelerationMode set to software"
            fi
        fi
    fi
fi

# Ensure user files belong to the user if running with sudo
if [[ "$DRY_RUN" -eq 0 && "$EUID" -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    local_gid="$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")"
    chown -R "$TARGET_USER:$local_gid" \
        "$TARGET_HOME/.config/niri" \
        "$TARGET_HOME/.local/bin" \
        "$TARGET_HOME/.config/systemd/user" 2>/dev/null || true
fi

# ============================================================
# 6. AI configuration review (optional)
# ============================================================

step "6/7 · AI configuration review (optional)"

# The AI reviews the resulting configuration and adapts recommendations to
# this machine: GPU quirks, VM pitfalls, leftover conflicts, etc.
# It runs ONLY with user consent and NEVER modifies files without a diff
# shown in the log. Everything it prints is appended to the log file.

AI_KIND=""      # installed | temp | ""
AI_RUNNER=()    # command + prefix args used to invoke the AI CLI
if [[ "$NO_AI" -eq 0 ]]; then
    if command -v claude >/dev/null 2>&1; then
        AI_KIND="installed"; AI_RUNNER=(claude)
    elif command -v gemini >/dev/null 2>&1; then
        AI_KIND="installed"; AI_RUNNER=(gemini)
    elif command -v npx >/dev/null 2>&1; then
        # Downloaded on the fly into the npx cache — nothing installed permanently.
        AI_KIND="temp"; AI_RUNNER=(npx -y @anthropic-ai/claude-code)
    elif command -v nix >/dev/null 2>&1; then
        # Pure NixOS fallback: node+npx come from an ephemeral nix shell.
        AI_KIND="temp"; AI_RUNNER=(nix --extra-experimental-features "nix-command flakes" shell nixpkgs#nodejs -c npx -y @anthropic-ai/claude-code)
    fi
fi

if [[ "$NO_AI" -eq 1 ]]; then
    info "AI review skipped (--no-ai)."
elif [[ -z "$AI_KIND" ]]; then
    info "No AI CLI available and none can be fetched (npx/nix missing). Skipping — optional."
else
    if [[ "$AI_KIND" == "installed" ]]; then
        section_note "AI CLI found: ${AI_RUNNER[0]}. It will REVIEW the resulting"
    else
        section_note "No AI CLI installed: it will be downloaded TEMPORARILY (npx/nix cache;"
        section_note "nothing installed permanently). It reuses your existing claude login/API key."
    fi
    section_note "configuration for conflicts and machine-specific pitfalls."
    section_note "It is read-only: suggestions are printed and logged, nothing is changed."

    if confirm "Run AI configuration review now?"; then
        AI_PROMPT="Analiza esta configuración de NixOS para el escritorio iNiR + Niri.
Detecta conflictos, dependencias faltantes y problemas específicos de esta
máquina (GPU: $DETECTED_GPU, VM: $IS_VM, display manager elegido: $CHOSEN_DM,
usuario: $DETECTED_USER). Responde en máximo 15 líneas, con viñetas concisas:
1) problemas críticos que romperían la sesión niri o iNiR
2) mejoras recomendadas
3) si todo está bien, dilo explícitamente.
Archivos clave: /etc/nixos/configuration.nix, /etc/nixos/flake.nix,
/etc/nixos/modules/*.nix, ~/.config/niri/config.kdl"

        info "Running AI review via ${AI_RUNNER[0]} (this may take a minute; the first npx run downloads the CLI)..."
        echo
        if [[ "${AI_RUNNER[0]}" == "gemini" ]]; then
            gemini -p "$AI_PROMPT" 2>&1 | tee -a "$LOG_FILE" || \
                warn "AI review failed (non-fatal). Continuing."
        else
            # -p: non-interactive print mode; --allowedTools "" = read-only, no edits, no commands
            "${AI_RUNNER[@]}" -p "$AI_PROMPT" \
                --allowedTools "" --max-turns 1 2>&1 | tee -a "$LOG_FILE" || \
                warn "AI review failed (non-fatal). Continuing."
        fi
        echo
        ok "AI review finished (output saved to log)"
    else
        info "AI review skipped by user."
    fi
fi

# ============================================================
# 7. NixOS rebuild
# ============================================================

step "7/7 · Apply NixOS configuration"

REBUILD_TARGET="/etc/nixos"
FLAKE_SHOW="$(nix --extra-experimental-features "nix-command flakes" flake show /etc/nixos 2>/dev/null || true)"
if [[ -n "$DETECTED_HOSTNAME" && "$FLAKE_SHOW" == *"$DETECTED_HOSTNAME"* ]]; then
    REBUILD_TARGET="/etc/nixos#$DETECTED_HOSTNAME"
elif [[ "$FLAKE_SHOW" == *"nixos"* ]]; then
    REBUILD_TARGET="/etc/nixos#nixos"
elif [[ "$FLAKE_SHOW" == *"default"* ]]; then
    REBUILD_TARGET="/etc/nixos#default"
elif [[ -n "$DETECTED_HOSTNAME" ]]; then
    REBUILD_TARGET="/etc/nixos#$DETECTED_HOSTNAME"
else
    REBUILD_TARGET="/etc/nixos#default"
fi

REBUILD_CMD=(sudo nixos-rebuild switch --flake "$REBUILD_TARGET")

if [[ "$SKIP_REBUILD" -eq 1 ]]; then
    warn "Rebuild skipped (--skip-rebuild)."
    echo "Run manually when ready:"
    printf '    %s\n' "${REBUILD_CMD[*]}"
elif [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_msg "Would run: ${REBUILD_CMD[*]}"
elif confirm "Run nixos-rebuild switch now?"; then
    if [[ "$DRY_RUN" -eq 0 && -d /etc/nixos/.git ]]; then
        sudo git -C /etc/nixos add -A >/dev/null 2>&1 || true
    fi
    info "Building NixOS configuration ($REBUILD_TARGET)..."
    info "This can take several minutes on the first run."
    CURRENT_GEN="$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -oE '[0-9]+' || echo "unknown")"
    REBUILD_START=$(date +%s)
    if "${REBUILD_CMD[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        REBUILD_END=$(date +%s)
        REBUILD_DURATION=$((REBUILD_END - REBUILD_START))
        NEW_GEN="$(readlink /nix/var/nix/profiles/system 2>/dev/null | grep -oE '[0-9]+' || echo "unknown")"
        ok "NixOS rebuild completed successfully in ${REBUILD_DURATION}s (Generation #$CURRENT_GEN → #$NEW_GEN)"
    else
        REBUILD_END=$(date +%s)
        REBUILD_DURATION=$((REBUILD_END - REBUILD_START))
        err "NixOS rebuild failed after ${REBUILD_DURATION}s."
        warn "The running generation (#$CURRENT_GEN) was NOT altered — your system boots safely as before."
        if grep -qi "No space left on device" "$LOG_FILE" 2>/dev/null; then
            err "Diagnostic: Disk space exhausted during build."
            info "Fix: Free space with 'sudo nix-collect-garbage -d' and retry."
        elif grep -qi "untracked files" "$LOG_FILE" 2>/dev/null; then
            err "Diagnostic: Untracked git files in /etc/nixos."
            info "Fix: Stage files with 'sudo git -C /etc/nixos add -A'"
        elif grep -qi "cannot download" "$LOG_FILE" 2>/dev/null; then
            err "Diagnostic: Network failure downloading packages or flake inputs."
            info "Fix: Check internet connection and retry."
        elif grep -qi "already defined" "$LOG_FILE" 2>/dev/null; then
            err "Diagnostic: Duplicate attribute defined in Nix configuration."
            info "Fix: Check /etc/nixos/configuration.nix for duplicate option assignments."
        fi
        echo "  Check the log:   $LOG_FILE"
        echo "  Roll back:       sudo nixos-rebuild switch --rollback"
        exit 1
    fi
else
    warn "NixOS rebuild skipped."
    echo "Run manually when ready:"
    printf '    %s\n' "${REBUILD_CMD[*]}"
fi

# ============================================================
# Post-install verification
# ============================================================

echo
if [[ "$DRY_RUN" -eq 0 && "$SKIP_REBUILD" -eq 0 ]]; then
    step "Post-install verification"

    # Reload systemd user daemon if available
    if systemctl --user daemon-reload >/dev/null 2>&1; then
        systemctl --user daemon-reload >>"$LOG_FILE" 2>&1 || true
    fi

    # Verify that the rebuild installed the Niri and iNiR binaries and session
    niri_found=0
    inir_found=0

    if command -v niri >/dev/null 2>&1 || [[ -x /run/current-system/sw/bin/niri ]]; then
        niri_found=1
    fi
    if command -v inir >/dev/null 2>&1 || [[ -x /run/current-system/sw/bin/inir ]] || [[ -x "$TARGET_HOME/.local/bin/inir" ]]; then
        inir_found=1
    fi

    if [[ "$niri_found" -eq 1 ]]; then
        ok "Niri compositor installed (/run/current-system/sw/bin/niri)"
    else
        info "Niri compositor will be available after reboot"
    fi

    if [[ "$inir_found" -eq 1 ]]; then
        ok "iNiR shell installed"
    else
        info "iNiR shell will be available after reboot"
    fi

    # Check Wayland session entry
    if [[ -f /run/current-system/sw/share/wayland-sessions/niri.desktop ]] \
        || find /run/current-system/sw/share/wayland-sessions/ -name "*niri*.desktop" 2>/dev/null | grep -q .; then
        ok "Niri Wayland session registered"
    fi

    # Apply system and user tmpfiles rules (creates ~/.config/quickshell/inir and symlinks)
    sudo systemd-tmpfiles --create 2>>"$LOG_FILE" || true
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        sudo -u "$TARGET_USER" systemd-tmpfiles --user --create 2>>"$LOG_FILE" || true
    else
        systemd-tmpfiles --user --create 2>>"$LOG_FILE" || true
    fi
    ok "User runtime symlinks ready (~/.config/quickshell/inir, ~/.local/bin)"

    # Enable color-sync service for user autostart
    if [[ -f "$TARGET_HOME/.config/systemd/user/niri-sync-colors.service" ]]; then
        systemctl --user daemon-reload >>"$LOG_FILE" 2>&1 || true
        systemctl --user enable niri-sync-colors.service >>"$LOG_FILE" 2>&1 || true
        ok "Color synchronization service enabled (activates on login)"
    fi

    if [[ "$CHOSEN_DM" == "greetd" ]]; then
        if [[ -f /run/current-system/etc/systemd/system/greetd.service ]] \
            || systemctl list-unit-files 2>/dev/null | grep -q greetd; then
            ok "greetd display manager configured"
        fi
        info "On the login screen, pick 'Niri' (F3 / arrow keys) to start."
    else
        info "On the GDM login screen, click the gear ⚙ icon and select 'Niri'."
    fi
fi

# ============================================================
# Final banner
# ============================================================

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s%s╔══════════════════════════════════════════════════════╗%s\n' "$BOLD" "$BLUE" "$RESET"
    printf '%s%s║          ✨  Dry-run completed — no changes          ║%s\n' "$BOLD" "$BLUE" "$RESET"
    printf '%s%s╚══════════════════════════════════════════════════════╝%s\n' "$BOLD" "$BLUE" "$RESET"
else
    printf '%s%s╔══════════════════════════════════════════════════════╗%s\n' "$BOLD" "$GREEN" "$RESET"
    printf '%s%s║          ✨  Installation complete!                  ║%s\n' "$BOLD" "$GREEN" "$RESET"
    printf '%s%s╚══════════════════════════════════════════════════════╝%s\n' "$BOLD" "$GREEN" "$RESET"
fi
echo
SCRIPT_END_SEC=$(date +%s)
TOTAL_SEC=$((SCRIPT_END_SEC - SCRIPT_START_SEC))
if (( TOTAL_SEC >= 60 )); then
    TIME_STR="$((TOTAL_SEC / 60))m $((TOTAL_SEC % 60))s"
else
    TIME_STR="${TOTAL_SEC}s"
fi
printf '  Time taken:   %s%s%s\n' "$CYAN" "$TIME_STR" "$RESET"
printf '  Diagnostics:  %sbash %s/scripts/verify-setup.sh%s\n' "$BOLD" "$REPO_DIR" "$RESET"
printf '  Log:          %s%s%s\n' "$DIM" "$LOG_FILE" "$RESET"
if [[ -d "$BACKUPS_DIR" ]]; then
    printf '  Backups:      %s%s%s\n' "$DIM" "$BACKUPS_DIR" "$RESET"
fi
echo
printf '  %sUseful commands:%s\n' "$BOLD" "$RESET"
printf '    systemctl --user status inir.service\n'
printf '    systemctl --user status niri-sync-colors.service\n'
printf '    sudo nixos-rebuild switch --flake %s\n' "$REBUILD_TARGET"
printf '    sudo nixos-rebuild switch --rollback        # if the new session misbehaves\n'
printf '    sudo nix-collect-garbage -d                 # free space once everything works\n'
echo
if [[ -d "$BACKUPS_DIR" ]]; then
    printf '  %sNote: backups live in /tmp and are erased on reboot. Copy them somewhere\n' "$YELLOW"
    printf '  permanent first if you want to keep them:%s\n' "$RESET"
    printf '    cp -r %s ~/inir-nixos-backups\n' "$BACKUPS_DIR"
    echo
fi
printf '  %sNext step:%s reboot and pick %sNiri%s at the login screen.\n' \
    "$BOLD" "$RESET" "$BOLD" "$RESET"
echo
