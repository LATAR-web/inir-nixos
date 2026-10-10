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

- [📦 Installation Guide](#-installation-guide)
- [⌨️ Keyboard Shortcuts](#️-keyboard-shortcuts)
- [🎨 Color Synchronization](#-color-synchronization-material-you)
- [🔐 iNiR Shell SDDM (Optional)](#-inir-shell-sddm-optional)
- [🐾 Kira Mascot (Testing Phase)](#-kira-mascot-optional-extra--testing-phase-)
- [🗺️ Repository Structure](#️-repository-structure)
- [🐛 Troubleshooting](#-troubleshooting)

---

## 📦 Installation Guide
 
You can easily integrate iNiR into your own NixOS configuration, either using **Nix Flakes** (recommended) or via **Local modules**.

### Option A: Using Flakes (Recommended)

In your own `/etc/nixos/flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    inir-nixos = {
      url = "github:LATAR-web/inir-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, inir-nixos, ... }: {
    nixosConfigurations.<your_hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        inir-nixos.nixosModules.default
      ];
    };
  };
}
```

In your `/etc/nixos/configuration.nix`:

```nix
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Enable iNiR and declarative settings
  programs.inir = {
    enable = true;
    colorSync.enable = true;
    screenRecording.enable = true;
    hardware.brightnessControl = true;
    niri = {
      enable = true;
      autoDeployConfig = true; # Automatically seeds ~/.config/niri and ~/.config/alacritty
      defaultTerminal = "alacritty";
    };
    audio.enable = true;
    desktop = {
      enable = true;
      # display manager: "gdm" (default), "greetd" (VM without 3D), or
      # "sddm" (optional iNiR Shell login theme — see SDDM section below)
      displayManager = "gdm";
    };
  };

  nixpkgs.config.allowUnfree = true;
  users.users.<your_user>.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ];
}
```

### Option B: Copying modules to `/etc/nixos` (Manual without remote Flake)

```bash
sudo cp -a modules/ /etc/nixos/modules/

# If /etc/nixos is tracked with git:
sudo git -C /etc/nixos add -A modules/
```

And in your `/etc/nixos/configuration.nix` add `imports = [ ./modules ];`.

---

### Final Step: Rebuild and deploy dotfiles

1. **Rebuild the system**:
   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos#<your_hostname>
   ```

2. **Initialize user symlinks and dotfiles**:
   ```bash
   systemd-tmpfiles --user --create
   ```
   *(This automatically creates the Python virtual environment at `~/.local/state/quickshell/.venv`, binaries in `~/.local/bin/`, Niri modular configs at `~/.config/niri/config.d/`, and Alacritty)*.

3. **Start your session**:
   Select the **Niri** session from your display manager. Run `bash scripts/verify-setup.sh` to verify all components are green (✅).

---

## ⌨️ Keyboard Shortcuts

> [!NOTE]
> The keyboard shortcuts are the **same as the original [iNiR](https://github.com/snowarch/iNiR) shortcuts on Arch** (and any other distro). `Mod` is **Super** on bare metal, or **Alt** when Niri runs nested inside another session.

| Shortcut | Action |
|---|---|
| <kbd>Mod</kbd> + <kbd>Enter</kbd> / <kbd>T</kbd> | Terminal (Alacritty) |
| <kbd>Mod</kbd> + <kbd>Space</kbd> / <kbd>Tab</kbd> | Overview mode |
| <kbd>Mod</kbd> + <kbd>G</kbd> | Desktop overlay (crosshair) |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Mod</kbd> + <kbd>,</kbd> | iNiR Settings |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Shortcuts cheatsheet |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region snip menu |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | Region OCR (extract text) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>A</kbd> | Region search (Google Lens) |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd> / <kbd>S</kbd> | Record region / Stop recording |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>T</kbd> | Wallpaper picker (Material You) |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Cycle panel family |
| <kbd>Super</kbd> + <kbd>E</kbd> | File manager (Nautilus) |
| <kbd>Mod</kbd> + <kbd>B</kbd> / <kbd>Super</kbd> + <kbd>W</kbd> | Browser |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd> + <kbd>Q</kbd> | Close window / Session dialog |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>E</kbd> | Quit session |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>9</kbd> | Go to workspace 1–9 |

---

## 🎨 Color Synchronization (Material You)

When picking a wallpaper with <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>T</kbd>, `niri-sync-colors` extracts the Material You color palette automatically and updates:
- **Niri active focus ring** (`focus-ring` in `~/.config/niri/config.kdl`).
- **Alacritty color theme** (`~/.config/alacritty/theme.toml`).
- **GTK / GNOME accent** (`accent-color` in libadwaita).

---

## 🔐 iNiR Shell SDDM (Optional)

> [!NOTE]
> **Optional:** SDDM is only one of the supported display managers. You can keep using **GDM** or **greetd** and ignore this section entirely.

If you prefer SDDM as the login screen, this flake enables it with:

```nix
programs.inir.desktop = {
  enable = true;
  displayManager = "sddm";
};
```

The official **ii-pixel** login theme — with Material You colors, matching wallpaper and avatar sync — is an **optional extra** provided by the separate flake [`LATAR-web/inir-sddm-nixos`](https://github.com/LATAR-web/inir-sddm-nixos):

```nix
# Add the input:  inir-sddm = { url = "github:LATAR-web/inir-sddm-nixos"; };
# Then enable it in your configuration.nix:
services.inir-sddm.enable = true;
```

See the `inir-sddm-nixos` repo for full setup instructions.

---

## 🐾 Kira Mascot (Optional Extra · Testing Phase 🧪)

> [!NOTE]
> **Testing / experimental phase:** The Kira mascot integration on NixOS is currently in an active **testing phase**. Visual widgets, companion behavior, and mini-games are being evaluated.

iNiR includes **Kira**, an animated desktop mascot companion that peeks from screen edges, reacts to system events (music, volume, battery, updates), and offers mini-games and wallpaper widgets.

To enable her in your `/etc/nixos/configuration.nix`:
```nix
programs.inir.mascot.enable = true;
```

After rebuilding (`sudo nixos-rebuild switch`), you can customize and interact with her:
- **Graphical Settings:** <kbd>Mod</kbd> + <kbd>,</kbd> → **Mascota** (poses, size, visit frequency, and widgets).
- **IPC Commands:** `inir mascot poke`, `inir mascot romp` (chaos mode), `inir mascot chase` (catch game), `inir mascot hideSeek` (hide and seek), or `inir mascot hide`.

---

## 🗺️ Repository Structure

| File / Folder | Purpose |
|---|---|
| `modules/` | NixOS modules: iNiR package, dependencies, fonts, audio, and patches |
| `modules/mascot.nix` | Optional extra module: Kira mascot art pack and desktop companion integration |
| `niri/config.kdl` | Niri compositor shortcuts, layout, and window rules |
| `alacritty/alacritty.toml` | Terminal configuration with dynamic palette support |
| `scripts/niri-sync-colors` | Background daemon/script for Material You color sync |
| `scripts/record-screen` | Screen recorder script with audio capture |
| `scripts/verify-setup.sh` | Sanity check and diagnostic verification script |

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
