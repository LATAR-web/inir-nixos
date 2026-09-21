#!/usr/bin/env bash
# Checks if /etc/nixos has upstream commits not yet pulled, and notifies
# the user via libnotify if so. Does NOT pull or apply anything automatically.
set -euo pipefail

REPO_DIR="/etc/nixos"
cd "$REPO_DIR"

git fetch --quiet origin main 2>/dev/null || exit 0

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [[ "$LOCAL" != "$REMOTE" ]]; then
    COUNT=$(git rev-list --count HEAD..origin/main)
    LATEST_MSG=$(git log origin/main -1 --pretty=%s)
    notify-send \
        "NixOS config update available" \
        "$COUNT new commit(s). Latest: $LATEST_MSG\n\nRun: cd /etc/nixos && git pull && sudo nixos-rebuild switch --flake /etc/nixos#nixos" \
        -a "NixOS Config" \
        -i software-update-available
fi
