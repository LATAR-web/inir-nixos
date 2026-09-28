<div align="center">

# ❄️ iNiR on NixOS

<p>
  <b>English</b> |
  <b><a href="README.es.md">Español</a></b>
</p>

[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-wayland-88C0D0?style=flat-square&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=flat-square)](https://nixos.wiki/wiki/Flakes)
[![iNiR](https://img.shields.io/badge/iNiR-shell-orange?style=flat-square)](https://github.com/snowarch/iNiR)
[![Material You](https://img.shields.io/badge/Theming-Material_You-green?style=flat-square)](https://github.com/snowarch/iNiR)

<img width="1920" height="1080" alt="iNiR on NixOS" src="https://github.com/user-attachments/assets/56163c9d-20f7-417b-a4a9-c5e9ee86c26e" />

### Reproducible modules to run [iNiR](https://github.com/snowarch/iNiR) on top of the Niri Wayland compositor on NixOS with Flakes.

</div>

---

## 📑 Table of Contents

- [📦 Manual Installation (Recommended)](#-manual-installation-recommended)
- [⚡ Automated Installation (`install.sh`)](#-automated-installation-installsh)
- [⌨️ Keyboard Shortcuts](#️-keyboard-shortcuts)
- [🎨 Color Synchronization](#-color-synchronization-material-you)
- [🗺️ Repository Structure](#️-repository-structure)
- [🐛 Troubleshooting](#-troubleshooting)

---

## 📦 Manual Installation (Recommended)

This is the **preferred** method if you already have an existing NixOS setup and want to integrate iNiR cleanly under your direct control.

### 1. Copy modules to `/etc/nixos`
```bash
sudo cp -a modules/ /etc/nixos/modules/

# If /etc/nixos is tracked with git, you must stage the directory (or Flakes will ignore it):
sudo git -C /etc/nixos add -A modules/
```

### 2. Configure `/etc/nixos/flake.nix`
Add the `inir` input and pass it via `specialArgs`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir, ... }: {
    nixosConfigurations.<your_hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inir; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

### 3. Integrate into `/etc/nixos/configuration.nix`
Import `./modules`, enable proprietary software, and grant brightness/hardware permissions:

```nix
{
  imports = [
    ./hardware-configuration.nix
    ./modules # Loads iNiR, Niri, fonts, audio and system services
  ];

  nixpkgs.config.allowUnfree = true;
  users.users.<your_user>.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];
}
```

### 4. Remove any residual directories
If you previously cloned or created `~/.config/quickshell/inir` manually, it will shadow the packaged runtime:
```bash
[[ -d ~/.config/quickshell/inir && ! -L ~/.config/quickshell/inir ]] && rm -rf ~/.config/quickshell/inir
```

### 5. Rebuild your system
```bash
sudo nixos-rebuild switch --flake /etc/nixos#<your_hostname>
```

### 6. Initialize user symlinks and dotfiles
> [!IMPORTANT]
> `nixos-rebuild` only applies system-level (`root`) tmpfiles rules. To create the iNiR user runtime symlinks (`~/.config/quickshell/inir` and `~/.local/bin/inir`), **you must run `systemd-tmpfiles --user --create`**:

```bash
# 1. Create runtime symlinks for your user
systemd-tmpfiles --user --create

# 2. Deploy Niri, Alacritty, and color synchronizer configs
mkdir -p ~/.config/niri ~/.config/alacritty ~/.local/bin ~/.config/systemd/user
cp niri/config.kdl ~/.config/niri/config.kdl
cp alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
cp scripts/niri-sync-colors ~/.local/bin/ && chmod +x ~/.local/bin/niri-sync-colors
cp scripts/record-screen ~/.local/bin/ && chmod +x ~/.local/bin/record-screen
cp systemd/niri-sync-colors.service ~/.config/systemd/user/

# 3. Seed initial theme & enable background color sync
~/.local/bin/niri-sync-colors
systemctl --user daemon-reload && systemctl --user enable --now niri-sync-colors.service
```

### 7. Start your session
Log out and select **Niri** from your display manager (GDM or greetd). `inir.service` will start automatically.

To verify that your installation is complete:
```bash
bash scripts/verify-setup.sh
```

---

## ⚡ Automated Installation (`install.sh`)

> [!CAUTION]
> ### ⚠️ WARNING: ONLY FOR FRESH / CLEAN INSTALLATIONS
> `install.sh` **rebuilds your entire NixOS system**:
> - Migrates your channel to `nixos-unstable`.
> - Modifies or injects configuration in `/etc/nixos/configuration.nix` (GPU drivers, microcode, display manager).
> - May overwrite dotfiles in `~/.config/`.
> 
> **DO NOT run this on an established system with custom configurations you want to preserve.** For existing systems, always use [Manual Installation](#-manual-installation-recommended).

If you are on a fresh NixOS install and want full automation:

```bash
git clone https://github.com/LATAR-web/inir-nixos.git
cd inir-nixos
chmod +x install.sh

./install.sh --dry-run   # Mandatory dry-run: checks everything without modifying
./install.sh             # Interactive run
```

### Script CLI Flags:
| Flag | Description |
|---|---|
| `--dry-run` | Simulates installation without modifying files or rebuilding. |
| `-y`, `--yes` | Non-interactive: assumes "yes" to all prompts. |
| `--skip-rebuild` | Deploys files and dotfiles but skips `nixos-rebuild switch`. |
| `--check` | Runs `scripts/verify-setup.sh` and exits. |

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| <kbd>Mod</kbd> + <kbd>Enter</kbd> | Terminal (Alacritty) |
| <kbd>Mod</kbd> + <kbd>W</kbd> | Wallpaper picker (Material You) |
| <kbd>Mod</kbd> + <kbd>Space</kbd> / <kbd>Super</kbd> + <kbd>Tab</kbd> | Overview mode |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Mod</kbd> + <kbd>,</kbd> | iNiR Settings |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Shortcuts cheatsheet |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | Region OCR (extract text) |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> / <kbd>S</kbd> | Record region / Stop recording |
| <kbd>Mod</kbd> + <kbd>E</kbd> | File manager (Nautilus) |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd>+<kbd>Q</kbd> | Close window / Quit session |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>5</kbd> | Go to workspace 1–5 |

---

## 🎨 Color Synchronization (Material You)

When picking a wallpaper with <kbd>Mod</kbd> + <kbd>W</kbd>, `niri-sync-colors` extracts the Material You color palette automatically and updates:
- **Niri active focus ring** (`focus-ring` in `~/.config/niri/config.kdl`).
- **Alacritty color theme** (`~/.config/alacritty/theme.toml`).
- **GTK / GNOME accent** (`accent-color` in libadwaita).

---

## 🗺️ Repository Structure

| File / Folder | Purpose |
|---|---|
| `modules/` | NixOS modules: iNiR package, dependencies, fonts, audio, and patches |
| `niri/config.kdl` | Niri compositor shortcuts, layout, and window rules |
| `alacritty/alacritty.toml` | Terminal configuration with dynamic palette support |
| `scripts/niri-sync-colors` | Background daemon/script for Material You color sync |
| `scripts/record-screen` | Screen recorder script with audio capture |
| `scripts/verify-setup.sh` | Sanity check and diagnostic verification script |
| `install.sh` | Automated installer for fresh installations |

---

## 🐛 Troubleshooting

| Issue | Cause & Fix |
|---|---|
| `Unable to locate config-path helper` when running `inir run` | **1)** User symlinks not initialized: run `systemd-tmpfiles --user --create`.<br>**2)** A real directory shadows the runtime: run `rm -rf ~/.config/quickshell/inir && systemd-tmpfiles --user --create`. |
| Niri doesn't show up in display manager (GDM) | GDM can hide Wayland sessions in VMs or NVIDIA setups. Switch to `programs.inir.desktop.displayManager = "greetd";` or clear `sudo rm -f /var/lib/AccountsService/users/*`. |
| `allowUnfree` evaluation error | Add `nixpkgs.config.allowUnfree = true;` to your `configuration.nix`. |
| Brightness control (DDC/CI) does not work | Ensure your user is in `video` and `i2c` groups, and `hardware.i2c.enable = true;`. |

---

<div align="center">
  <i>Made with ❄️ for NixOS and Niri</i>
</div>
