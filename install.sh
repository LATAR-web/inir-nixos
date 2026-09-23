#!/usr/bin/env bash
#
# iNiR + Niri + NixOS
# Automated installer [EXPERIMENTAL] for:
#   https://github.com/LATAR-web/inir-nixos
#
# Usage:
#   ./install.sh
#   ./install.sh --yes
#   ./install.sh --dry-run
#   ./install.sh --skip-rebuild
#   ./install.sh --check
#   ./install.sh --help
#

set -Eeuo pipefail

# ============================================================
# Paths
# ============================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/inir-nixos-install-${TIMESTAMP}.log"

# ============================================================
# Options
# ============================================================

ASSUME_YES=0
DRY_RUN=0
SKIP_REBUILD=0
CHECK_ONLY=0

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
        --yes|-y)
            ASSUME_YES=1
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        --skip-rebuild)
            SKIP_REBUILD=1
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        --help|-h)
            usage
            exit 0
            ;;
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

if [[ ! -t 1 ]]; then
    COLOR=0
fi

if [[ "${NO_COLOR:-}" != "" ]]; then
    COLOR=0
fi

if [[ "${TERM:-}" == "dumb" ]]; then
    COLOR=0
fi

if [[ "$COLOR" -eq 1 ]]; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'

    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    MAGENTA=$'\033[35m'
    CYAN=$'\033[36m'
    WHITE=$'\033[37m'

    BG_RED=$'\033[41m'
    BG_GREEN=$'\033[42m'
    BG_BLUE=$'\033[44m'
    BG_YELLOW=$'\033[43m'
else
    RESET=''
    BOLD=''
    DIM=''

    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''

    BG_RED=''
    BG_GREEN=''
    BG_BLUE=''
    BG_YELLOW=''
fi

# ============================================================
# Logging
# ============================================================

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    printf '%s\n' "$1" >> "$LOG_FILE"
}

info() {
    printf '  %s→%s %s\n' "$BLUE" "$RESET" "$1"
    log "INFO: $1"
}

success() {
    printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"
    log "OK: $1"
}

warning() {
    printf '  %s⚠%s %s\n' "$YELLOW" "$RESET" "$1"
    log "WARN: $1"
}

error() {
    printf '  %s✗%s %s\n' "$RED" "$RESET" "$1" >&2
    log "ERROR: $1"
}

step() {
    echo
    printf '%s%s%s\n' "$BOLD" "$1" "$RESET"
    log "STEP: $1"
}

debug() {
    printf '  %s%s%s\n' "$DIM" "$1" "$RESET"
    log "DEBUG: $1"
}

dry_run_msg() {
    printf '  %s[dry-run]%s %s\n' "$YELLOW" "$RESET" "$1"
    log "DRY-RUN: $1"
}

separator() {
    printf '%s────────────────────────────────────────────────────────%s\n' \
        "$DIM" "$RESET"
}

# ============================================================
# Error handling
# ============================================================

FAILED=0

on_error() {
    local line="$1"

    if [[ "$FAILED" -eq 1 ]]; then
        exit 1
    fi

    FAILED=1

    echo
    error "Installation failed at line $line."
    error "Full log: $LOG_FILE"
    exit 1
}

trap 'on_error "$LINENO"' ERR
trap 'echo; warning "Installation cancelled by user."; exit 130' INT TERM

# ============================================================
# Helpers
# ============================================================

run() {
    local description="$1"
    shift

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "$description"
        debug "Command: $*"
        return 0
    fi

    log "RUN: $*"

    if "$@" >>"$LOG_FILE" 2>&1; then
        success "$description"
    else
        error "$description failed."
        error "Check: $LOG_FILE"
        return 1
    fi
}

