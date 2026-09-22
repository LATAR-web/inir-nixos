#!/usr/bin/env bash
# Checks whether /etc/nixos has upstream commits not yet pulled.
# Does not pull or apply anything automatically.

set -Eeuo pipefail

REPO_DIR="/etc/nixos"

command -v git >/dev/null 2>&1 || exit 0
command -v notify-send >/dev/null 2>&1 || exit 0

[[ -d "$REPO_DIR/.git" ]] || exit 0

cd "$REPO_DIR"

git fetch --quiet origin main 2>/dev/null || exit 0

read -r LOCAL_ONLY REMOTE_ONLY < <(
    git rev-list --left-right --count HEAD...origin/main
)

if (( REMOTE_ONLY > 0 && LOCAL_ONLY == 0 )); then
    LATEST_MSG="$(git log origin/main -1 --pretty=%s)"

    notify-send \
        "NixOS config update available" \
        "$REMOTE_ONLY new commit(s). Latest: $LATEST_MSG\n\nRun: cd /etc/nixos && git pull && sudo nixos-rebuild switch --flake /etc/nixos#nixos" \
        -a "NixOS Config" \
        -i software-update-available

elif (( REMOTE_ONLY > 0 && LOCAL_ONLY > 0 )); then
    notify-send \
        "NixOS config repository diverged" \
        "Local and remote histories have diverged. Review /etc/nixos before pulling." \
        -a "NixOS Config" \
        -i dialog-warning
fi
