#!/usr/bin/env bash
# Read-only sanity check. Never modifies anything.
set -uo pipefail

ok()   { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; }
warn() { echo "  ⚠️  $1"; }

echo "── Checking iNiR + niri + NixOS setup ──"

command -v niri >/dev/null && ok "niri binary found" || fail "niri not found"
command -v inir >/dev/null && ok "inir binary found" || fail "inir not found"

systemctl --user is-active --quiet inir.service \
    && ok "inir.service is running" \
    || fail "inir.service is NOT running"

systemctl --user is-active --quiet niri-sync-colors.service \
    && ok "niri-sync-colors.service is running" \
    || warn "niri-sync-colors.service not running"

command -v python3 >/dev/null && ok "python3 found" || fail "python3 not found"
python3 -c "import materialyoucolor" 2>/dev/null \
    && ok "materialyoucolor importable" \
    || fail "materialyoucolor NOT importable"

[[ -f "$HOME/.config/niri/config.kdl" ]] \
    && ok "config.kdl exists" \
    || fail "~/.config/niri/config.kdl missing"

[[ -w "$HOME/.local/bin" ]] \
    && ok "~/.local/bin is writable" \
    || fail "~/.local/bin is NOT writable (chmod u+w ~/.local/bin)"

echo "── Done ──"
