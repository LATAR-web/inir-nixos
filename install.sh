#!/usr/bin/env bash
# Automated installer for this repo's iNiR + niri + NixOS setup.
# Copies every file to its real system location. Safe to re-run —
# backs up anything it would overwrite instead of clobbering it.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

info() { echo "→ $1"; }
ok()   { echo "  ✅ $1"; }

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        cp -a "$target" "$target.bak.$TIMESTAMP"
        echo "  (backed up existing $target → $target.bak.$TIMESTAMP)"
    fi
}

echo "═══════════════════════════════════════════"
echo "  iNiR + niri + NixOS — automated installer"
echo "═══════════════════════════════════════════"
echo

if [[ ! -d /etc/nixos ]]; then
    echo "❌ /etc/nixos does not exist. Are you on NixOS?"
    exit 1
fi

# --- 1. System config (requires sudo) ---
info "Copying system config to /etc/nixos (needs sudo)..."
for f in configuration.nix flake.nix; do
    sudo cp -a "$REPO_DIR/$f" "/etc/nixos/$f"
done
sudo cp -a "$REPO_DIR/modules" /etc/nixos/
ok "System config copied"

if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    info "No hardware-configuration.nix found — generating yours..."
    sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix > /dev/null
    ok "hardware-configuration.nix generated"
else
    echo "  (keeping your existing hardware-configuration.nix)"
fi

# --- 2. Niri config ---
info "Installing niri config..."
mkdir -p "$HOME/.config/niri"
backup_if_exists "$HOME/.config/niri/config.kdl"
cp "$REPO_DIR/niri/config.kdl" "$HOME/.config/niri/config.kdl"
ok "config.kdl installed"

# --- 3. Color sync script + service ---
info "Installing color sync script + service..."
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
if [[ ! -w "$HOME/.local/bin" ]]; then
    chmod u+w "$HOME/.local/bin"
fi
cp "$REPO_DIR/scripts/niri-sync-colors" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/niri-sync-colors"
cp "$REPO_DIR/systemd/niri-sync-colors.service" "$HOME/.config/systemd/user/"
ok "Color sync installed"

# --- 4. Optional update notifier ---
read -rp "Install the optional update-notification timer? [y/N] " reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
    cp "$REPO_DIR/scripts/check-config-updates.sh" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/check-config-updates.sh"
    cp "$REPO_DIR/systemd/check-config-updates.service" "$REPO_DIR/systemd/check-config-updates.timer" "$HOME/.config/systemd/user/"
    ok "Update notifier installed"
fi

# --- 5. Reload systemd, enable services ---
info "Reloading systemd and enabling services..."
systemctl --user daemon-reload
systemctl --user enable --now niri-sync-colors.service
[[ "$reply" =~ ^[Yy]$ ]] && systemctl --user enable --now check-config-updates.timer
ok "Services enabled"

# --- 6. Rebuild ---
echo
read -rp "Run 'nixos-rebuild switch' now? This can take a while. [y/N] " rebuild_reply
if [[ "$rebuild_reply" =~ ^[Yy]$ ]]; then
    sudo nixos-rebuild switch --flake /etc/nixos#nixos
else
    echo "  Skipped — run this yourself when ready:"
    echo "    sudo nixos-rebuild switch --flake /etc/nixos#nixos"
fi

echo
echo "═══════════════════════════════════════════"
echo "  Done. Verify with:"
echo "    bash $REPO_DIR/scripts/verify-setup.sh"
echo "═══════════════════════════════════════════"
