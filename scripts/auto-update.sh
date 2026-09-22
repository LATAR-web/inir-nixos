#!/usr/bin/env bash
# Optional: pulls + rebuilds automatically, but ONLY if the build succeeds.
# Never leaves the system half-updated. Notifies the outcome either way.
set -uo pipefail

REPO_DIR="/etc/nixos"
cd "$REPO_DIR" || exit 1

git fetch --quiet origin main 2>/dev/null || exit 0

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

[[ "$LOCAL" == "$REMOTE" ]] && exit 0  # already up to date

PREV_GEN=$(readlink /run/current-system)

if ! git pull --quiet origin main; then
    notify-send "NixOS auto-update failed" "git pull failed — check /etc/nixos manually" -a "NixOS Config" -i dialog-error
    exit 1
fi

if sudo nixos-rebuild switch --flake /etc/nixos#nixos > /tmp/auto-update.log 2>&1; then
    notify-send "NixOS config updated" "Rebuilt successfully from origin/main." -a "NixOS Config" -i software-update-available
else
    # Roll the repo checkout back too, so it matches what's actually running
    git reset --hard "$LOCAL" --quiet
    notify-send "NixOS auto-update FAILED — rolled back" \
        "Build broke, repo reverted to last working commit. Log: /tmp/auto-update.log" \
        -a "NixOS Config" -i dialog-error
    exit 1
fi
