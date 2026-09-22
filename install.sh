#!/usr/bin/env bash
#
# iNiR + Niri + NixOS
# Automated installer for:
#   https://github.com/LATAR-web/inir-nixos-setup
#
# Usage:
#   ./install.sh
#   ./install.sh --yes
#   ./install.sh --dry-run
#   ./install.sh --skip-rebuild
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
printf '%s%s║                 Automated Installer                ║%s\n' \
    "$BOLD" "$CYAN" "$RESET"
printf '%s%s╚══════════════════════════════════════════════════════╝%s\n' \
    "$BOLD" "$CYAN" "$RESET"
printf '\n'

printf 'Repository: %shttps://github.com/LATAR-web/inir-nixos-setup%s\n' \
    "$BLUE" "$RESET"

printf 'Installer:  %s%s%s\n' "$DIM" "$REPO_DIR" "$RESET"
printf 'Log file:   %s%s%s\n' "$DIM" "$LOG_FILE" "$RESET"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    printf '%s%s DRY-RUN MODE %s\n' "$BG_BLUE" "$WHITE" "$RESET"
    printf 'No system changes will be made.\n'
fi

# ============================================================
# 0. Pre-flight
# ============================================================

step "0/6 — Pre-flight checks"

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

require_command git "git"
require_command nix "nix"
require_command sudo "sudo"
require_command python3 "python3"
require_command jq "jq"
require_command inotifywait "inotify-tools"
require_command flock "util-linux"

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
    printf '      nix flake check --no-write-lock-file "%s"
' "$REPO_DIR"
else
    info "Validating Nix flake..."

    if nix --extra-experimental-features "nix-command flakes" \
        flake check --no-write-lock-file "$REPO_DIR"; then
        success "Nix flake validation passed"
    else
        error "Nix flake validation failed."
        error "Run manually:"
        printf '      nix flake check --no-write-lock-file "%s"
' "$REPO_DIR"
        exit 1
    fi
fi

# ============================================================
# 1. System configuration
# ============================================================

step "1/6 — System configuration → /etc/nixos"

echo
printf '%sThe following files may be replaced:%s\n' "$BOLD" "$RESET"
echo "  • /etc/nixos/configuration.nix"
echo "  • /etc/nixos/flake.nix"
echo "  • /etc/nixos/modules/"
echo
printf '%sYour existing hardware-configuration.nix will NOT be replaced.%s\n' \
    "$GREEN" "$RESET"

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ -e /etc/nixos/configuration.nix ||
          -e /etc/nixos/flake.nix ||
          -d /etc/nixos/modules ]]; then

        if ! confirm "Create backups and continue?"; then
            error "Installation cancelled."
            exit 1
        fi

        backup_if_exists "/etc/nixos/configuration.nix"
        backup_if_exists "/etc/nixos/flake.nix"
        backup_if_exists "/etc/nixos/modules"
    fi
fi

run "Install configuration.nix" \
    sudo cp -a "$REPO_DIR/configuration.nix" /etc/nixos/configuration.nix

run "Install flake.nix" \
    sudo cp -a "$REPO_DIR/flake.nix" /etc/nixos/flake.nix

run "Install NixOS modules" \
    sudo cp -a "$REPO_DIR/modules" /etc/nixos/

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
# 2. Niri
# ============================================================

step "2/6 — Niri configuration"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$HOME/.config/niri"
else
    dry_run_msg "Would create ~/.config/niri"
fi

backup_if_exists "$HOME/.config/niri/config.kdl"

run "Install Niri config" \
    cp "$REPO_DIR/niri/config.kdl" \
    "$HOME/.config/niri/config.kdl"

# ============================================================
# 3. Color synchronization
# ============================================================

step "3/6 — Wallpaper → Niri color synchronization"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p \
        "$HOME/.local/bin" \
        "$HOME/.config/systemd/user"
else
    dry_run_msg "Would create ~/.local/bin"
    dry_run_msg "Would create ~/.config/systemd/user"
fi

run "Install niri-sync-colors" \
    cp "$REPO_DIR/scripts/niri-sync-colors" \
    "$HOME/.local/bin/niri-sync-colors"

run "Make niri-sync-colors executable" \
    chmod +x "$HOME/.local/bin/niri-sync-colors"

if [[ -f "$REPO_DIR/systemd/niri-sync-colors.service" ]]; then
    run "Install color-sync systemd service" \
        cp "$REPO_DIR/systemd/niri-sync-colors.service" \
        "$HOME/.config/systemd/user/niri-sync-colors.service"
else
    warning "niri-sync-colors.service not found."
fi

# ============================================================
# 4. Optional extras
# ============================================================

step "4/6 — Optional extras"

INSTALL_NOTIFIER=0

if [[ -f "$REPO_DIR/scripts/check-config-updates.sh" &&
      -f "$REPO_DIR/systemd/check-config-updates.service" &&
      -f "$REPO_DIR/systemd/check-config-updates.timer" ]]; then

    if confirm "Install daily update notification?"; then
        INSTALL_NOTIFIER=1

        run "Install update notifier" \
            cp "$REPO_DIR/scripts/check-config-updates.sh" \
            "$HOME/.local/bin/check-config-updates.sh"

        run "Make update notifier executable" \
            chmod +x "$HOME/.local/bin/check-config-updates.sh"

        run "Install update notifier service" \
            cp "$REPO_DIR/systemd/check-config-updates.service" \
            "$HOME/.config/systemd/user/check-config-updates.service"

        run "Install update notifier timer" \
            cp "$REPO_DIR/systemd/check-config-updates.timer" \
            "$HOME/.config/systemd/user/check-config-updates.timer"
    else
        info "Daily update notification skipped."
    fi
else
    info "Optional update notifier files not found — skipping."
fi

# ============================================================
# 5. User services
# ============================================================

step "5/6 — User services"

run "Reload systemd user manager" \
    systemctl --user daemon-reload

if [[ -f "$HOME/.config/systemd/user/niri-sync-colors.service" ]]; then
    run "Enable color synchronization" \
        systemctl --user enable --now niri-sync-colors.service
fi

if [[ "$INSTALL_NOTIFIER" -eq 1 ]]; then
    run "Enable update notification timer" \
        systemctl --user enable --now check-config-updates.timer
fi

# ============================================================
# 6. NixOS rebuild
# ============================================================

step "6/6 — Apply NixOS configuration"

REBUILD_CMD=(
    sudo
    nixos-rebuild
    switch
    --flake
    /etc/nixos#nixos
)

if [[ "$SKIP_REBUILD" -eq 1 ]]; then
    warning "Rebuild skipped because --skip-rebuild was specified."
    echo
    echo "Run manually when ready:"
    echo
    printf '    %s\n' \
        "sudo nixos-rebuild switch --flake /etc/nixos#nixos"

elif [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_msg "Would run:"
    printf '    %q ' "${REBUILD_CMD[@]}"
    echo

elif confirm "Run nixos-rebuild now?"; then

    info "Building NixOS configuration..."
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
        "sudo nixos-rebuild switch --flake /etc/nixos#nixos"
fi

# ============================================================
# Final
# ============================================================

echo

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
printf 'Verify your installation:\n'
printf '  %s\n' \
    "bash $REPO_DIR/scripts/verify-setup.sh"

echo
printf 'Installation log:\n'
printf '  %s\n' "$LOG_FILE"

echo
printf '%sUseful commands:%s\n' "$BOLD" "$RESET"
echo "  systemctl --user status niri-sync-colors.service"
echo "  journalctl --user -u niri-sync-colors.service"
echo "  sudo nixos-rebuild switch --flake /etc/nixos#nixos"
echo