confirm() {
    local prompt="$1"

    if [[ "$ASSUME_YES" -eq 1 ]]; then
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 0
    fi

    printf '%s [y/N] ' "$prompt"

    local reply
    read -r reply

    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

backup_if_exists() {
    local target="$1"

    [[ -e "$target" || -L "$target" ]] || return 0

    local backup="${target}.bak.${TIMESTAMP}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would backup:"
        printf '      %s → %s\n' "$target" "$backup"
        return 0
    fi

    local copy_cmd=(cp -a)

    if [[ "$target" == "/etc/nixos" || "$target" == /etc/nixos/* ]]; then
        copy_cmd=(sudo cp -a)
    fi

    if "${copy_cmd[@]}" "$target" "$backup"; then
        warning "Backup created:"
        printf '      %s → %s\n' "$target" "$backup"
        log "BACKUP: $target -> $backup"
    else
        error "Could not backup $target"
        return 1
    fi
}

require_command() {
    local command="$1"
    local package_hint="${2:-}"

    if command -v "$command" >/dev/null 2>&1; then
        success "$command available"
        return 0
    fi

    error "$command is not installed."

    if [[ -n "$package_hint" ]]; then
        echo "      Suggested package: $package_hint"
    fi

    return 1
}

# ============================================================
# Header
# ============================================================

printf '\n'
printf '%s%s╔══════════════════════════════════════════════════════╗%s\n' \
    "$BOLD" "$CYAN" "$RESET"
printf '%s%s║              iNiR + Niri + NixOS                  ║%s\n' \
    "$BOLD" "$CYAN" "$RESET"
printf '%s%s║       Automated Modular Installer [EXPERIMENTAL]   ║%s\n' \
    "$BOLD" "$CYAN" "$RESET"
printf '%s%s╚══════════════════════════════════════════════════════╝%s\n' \
    "$BOLD" "$CYAN" "$RESET"
printf '\n'

printf 'Repository: %shttps://github.com/LATAR-web/inir-nixos%s\n' \
    "$BLUE" "$RESET"

printf 'Installer:  %s%s%s\n' "$DIM" "$REPO_DIR" "$RESET"
printf 'Log file:   %s%s%s\n' "$DIM" "$LOG_FILE" "$RESET"

echo
printf '%s%s ⚠️  EXPERIMENTAL SETUP %s\n' "$BG_YELLOW" "$WHITE" "$RESET"
printf '  This installer modifies your NixOS configuration and systemd user services.\n'
printf '  Existing configurations are backed up with timestamps (.bak.<date>).\n'

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    printf '%s%s DRY-RUN MODE %s\n' "$BG_BLUE" "$WHITE" "$RESET"
    printf 'No system changes will be made.\n'
fi

# ============================================================
# 0. Pre-flight
# ============================================================

step "0/6 — Pre-flight checks"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    exec bash "$REPO_DIR/scripts/verify-setup.sh"
fi

if [[ ! -d /etc/nixos ]]; then
    error "/etc/nixos does not exist."
    error "This installer requires NixOS."
    exit 1
fi

success "/etc/nixos exists"

if [[ ! -f /etc/NIXOS ]]; then
    warning "/etc/NIXOS was not found."
    warning "Continuing because /etc/nixos exists."
fi

# Only require tools needed to run the installer and rebuild.
# Runtime packages (python3, jq, inotifywait, etc.) are installed
# by NixOS modules during the rebuild and checked post-rebuild.
require_command git "git"
require_command nix "nix"
require_command sudo "sudo"

if [[ ! -f "$REPO_DIR/configuration.nix" ]]; then
    error "Missing configuration.nix in repository."
    exit 1
fi

if [[ ! -f "$REPO_DIR/flake.nix" ]]; then
    error "Missing flake.nix in repository."
    exit 1
fi

if [[ ! -d "$REPO_DIR/modules" ]]; then
    error "Missing modules/ directory in repository."
    exit 1
fi

if [[ ! -f "$REPO_DIR/niri/config.kdl" ]]; then
    error "Missing niri/config.kdl."
    exit 1
fi

if [[ ! -f "$REPO_DIR/scripts/niri-sync-colors" ]]; then
    error "Missing scripts/niri-sync-colors."
    exit 1
fi

success "Repository structure looks valid"

if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_msg "Would validate the Nix flake:"
    printf '      nix flake check --no-write-lock-file "%s"\n' "$REPO_DIR"
else
    info "Validating Nix flake..."

    if nix --extra-experimental-features "nix-command flakes" \
        flake check --no-write-lock-file "$REPO_DIR"; then
        success "Nix flake validation passed"
    else
        error "Nix flake validation failed."
        error "Run manually:"
        printf '      nix flake check --no-write-lock-file "%s"\n' "$REPO_DIR"
        exit 1
    fi
fi

# ============================================================
# 1. Detect target user and machine settings
# ============================================================

step "1/6 — Detecting environment and user configuration"

if [[ "$EUID" -eq 0 && -z "${SUDO_USER:-}" ]]; then
    warning "Running directly as root."
    warning "It is recommended to run ./install.sh as your normal user (sudo is used when needed)."
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

# If /etc/nixos/configuration.nix already defines these, respect them!
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

info "Target User:     $DETECTED_USER (home: $TARGET_HOME)"
info "Hostname:        $DETECTED_HOSTNAME"
info "Timezone:        $DETECTED_TZ"
info "Locale:          $DETECTED_LOCALE"
info "Keyboard Layout: $DETECTED_LAYOUT"

if [[ "$ASSUME_YES" -ne 1 && "$DRY_RUN" -ne 1 ]]; then
    if ! confirm "Confirm detected settings for configuration?"; then
        read -rp "Username [$DETECTED_USER]: " _u
        read -rp "Hostname [$DETECTED_HOSTNAME]: " _h
        read -rp "Timezone [$DETECTED_TZ]: " _t
        read -rp "Locale [$DETECTED_LOCALE]: " _loc
        read -rp "Keyboard layout [$DETECTED_LAYOUT]: " _l
        [[ -n "$_u" ]] && DETECTED_USER="$_u"
        [[ -n "$_h" ]] && DETECTED_HOSTNAME="$_h"
        [[ -n "$_t" ]] && DETECTED_TZ="$_t"
        [[ -n "$_loc" ]] && DETECTED_LOCALE="$_loc"
        [[ -n "$_l" ]] && DETECTED_LAYOUT="$_l"
    fi
fi

# ============================================================
# 2. Stray inir.service check & obsolete service cleanup
# ============================================================

step "2/6 — Checking for stray and obsolete user services"

STRAY_SERVICE="$TARGET_HOME/.config/systemd/user/inir.service"

if [[ -e "$STRAY_SERVICE" ]]; then
    warning "$STRAY_SERVICE exists."
    warning "This file silently overrides the NixOS declarative service in"
    warning "/etc/systemd/user/ — preventing inir from running properly."
    warning "(Usually generated mistakenly by running 'inir doctor')."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would remove: $STRAY_SERVICE"
    elif confirm "Remove stray inir.service now?"; then
        rm -f "$STRAY_SERVICE"
        rm -f "$TARGET_HOME/.config/systemd/user/inir.service.d/"*.conf 2>/dev/null || true
        success "Stray service file removed"
    else
        warning "Leaving it in place — this will cause inir service conflicts."
    fi
else
    success "No stray inir.service found"
fi

# Clean up obsolete niri-color-sync service if present (replaced by niri-sync-colors)
OLD_COLOR_SERVICE="$TARGET_HOME/.config/systemd/user/niri-color-sync.service"
if [[ -e "$OLD_COLOR_SERVICE" ]]; then
    systemctl --user stop niri-color-sync.service 2>/dev/null || true
    systemctl --user disable niri-color-sync.service 2>/dev/null || true
    rm -f "$OLD_COLOR_SERVICE" "$TARGET_HOME/.local/bin/sync-niri-colors.sh" 2>/dev/null || true
    success "Removed obsolete niri-color-sync service"
fi

# Clean up obsolete xwayland-satellite service if present (niri manages xwayland natively)
OLD_XWAYLAND_SERVICE="$TARGET_HOME/.config/systemd/user/xwayland-satellite.service"
if [[ -e "$OLD_XWAYLAND_SERVICE" || -e "$TARGET_HOME/.config/systemd/user/graphical-session.target.wants/xwayland-satellite.service" ]]; then
    systemctl --user stop xwayland-satellite.service 2>/dev/null || true
    systemctl --user disable xwayland-satellite.service 2>/dev/null || true
    rm -f "$OLD_XWAYLAND_SERVICE" "$TARGET_HOME/.config/systemd/user/graphical-session.target.wants/xwayland-satellite.service" 2>/dev/null || true
    success "Removed obsolete xwayland-satellite service"
fi

# Clean up obsolete update services/timers if present
for obsolete_unit in check-config-updates.timer check-config-updates.service auto-update.timer auto-update.service; do
    if [[ -e "$TARGET_HOME/.config/systemd/user/$obsolete_unit" || -e "$TARGET_HOME/.config/systemd/user/timers.target.wants/$obsolete_unit" ]]; then
        systemctl --user stop "$obsolete_unit" 2>/dev/null || true
        systemctl --user disable "$obsolete_unit" 2>/dev/null || true
        rm -f "$TARGET_HOME/.config/systemd/user/$obsolete_unit" "$TARGET_HOME/.config/systemd/user/timers.target.wants/$obsolete_unit" 2>/dev/null || true
        rm -f "$TARGET_HOME/.local/bin/check-config-updates.sh" "$TARGET_HOME/.local/bin/auto-update.sh" 2>/dev/null || true
        success "Removed obsolete $obsolete_unit"
    fi
done

# ============================================================
# 3. System configuration (NixOS modules)
# ============================================================

step "3/6 — System configuration → /etc/nixos"

echo
printf '%sInstalling iNiR modules to /etc/nixos/modules...%s\n' "$BOLD" "$RESET"
echo "  • Preserves existing user packages, settings, and users"
echo "  • Adapts to your current configuration without overwriting it"
echo "  • GNOME fallback is disabled by default to eliminate system bloat"
echo

if [[ "$DRY_RUN" -eq 0 ]]; then
    backup_if_exists "/etc/nixos/modules"
    sudo rm -rf /etc/nixos/modules
    sudo cp -a "$REPO_DIR/modules" /etc/nixos/modules
    success "Installed iNiR modules to /etc/nixos/modules"
else
    dry_run_msg "Would install iNiR modules to /etc/nixos/modules"
fi

if [[ -f /etc/nixos/configuration.nix ]]; then
    info "Existing /etc/nixos/configuration.nix detected."
    info "Adapting your existing configuration (user packages and apps preserved)..."

    backup_if_exists "/etc/nixos/configuration.nix"

    if [[ "$DRY_RUN" -eq 0 ]]; then
        if grep -Eq '(\./modules|modules/inir)' /etc/nixos/configuration.nix; then
            success "./modules is already imported in /etc/nixos/configuration.nix"
        else
            if grep -Eq 'imports\s*=\s*\[' /etc/nixos/configuration.nix; then
                sudo sed -i -E 's|(imports\s*=\s*\[)|\1\n    ./modules|' /etc/nixos/configuration.nix
                success "Added ./modules to imports in /etc/nixos/configuration.nix"
            else
                warning "Could not automatically inject ./modules into imports."
                info "Please add './modules' to imports in /etc/nixos/configuration.nix manually."
            fi
        fi

        # Check required user groups for monitor brightness control (DDC/CI)
        if ! grep -q "i2c" /etc/nixos/configuration.nix 2>/dev/null || ! grep -q "video" /etc/nixos/configuration.nix 2>/dev/null; then
            warning "Notice: Monitor brightness control (DDC/CI via ddcutil) requires groups 'video' and 'i2c'."
            info "Make sure your user has 'video' and 'i2c' in extraGroups in /etc/nixos/configuration.nix."
        fi
    else
        dry_run_msg "Would add ./modules to imports in /etc/nixos/configuration.nix"
    fi
else
    info "No existing configuration.nix found. Installing reference configuration..."
    backup_if_exists "/etc/nixos/configuration.nix"
    run "Install configuration.nix" \
        sudo cp -a "$REPO_DIR/configuration.nix" /etc/nixos/configuration.nix

    if [[ "$DRY_RUN" -eq 0 ]]; then
        sudo sed -i \
            -e "s/\"YOUR_USERNAME\"/\"$DETECTED_USER\"/g" \
            -e "s/networking.hostName = \"nixos\";/networking.hostName = \"$DETECTED_HOSTNAME\";/" \
            -e "s#time.timeZone = \"America/Mexico_City\";#time.timeZone = \"$DETECTED_TZ\";#" \
            -e "s/i18n.defaultLocale = \"es_MX.UTF-8\";/i18n.defaultLocale = \"$DETECTED_LOCALE\";/" \
            /etc/nixos/configuration.nix
        success "Configured reference configuration.nix with detected values"
    else
        dry_run_msg "Would substitute username/hostname/timezone/locale into configuration.nix"
    fi
fi

if [[ -f /etc/nixos/flake.nix ]]; then
    info "Existing /etc/nixos/flake.nix detected."
    if grep -q "snowarch/inir" /etc/nixos/flake.nix; then
        success "iNiR flake input is already configured in /etc/nixos/flake.nix"
    else
        warning "iNiR input not detected in /etc/nixos/flake.nix."
        info "Make sure your flake.nix includes the inir input and passes it in specialArgs:"
        printf '      inputs.inir.url = "github:snowarch/inir";\n'
        printf '      specialArgs = { inherit inir; };\n'
    fi
else
    info "No flake.nix found. Installing reference flake.nix..."
    backup_if_exists "/etc/nixos/flake.nix"
    run "Install flake.nix" \
        sudo cp -a "$REPO_DIR/flake.nix" /etc/nixos/flake.nix

    if [[ "$DRY_RUN" -eq 0 ]]; then
        if [[ "$DETECTED_HOSTNAME" != "nixos" ]]; then
            sudo sed -i \
                -e "s/nixosConfigurations\.nixos/nixosConfigurations.\"$DETECTED_HOSTNAME\"/g" \
                /etc/nixos/flake.nix 2>/dev/null || true
        fi
    fi
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ -d /etc/nixos/.git ]]; then
        info "Staging installed files in /etc/nixos git repo..."
        sudo git -C /etc/nixos add -A || true
    fi
fi

if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    info "No hardware-configuration.nix found."

    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run_msg "Would generate hardware-configuration.nix"
    elif confirm "Generate hardware-configuration.nix for this machine?"; then
        if sudo nixos-generate-config \
            --show-hardware-config |
            sudo tee /etc/nixos/hardware-configuration.nix >/dev/null; then
            success "hardware-configuration.nix generated"
        else
            error "Could not generate hardware-configuration.nix"
            exit 1
        fi
    else
        warning "Hardware configuration generation skipped."
    fi
else
    success "Existing hardware-configuration.nix preserved"
fi

# ============================================================
# 4. Niri configuration
# ============================================================

step "4/6 — Niri configuration"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$TARGET_HOME/.config/niri"
else
    dry_run_msg "Would create $TARGET_HOME/.config/niri"
fi

backup_if_exists "$TARGET_HOME/.config/niri/config.kdl"

run "Install Niri config" \
    cp "$REPO_DIR/niri/config.kdl" \
    "$TARGET_HOME/.config/niri/config.kdl"

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ "$DETECTED_LAYOUT" != "latam" && -n "$DETECTED_LAYOUT" ]]; then
        sed -i "s/layout \"latam,us\"/layout \"$DETECTED_LAYOUT,us\"/" "$TARGET_HOME/.config/niri/config.kdl" 2>/dev/null || true
        debug "Adapted Niri keyboard layout to: $DETECTED_LAYOUT,us"
    fi
fi

# ============================================================
# 5. Color synchronization
# ============================================================

step "5/6 — Wallpaper → Niri color synchronization"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p \
        "$TARGET_HOME/.local/bin" \
        "$TARGET_HOME/.config/systemd/user"
else
    dry_run_msg "Would create $TARGET_HOME/.local/bin"
    dry_run_msg "Would create $TARGET_HOME/.config/systemd/user"
fi

run "Install niri-sync-colors" \
    cp "$REPO_DIR/scripts/niri-sync-colors" \
    "$TARGET_HOME/.local/bin/niri-sync-colors"

run "Make niri-sync-colors executable" \
    chmod +x "$TARGET_HOME/.local/bin/niri-sync-colors"

if [[ -f "$REPO_DIR/systemd/niri-sync-colors.service" ]]; then
    run "Install color-sync systemd service" \
        cp "$REPO_DIR/systemd/niri-sync-colors.service" \
        "$TARGET_HOME/.config/systemd/user/niri-sync-colors.service"

    run "Reload systemd user manager" \
        systemctl --user daemon-reload

    run "Enable color synchronization" \
        systemctl --user enable --now niri-sync-colors.service
fi

# ============================================================
# 6. NixOS rebuild
# ============================================================

step "6/6 — Apply NixOS configuration"

REBUILD_TARGET="/etc/nixos"
if nix flake show /etc/nixos 2>/dev/null | grep -q "$DETECTED_HOSTNAME"; then
    REBUILD_TARGET="/etc/nixos#$DETECTED_HOSTNAME"
elif nix flake show /etc/nixos 2>/dev/null | grep -q "nixos"; then
    REBUILD_TARGET="/etc/nixos#nixos"
fi

REBUILD_CMD=(
    sudo
    nixos-rebuild
    switch
    --flake
    "$REBUILD_TARGET"
)

if [[ "$SKIP_REBUILD" -eq 1 ]]; then
    warning "Rebuild skipped because --skip-rebuild was specified."
    echo
    echo "Run manually when ready:"
    echo
    printf '    %s\n' \
        "sudo nixos-rebuild switch --flake $REBUILD_TARGET"

elif [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_msg "Would run:"
    printf '    %q ' "${REBUILD_CMD[@]}"
    echo

elif confirm "Run nixos-rebuild switch now?"; then

    info "Building NixOS configuration with flake $REBUILD_TARGET..."
    info "This can take several minutes on the first run."

    log "RUN: ${REBUILD_CMD[*]}"

    if "${REBUILD_CMD[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        success "NixOS rebuild completed successfully"
    else
        error "NixOS rebuild failed."
        warning "The previous NixOS generation remains active."
        echo
        echo "Check the log:"
        echo "  $LOG_FILE"
        exit 1
    fi

else
    warning "NixOS rebuild skipped."
    echo
    echo "Run manually when ready:"
    echo
    printf '    %s\n' \
        "sudo nixos-rebuild switch --flake $REBUILD_TARGET"
fi

# ============================================================
# Final & Verification
# ============================================================

echo

if [[ "$DRY_RUN" -eq 0 && "$SKIP_REBUILD" -eq 0 ]]; then
    step "Post-install verification"

    info "Reloading systemd user daemon..."
    systemctl --user daemon-reload || true
    systemctl --user restart inir.service 2>/dev/null || true
    systemctl --user restart niri-sync-colors.service 2>/dev/null || true

    sleep 2  # give systemd a moment to (re)start inir.service after the rebuild

    if systemctl --user is-active --quiet inir.service; then
        success "inir.service is active (running)"
    else
        warning "inir.service is not currently active."
        info "Note: inir.service starts automatically when you log into a Niri session."
    fi

    if systemctl --user is-active --quiet niri-sync-colors.service; then
        success "niri-sync-colors.service is active (running)"
    fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s%s╔══════════════════════════════════════════════════════╗%s\n' \
        "$BOLD" "$BLUE" "$RESET"
    printf '%s%s║              Dry-run completed!                   ║%s\n' \
        "$BOLD" "$BLUE" "$RESET"
    printf '%s%s╚══════════════════════════════════════════════════════╝%s\n' \
        "$BOLD" "$BLUE" "$RESET"
    echo
    printf '%sNo changes were made to the system.%s\n' \
        "$YELLOW" "$RESET"
else
    printf '%s%s╔══════════════════════════════════════════════════════╗%s\n' \
        "$BOLD" "$GREEN" "$RESET"
    printf '%s%s║             Installation complete!                 ║%s\n' \
        "$BOLD" "$GREEN" "$RESET"
    printf '%s%s╚══════════════════════════════════════════════════════╝%s\n' \
        "$BOLD" "$GREEN" "$RESET"
fi

echo
printf 'Run diagnostic verification at any time:\n'
printf '  %s\n' \
    "bash $REPO_DIR/scripts/verify-setup.sh"

echo
printf 'Installation log:\n'
printf '  %s\n' "$LOG_FILE"

echo
printf '%sUseful commands:%s\n' "$BOLD" "$RESET"
printf '  systemctl --user status niri-sync-colors.service\n'
printf '  journalctl --user -u niri-sync-colors.service\n'
printf '  sudo nixos-rebuild switch --flake %s\n' "$REBUILD_TARGET"
echo
