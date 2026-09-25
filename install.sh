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
LOG_FILE="/tmp/inir-nixos-install-${TIMESTAMP}.log"
BACKUPS_DIR="/tmp/inir-nixos-backups-${TIMESTAMP}"

ASSUME_YES=0
DRY_RUN=0
SKIP_REBUILD=0
CHECK_ONLY=0
NO_AI=0

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
  ./install.sh --skip-rebuild
HELP
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y)         ASSUME_YES=1 ;;
        --dry-run)        DRY_RUN=1 ;;
        --skip-rebuild)   SKIP_REBUILD=1 ;;
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

require_command git "git"
require_command nix "nix"
require_command sudo "sudo"

for required in configuration.nix flake.nix niri/config.kdl scripts/niri-sync-colors; do
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
DETECTED_SESSION="$(echo "${XDG_CURRENT_DESKTOP:-}" | cut -d: -f2)"
DETECTED_GPU="unknown"
GPU_MODULES="$(lsmod 2>/dev/null | awk 'BEGIN{r=""} $1=="nvidia"||$1=="nouveau"{r="nvidia"} $1=="i915"||$1=="xe"{r="intel"} $1=="amdgpu"{r="amd"} END{print r}')" || true
if [[ -n "$GPU_MODULES" ]]; then DETECTED_GPU="$GPU_MODULES"; fi
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

