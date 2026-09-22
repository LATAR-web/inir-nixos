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
else
    fail "~/.config/niri/config.kdl missing"
fi

if [[ -x "$HOME/.local/bin/niri-sync-colors" ]]; then
    ok "niri-sync-colors is executable"
else
    fail "~/.local/bin/niri-sync-colors missing or not executable"
fi

if [[ -f "$HOME/.config/systemd/user/niri-sync-colors.service" ]]; then
    ok "color-sync systemd service exists"
else
    fail "color-sync systemd service missing"
fi

if [[ -f "$HOME/.config/quickshell/inir/scripts/niri-config.py" ]]; then
    ok "iNiR niri-config.py exists"
else
    warn "iNiR niri-config.py not found"
fi

if [[ -w "$HOME/.local/bin" ]]; then
    ok "~/.local/bin is writable"
else
    fail "~/.local/bin is NOT writable"
fi

if [[ -f "$HOME/.config/systemd/user/check-config-updates.timer" ]]; then
    if systemctl --user is-enabled --quiet check-config-updates.timer; then
        ok "update notification timer is enabled"
    else
        warn "update notification timer is not enabled"
    fi
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
