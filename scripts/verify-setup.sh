#!/usr/bin/env bash
# Read-only sanity check. Never modifies anything.

set -uo pipefail

FAILURES=0

ok() {
    echo "  ✅ $1"
}

fail() {
    echo "  ❌ $1"
    FAILURES=$((FAILURES + 1))
}

warn() {
    echo "  ⚠️  $1"
}

check_command() {
    local cmd="$1"
    local name="${2:-$1}"

    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$name found"
    else
        fail "$name not found"
    fi
}

echo "── Checking iNiR + niri + NixOS setup ──"

check_command niri "niri"
check_command inir "inir"
check_command python3 "python3"
check_command jq "jq"
check_command inotifywait "inotifywait"
check_command wl-paste "wl-paste"
check_command cliphist "cliphist"
check_command wf-recorder "wf-recorder"
check_command pactl "pactl (PulseAudio CLI)"

if command -v pactl >/dev/null 2>&1; then
    _def_sink="$(pactl get-default-sink 2>/dev/null || true)"
    if [[ -n "$_def_sink" ]]; then
        ok "Default audio sink detected ($_def_sink)"
    else
        warn "pactl found but no default audio sink active yet"
    fi
else
    fail "pactl not found (screen recording will not capture audio)"
fi

if python3 -c "import materialyoucolor" 2>/dev/null; then
    ok "materialyoucolor importable"
else
    fail "materialyoucolor NOT importable"
fi

if systemctl --user is-active --quiet inir.service; then
    ok "inir.service is running"
else
    fail "inir.service is NOT running"
fi

if systemctl --user is-active --quiet niri-sync-colors.service; then
    ok "niri-sync-colors.service is running"
else
    warn "niri-sync-colors.service is not running"
fi

if systemctl --user is-enabled --quiet niri-sync-colors.service; then
    ok "niri-sync-colors.service is enabled"
else
    warn "niri-sync-colors.service is not enabled"
fi

if [[ -f "$HOME/.config/niri/config.kdl" ]]; then
    ok "config.kdl exists"
    if grep -Eq 'wl-paste .*--watch' "$HOME/.config/niri/config.kdl" 2>/dev/null; then
        ok "clipboard watcher configured in config.kdl"
    else
        fail "clipboard watcher missing in config.kdl"
    fi
else
    fail "~/.config/niri/config.kdl missing"
fi

if pgrep -f "wl-paste.*--watch" >/dev/null 2>&1; then
    ok "clipboard watcher process is running"
else
    fail "clipboard watcher process is NOT running"
fi

if [[ -f "$HOME/.config/systemd/user/niri-color-sync.service" ]]; then
    fail "stale niri-color-sync.service found (remove to prevent conflicts)"
fi

if [[ -f "$HOME/.config/systemd/user/xwayland-satellite.service" ]]; then
    fail "stale xwayland-satellite.service found (remove to prevent conflicts; niri manages xwayland natively)"
fi

if [[ -x "$HOME/.local/bin/niri-sync-colors" ]]; then
    ok "niri-sync-colors is executable"
else
    fail "~/.local/bin/niri-sync-colors missing or not executable"
fi

if [[ -x "$HOME/.local/bin/record-screen" ]]; then
    ok "record-screen is executable"
else
    warn "~/.local/bin/record-screen missing or not executable"
fi

if [[ -f "$HOME/.config/systemd/user/niri-sync-colors.service" ]]; then
    ok "color-sync systemd service exists"
else
    fail "color-sync systemd service missing"
fi

# allowUnfree: without it, NVIDIA drivers / Steam / VS Code fail to evaluate
if grep -rqE 'allowUnfree[[:space:]]*=[[:space:]]*true|allowUnfreePredicate' /etc/nixos/configuration.nix /etc/nixos/flake.nix /etc/nixos/modules/*.nix 2>/dev/null; then
    ok "allowUnfree enabled (proprietary packages available)"
else
    fail "allowUnfree NOT enabled — NVIDIA/Steam/etc. will fail to build (set nixpkgs.config.allowUnfree = true;)"
fi

# greetd option consistency: if greetd was chosen, it must be written in the config
if grep -q 'programs.inir.desktop.displayManager = "greetd"' /etc/nixos/configuration.nix 2>/dev/null; then
    ok "greetd configured as display manager"
fi

if [[ -f "$HOME/.config/quickshell/inir/scripts/niri-config.py" || -f "/run/current-system/sw/share/quickshell/inir/scripts/niri-config.py" ]]; then
    ok "iNiR niri-config.py exists"
else
    warn "iNiR niri-config.py not found"
fi

if [[ -w "$HOME/.local/bin" ]]; then
    ok "~/.local/bin is writable"
else
    fail "~/.local/bin is NOT writable"
fi

# niri Wayland session registered system-wide (requires programs.niri.enable)
if [[ -f /run/current-system/sw/share/wayland-sessions/niri.desktop ]]; then
    ok "niri Wayland session registered"
else
    fail "niri Wayland session NOT registered (did the rebuild apply modules/inir.nix?)"
fi

# Disk space under /nix (a full store breaks every future rebuild)
_nix_free="$(df -BG --output=avail /nix 2>/dev/null | tail -n1 | tr -dc '0-9' || echo 0)"
if (( _nix_free > 0 && _nix_free < 5 )); then
    fail "Only ${_nix_free}GB free in /nix — run 'sudo nix-collect-garbage -d'"
elif (( _nix_free > 0 && _nix_free < 10 )); then
    warn "${_nix_free}GB free in /nix — consider 'sudo nix-collect-garbage -d'"
else
    ok "Disk space OK (${_nix_free}GB free in /nix)"
fi

echo "── Done ──"

if (( FAILURES > 0 )); then
    echo
    echo "❌ Verification failed: $FAILURES check(s) failed."
    exit 1
fi

echo
echo "✅ Verification passed."
exit 0
