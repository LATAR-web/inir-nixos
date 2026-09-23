<div align="center">

# ❄️ iNiR on NixOS
<img width="1920" height="1080" alt="iNiR on NixOS" src="https://github.com/user-attachments/assets/56163c9d-20f7-417b-a4a9-c5e9ee86c26e" />

### A reproducible, modular guide and automated setup for running [iNiR](https://github.com/snowarch/iNiR) on Niri + NixOS with flakes

[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-wayland-88C0D0?style=for-the-badge&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![iNiR](https://img.shields.io/badge/iNiR-shell-orange?style=for-the-badge)](https://github.com/snowarch/iNiR)
[![Material You](https://img.shields.io/badge/Theming-Material_You-green?style=for-the-badge)](https://github.com/snowarch/iNiR)

This repository provides a clean, modular NixOS configuration and automated installer to run the **iNiR** desktop shell alongside the scrollable **Niri** Wayland compositor with full Material You color dynamic theming, icon resolution fixes, and systemd integration.

</div>

---

## 📑 Contents

- [Features](#-features)
- [File Map](#-file-map--what-goes-where)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
  - [Option A — Automated Installer (Recommended)](#option-a--automated-installer-recommended)
  - [Option B — Manual Installation](#option-b--manual-step-by-step)
- [Color Synchronization (Material You ↔ Niri)](#-color-sync--niri--wallpaper)
- [Niri Configuration & Keybinds](#-niri-configuration--keybinds)
- [Verification & Diagnostics](#-post-install-verification)
- [Updating](#-updating)
- [Known Issues & Solutions](#-known-issues--gotchas)

---

## ✨ Features

- **Modular NixOS Architecture**: Separation of concerns (`modules/inir.nix`, `modules/inir-deps.nix`, `modules/runtime.nix`, `modules/fonts.nix`, `modules/audio.nix`, `modules/desktop.nix`).
- **NixOS Compatibility Patches**:
  - `inir-icon-theme.patch`: Fixes icon theme discovery in `/run/current-system/sw/share/icons` and user directories.
  - `inir-nixos-fixes.patch`: Replaces hardcoded `/usr/bin/` paths (`notify-send`, `pidof`, `killall`, `hyprpicker`) with standard PATH calls and removes distro-specific package manager alerts.
- **Dynamic Material You Color Pipeline**: Full integration with `matugen`, Python (`materialyoucolor`, `pillow`, `numpy`, `evdev`), and dynamic Niri border syncing via `niri-sync-colors`.
- **Automated Installer**: Single command (`./install.sh`) with auto-detection for hardware configuration, keyboard layout, timezone, and user permissions.

---

## 🗺️ File Map — what goes where

| In this repo | Destination | Purpose |
|---|---|---|
| `configuration.nix` | `/etc/nixos/configuration.nix` | Base system config (imports `./hardware-configuration.nix` and `./modules`) |
| `flake.nix` | `/etc/nixos/flake.nix` | Flake definition pinning nixpkgs and the iNiR upstream flake input |
| `modules/default.nix` | `/etc/nixos/modules/default.nix` | Module aggregator |
| `modules/inir.nix` | `/etc/nixos/modules/inir.nix` | Patched iNiR package definition, environment variables & tmpfiles symlinks |
| `modules/inir-deps.nix` | `/etc/nixos/modules/inir-deps.nix` | All required runtime packages, Qt6/KDE frameworks, and Python theming libraries |
| `modules/runtime.nix` | `/etc/nixos/modules/runtime.nix` | Flakes, nix-ld compatibility, `QT_PLUGIN_PATH` and `QML2_IMPORT_PATH` |
| `modules/fonts.nix` | `/etc/nixos/modules/fonts.nix` | Required fonts (`material-symbols`, JetBrains Mono Nerd Font, Roboto) |
| `modules/patches/` | `/etc/nixos/modules/patches/` | Patches for NixOS icon resolution and hardcoded FHS paths |
| `modules/audio.nix` | `/etc/nixos/modules/audio.nix` | PipeWire audio server setup |
| `modules/desktop.nix` | `/etc/nixos/modules/desktop.nix` | GDM display manager + fallback desktop session |
| `niri/config.kdl` | `~/.config/niri/config.kdl` | Niri compositor keybinds, layout, and focus-ring configuration |
| `scripts/niri-sync-colors` | `~/.local/bin/niri-sync-colors` | Watches generated palette and updates Niri focus-ring & wallpaper metadata |
| `systemd/niri-sync-colors.service` | `~/.config/systemd/user/` | User systemd daemon running `niri-sync-colors --watch` |
| `scripts/verify-setup.sh` | Run locally | Non-destructive diagnostic check for dependencies and services |
| `install.sh` | Run locally | Automated installer with auto-detection, backups, and verification |

---

## 📋 Requirements

- NixOS installed with experimental features enabled (`flakes` and `nix-command`).
- A normal user with `sudo` privileges.
- Network connection for downloading flake inputs and Nix packages.

---

## 🚀 Quick Start

### Option A — Automated Installer (Recommended)

Clone the repository and run the installer:

```bash
git clone https://github.com/LATAR-web/inir-nixos.git
cd inir-nixos
chmod +x install.sh
./install.sh
```

#### Installer Options:
- `./install.sh`: Interactive installation with confirmation at each critical step.
- `./install.sh --yes`: Automatically confirm all prompts.
- `./install.sh --dry-run`: View all actions without modifying the filesystem.
- `./install.sh --skip-rebuild`: Install configuration files and services without executing `nixos-rebuild switch`.
- `./install.sh --check`: Run diagnostic verification using `scripts/verify-setup.sh`.

---

### Option B — Manual Step-by-Step

#### 1️⃣ Back up and clone into `/etc/nixos`

```bash
sudo mv /etc/nixos /etc/nixos.bak
sudo git clone https://github.com/LATAR-web/inir-nixos.git /etc/nixos
```

#### 2️⃣ Ensure hardware configuration is present

```bash
# Keep your existing hardware-configuration.nix, or generate one:
sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix
```

#### 3️⃣ Adjust `configuration.nix`

Open `/etc/nixos/configuration.nix` and replace:
- `"YOUR_USERNAME"` with your Linux username.
- `networking.hostName` and `time.timeZone` as needed.
- In `/etc/nixos/modules/desktop.nix`, verify your keyboard layout (defaults to `latam`).

#### 4️⃣ Build and switch

```bash
cd /etc/nixos
# If /etc/nixos is a git repository, ensure all new files are staged:
sudo git add -A
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

#### 5️⃣ Install Niri config and color sync service

```bash
mkdir -p ~/.config/niri ~/.local/bin ~/.config/systemd/user

# Install Niri configuration
cp /etc/nixos/niri/config.kdl ~/.config/niri/config.kdl

# Install and enable color synchronization
cp /etc/nixos/scripts/niri-sync-colors ~/.local/bin/
chmod +x ~/.local/bin/niri-sync-colors
cp /etc/nixos/systemd/niri-sync-colors.service ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now niri-sync-colors.service
```

---

## 🎨 Color Sync — Niri ↔ Wallpaper

iNiR generates dynamic Material You color schemes from your active wallpaper using `matugen` and a Python pipeline (`materialyoucolor`, `pillow`, `numpy`, `evdev`).

To synchronize these generated colors with the Niri compositor:
1. When you select a wallpaper with <kbd>Mod</kbd> + <kbd>W</kbd>, iNiR writes:
   - `~/.local/state/quickshell/user/generated/colors.json`
   - `~/.local/state/quickshell/user/generated/theme-meta.json`
2. The `niri-sync-colors` background service (`systemd/niri-sync-colors.service`) detects file modifications via `inotifywait`.
3. It calls `niri-config.py` to update the active and inactive `focus-ring` colors in `~/.config/niri/config.kdl` live.
4. It atomically updates the active wallpaper path in `~/.config/illogical-impulse/config.json`.

---

## ⌨️ Niri Configuration & Keybinds

Key shortcuts configured in `niri/config.kdl`:

| Key | Action |
|---|---|
| <kbd>Mod</kbd> + <kbd>Return</kbd> | Open terminal (`alacritty`) |
| <kbd>Mod</kbd> + <kbd>W</kbd> | Open wallpaper selector |
| <kbd>Mod</kbd> + <kbd>Space</kbd> | Toggle overview |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Open clipboard history |
| <kbd>Mod</kbd> + <kbd>,</kbd> | Open iNiR settings |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Toggle cheatsheet |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Cycle panel style family |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | Region OCR recognition |
| <kbd>Mod</kbd> + <kbd>E</kbd> | Open file manager |
| <kbd>Mod</kbd> + <kbd>B</kbd> | Open browser |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>Space</kbd> | Switch keyboard layout |
| <kbd>Mod</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>Q</kbd> | Quit compositor |
| <kbd>Mod</kbd> + <kbd>F</kbd> | Fullscreen toggle |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>5</kbd> | Focus workspace 1–5 |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd>–<kbd>5</kbd> | Move column to workspace 1–5 |

---

## ✅ Post-Install Verification

Run the built-in verification script to inspect your setup:

```bash
bash scripts/verify-setup.sh
```

Checks performed:
- Availability of required CLI tools (`niri`, `inir`, `python3`, `jq`, `inotifywait`, `cliphist`).
- Python `materialyoucolor` module import test.
- Status of `inir.service` and `niri-sync-colors.service`.
- Niri config and clipboard watcher validation.

---

## 🔄 Updating

To update flake inputs and rebuild your system:

```bash
cd /etc/nixos
nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#nixos
systemctl --user restart inir.service
```

If something breaks, rollback instantly:
```bash
sudo nixos-rebuild switch --rollback
```

---

## 🐛 Known Issues & Solutions

| Issue | Cause & Solution |
|---|---|
| **Stray `inir.service` in user directory** | `inir doctor` may generate a file at `~/.config/systemd/user/inir.service`. This file overrides `/etc/systemd/user/inir.service` created by NixOS and breaks declarative configuration. Remove `~/.config/systemd/user/inir.service` if present. |
| **Missing `/bin/cat`** | iNiR scripts rely on FHS `/bin/cat`. Fixed via `systemd.tmpfiles.rules = [ "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat" ];` in `configuration.nix`. |
| **Missing Icons in QuickShell** | Upstream iNiR searches Arch `/usr/share/icons`. Fixed by `modules/patches/inir-icon-theme.patch` and symlinking `/run/current-system/sw/share/icons`. |
| **Brightness controls (DDC/CI) fail** | Make sure your user belongs to `video` and `i2c` groups, and `hardware.i2c.enable = true` is set in `modules/inir.nix`. |

---

<div align="center">

Made with ❄️ for NixOS and Niri

</div>