# Reset stale AccountsService session (fixes GDM not offering niri)
if [[ "$STALE_ACCOUNTSSERVICE" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would remove stale AccountsService user state"
    else
        sudo rm -f /var/lib/AccountsService/users/* 2>/dev/null || true
        sudo rm -f /var/lib/AccountsService/icons/* 2>/dev/null || true
        ok "Stale AccountsService state cleared (niri will be offered fresh)"
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
    mkdir -p /etc/nixos/modules
    # 1) Update only the iNiR-owned module files (never touch user files)
    for f in audio.nix desktop.nix fonts.nix inir-deps.nix inir.nix runtime.nix default.nix; do
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
            audio.nix|desktop.nix|fonts.nix|inir-deps.nix|inir.nix|runtime.nix|default.nix) ;;
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
        # Required groups for brightness (DDC/CI)
        if ! grep -q '"i2c"' /etc/nixos/configuration.nix 2>/dev/null; then
            warn "Add 'i2c' to your user's extraGroups for external-monitor brightness (ddcutil)."
        fi
    else
        dry_run_msg "Would ensure ./modules is imported in configuration.nix"
    fi
    # Hard guarantee: without this import the whole installer is a no-op.
    if ! grep -Eq '^[^#]*\./modules' /etc/nixos/configuration.nix; then
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

# Niri session file must exist for display managers to list it
if [[ "$DRY_RUN" -eq 0 ]]; then
    if ! grep -q "programs.niri.enable" /etc/nixos/configuration.nix /etc/nixos/modules/inir.nix 2>/dev/null; then
        warn "programs.niri.enable not found — it is enabled by modules/inir.nix (installed above)."
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
        sudo sed -i -E 's|github:nixos/nixpkgs/nixos-[0-9]{2}\.[0-9]{2}|github:nixos/nixpkgs/nixos-unstable|g' /etc/nixos/flake.nix
        ok "flake.nix switched to nixos-unstable"
    fi
fi

# iNiR flake input check
if [[ -f /etc/nixos/flake.nix ]]; then
    if grep -q "snowarch/inir" /etc/nixos/flake.nix; then
        ok "iNiR flake input present"
    else
        warn "iNiR input missing in /etc/nixos/flake.nix. Required:"
        printf '      %s\n' 'inputs.inir.url = "github:snowarch/inir";'
        printf '      %s\n' 'specialArgs = { inherit inir; };'
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

# ============================================================
# 5. Niri & user configs
# ============================================================

step "5/7 · Niri configuration and user scripts"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$TARGET_HOME/.config/niri" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.config/systemd/user"
fi

backup_if_exists "$TARGET_HOME/.config/niri/config.kdl"
run "Install Niri config" \
    cp "$REPO_DIR/niri/config.kdl" "$TARGET_HOME/.config/niri/config.kdl"

if [[ "$DRY_RUN" -eq 0 && "$DETECTED_LAYOUT" != "latam" && -n "$DETECTED_LAYOUT" ]]; then
    sed -i "s/layout \"latam,us\"/layout \"$DETECTED_LAYOUT,us\"/" \
        "$TARGET_HOME/.config/niri/config.kdl" 2>/dev/null || true
    debug "Adapted Niri keyboard layout to: $DETECTED_LAYOUT,us"
fi

run "Install niri-sync-colors" \
    cp "$REPO_DIR/scripts/niri-sync-colors" "$TARGET_HOME/.local/bin/niri-sync-colors"
run "Make niri-sync-colors executable" \
    chmod +x "$TARGET_HOME/.local/bin/niri-sync-colors"

if [[ -f "$REPO_DIR/systemd/niri-sync-colors.service" ]]; then
    run "Install color-sync systemd service" \
        cp "$REPO_DIR/systemd/niri-sync-colors.service" \
           "$TARGET_HOME/.config/systemd/user/niri-sync-colors.service"
    run "Reload systemd user manager" systemctl --user daemon-reload
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

# ============================================================
# 6. AI configuration review (optional)
# ============================================================

step "6/7 · AI configuration review (optional)"

# The AI reviews the resulting configuration and adapts recommendations to
# this machine: GPU quirks, VM pitfalls, leftover conflicts, etc.
# It runs ONLY with user consent and NEVER modifies files without a diff
# shown in the log. Everything it prints is appended to the log file.

AI_BIN=""
if [[ "$NO_AI" -eq 0 ]]; then
    if command -v claude >/dev/null 2>&1; then
        AI_BIN="claude"
    elif command -v gemini >/dev/null 2>&1; then
        AI_BIN="gemini"
    fi
fi

if [[ "$NO_AI" -eq 1 ]]; then
    info "AI review skipped (--no-ai)."
elif [[ -z "$AI_BIN" ]]; then
    info "No AI CLI available (claude/gemini). Skipping — this is optional."
    info "Install claude-code (npm i -g @anthropic-ai/claude-code) to enable it."
else
    section_note "An AI CLI ($AI_BIN) is available. It will REVIEW the resulting"
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

        info "Running $AI_BIN review (this may take a minute)..."
        echo
        if [[ "$AI_BIN" == "claude" ]]; then
            # -p: non-interactive print mode; --allowedTools "" = read-only, no edits, no commands
            claude -p "$AI_PROMPT" \
                --allowedTools "" --max-turns 1 2>&1 | tee -a "$LOG_FILE" || \
                warn "AI review failed (non-fatal). Continuing."
        else
            gemini -p "$AI_PROMPT" 2>&1 | tee -a "$LOG_FILE" || \
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
FLAKE_SHOW="$(nix flake show /etc/nixos 2>/dev/null || true)"
if [[ "$FLAKE_SHOW" == *"$DETECTED_HOSTNAME"* ]]; then
    REBUILD_TARGET="/etc/nixos#$DETECTED_HOSTNAME"
elif [[ "$FLAKE_SHOW" == *"nixos"* ]]; then
    REBUILD_TARGET="/etc/nixos#nixos"
fi

REBUILD_CMD=(sudo nixos-rebuild switch --flake "$REBUILD_TARGET")

if [[ "$SKIP_REBUILD" -eq 1 ]]; then
    warn "Rebuild skipped (--skip-rebuild)."
    echo "Run manually when ready:"
    printf '    %s\n' "${REBUILD_CMD[*]}"
elif [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_msg "Would run: ${REBUILD_CMD[*]}"
elif confirm "Run nixos-rebuild switch now?"; then
    info "Building NixOS configuration ($REBUILD_TARGET)..."
    info "This can take several minutes on the first run."
    if "${REBUILD_CMD[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        ok "NixOS rebuild completed successfully"
    else
        err "NixOS rebuild failed."
        warn "The previous NixOS generation remains active."
        echo "  Check the log: $LOG_FILE"
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

    systemctl --user daemon-reload || true
    systemctl --user restart inir.service 2>/dev/null || true
    systemctl --user restart niri-sync-colors.service 2>/dev/null || true
    sleep 2

    if systemctl --user is-active --quiet inir.service; then
        ok "inir.service is active"
    else
        warn "inir.service not active — it starts on login to a Niri session."
    fi
    if systemctl --user is-active --quiet niri-sync-colors.service; then
        ok "niri-sync-colors.service is active"
    fi

    # Verify the rebuild actually produced a system with iNiR + niri session
    local_missing=()
    if ! systemctl list-unit-files 2>/dev/null | grep -q "inir.service"; then
        local_missing+=("inir.service (the rebuild did not apply the iNiR modules)")
    fi
    if [[ ! -f /run/current-system/sw/share/wayland-sessions/niri.desktop ]]; then
        local_missing+=("niri Wayland session (programs.niri.enable did not take effect)")
    fi
    if [[ ${#local_missing[@]} -gt 0 ]]; then
        err "Rebuild finished but required pieces are MISSING:"
        for m in "${local_missing[@]}"; do
            printf '      %s%s%s\n' "$RED" "$m" "$RESET"
        done
        warn "Most common cause: /etc/nixos/configuration.nix does not import ./modules,"
        warn "or /etc/nixos is not the flake that was rebuilt."
        info "Verify with: ls /run/current-system/sw/share/wayland-sessions/ && systemctl list-unit-files | grep inir"
    else
        ok "iNiR service and niri session present after rebuild"
    fi

    # Verify the chosen display manager + niri session file
    if [[ -f /run/current-system/sw/share/wayland-sessions/niri.desktop ]]; then
        ok "niri Wayland session registered"
    fi

    # Now that iNiR exists, activate the color-sync service
    if systemctl list-unit-files 2>/dev/null | grep -q "inir.service"; then
        run "Enable color synchronization (post-rebuild)" \
            systemctl --user enable --now niri-sync-colors.service
    fi

    if [[ "$CHOSEN_DM" == "greetd" ]]; then
        if [[ -f /run/current-system/etc/systemd/system/greetd.service ]] \
            || systemctl status greetd.service >/dev/null 2>&1; then
            ok "greetd is installed as the display manager"
        else
            warn "greetd not detected — did the rebuild finish?"
        fi
        info "On the login screen pick 'Niri' with F3 / arrow keys if needed."
    else
        if [[ "$RECOMMEND_GREETD" -eq 1 ]]; then
            warn "You chose GDM despite the recommendation."
            warn "If niri does NOT appear at the login screen after reboot:"
            info "  1) Press Ctrl+Alt+F3, log in on TTY"
            info "  2) Edit /etc/nixos/modules/desktop.nix → displayManager = \"greetd\";"
            info "  3) sudo nixos-rebuild switch --flake $REBUILD_TARGET"
        fi
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
echo
printf '  %sNext step:%s reboot and pick %sNiri%s at the login screen.\n' \
    "$BOLD" "$RESET" "$BOLD" "$RESET"
echo
