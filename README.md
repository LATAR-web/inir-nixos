<div align="center">

# ❄️ iNiR on NixOS

<p>
  <b>English</b> |
  <b><a href="README.es.md">Español</a></b>
</p>

[![Experimental](https://img.shields.io/badge/Status-Experimental-orange?style=for-the-badge&logo=flattr&logoColor=white)](#-quick-start)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-wayland-88C0D0?style=for-the-badge&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![iNiR](https://img.shields.io/badge/iNiR-shell-orange?style=for-the-badge)](https://github.com/snowarch/iNiR)
[![Material You](https://img.shields.io/badge/Theming-Material_You-green?style=for-the-badge)](https://github.com/snowarch/iNiR)

<img width="1920" height="1080" alt="iNiR on NixOS" src="https://github.com/user-attachments/assets/56163c9d-20f7-417b-a4a9-c5e9ee86c26e" />

### A reproducible, modular NixOS guide and automated installer for running [iNiR](https://github.com/snowarch/iNiR) on the Niri Wayland compositor with Nix Flakes.

</div>

---

## 🚀 Quick Start

> [!CAUTION]
> **`install.sh` switches your system from NixOS Stable to Unstable (`nixos-unstable`)** — required because iNiR/Niri/Qt6 need packages only on that channel. If you're already on unstable, nothing changes.

> [!WARNING]
> This project is **experimental**. The installer is non-destructive (timestamped backups before any change), but it's **recommended** to run `--dry-run` first, especially on production systems.

```bash
git clone https://github.com/LATAR-web/inir-nixos.git
cd inir-nixos
chmod +x install.sh
./install.sh --dry-run   # recommended first: simulates everything, changes nothing
./install.sh             # then run for real
```

Prefer to do it by hand? See [Option B — Manual Step-by-Step](#option-b--manual-step-by-step) below.

---

## 📑 Table of Contents

- [How Does the Installer Script Work?](#-how-does-the-installer-script-work-installsh)
  - [Installer CLI Options](#installer-cli-options)
  - [Manual Step-by-Step](#option-b--manual-step-by-step)
- [Adapting to User Configuration](#-adapting-to-user-configuration)
- [Repository Structure](#-repository-structure--what-goes-where)
- [Color Sync (Material You ↔ Niri)](#-color-sync--niri--wallpaper)
- [Niri Keybinds](#-niri-configuration--keybinds)
- [Post-Install Verification](#-post-install-verification)
- [Updating & Rollbacks](#-updating)
- [Troubleshooting](#-troubleshooting--known-gotchas)

---

## 🛠️ How Does the Installer Script Work? (`install.sh`)

Runs 7 phases, reproducibly and safely:

1. **Pre-flight** — checks NixOS, `git`, `nix`, `sudo`, and runs `nix flake check`.
2. **Environment detection** — resolves real user/home (even under `sudo`); reads hostname, timezone, locale, keyboard.
3. **Systemd cleanup** — removes stray `~/.config/systemd/user/inir.service` (created by `inir doctor`, overrides the NixOS-managed one) and other legacy services.
4. **Adapt `/etc/nixos`** — backs up and installs `/modules`; preserves your `configuration.nix`; injects `./modules` into `imports`.
5. **Deploy Niri config** — backs up and installs `~/.config/niri/config.kdl`, adapting the keyboard layout.
6. **Material You pipeline** — installs and enables `niri-sync-colors`.
7. **Rebuild** — `nixos-rebuild switch --flake`, logs to `/tmp/inir-nixos-install-<timestamp>.log`.

### Installer CLI Options

| Flag | Description |
|---|---|
| `./install.sh` | Interactive mode with confirmation prompts. |
| `./install.sh --yes` (`-y`) | Non-interactive: assumes "yes" to all prompts. |
| `./install.sh --dry-run` | Simulates everything, changes nothing. **Recommended first run.** |
| `./install.sh --skip-rebuild` | Deploys files/services but skips `nixos-rebuild switch`. |
| `./install.sh --check` | Runs `scripts/verify-setup.sh` and exits. |
| `./install.sh --help` (`-h`) | Shows CLI help. |

### Option B — Manual Step-by-Step

1. `sudo cp -a modules/ /etc/nixos/modules/`
2. Add `./modules` to `imports` in `configuration.nix`; add `video`/`i2c` to your user's groups.
3. In `flake.nix`, add the `inir` input and pass it via `specialArgs`:
   ```nix
   inputs.inir = {
     url = "github:snowarch/inir";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   outputs = { self, nixpkgs, inir, ... }: {
     nixosConfigurations."your_hostname" = nixpkgs.lib.nixosSystem {
       specialArgs = { inherit inir; };
       modules = [ ./configuration.nix ];
     };
   };
   ```
4. `sudo nixos-rebuild switch --flake /etc/nixos`
5. Install Niri config & color daemon:
   ```bash
   mkdir -p ~/.config/niri ~/.local/bin ~/.config/systemd/user
   cp niri/config.kdl ~/.config/niri/config.kdl
   cp scripts/niri-sync-colors ~/.local/bin/ && chmod +x ~/.local/bin/niri-sync-colors
   cp systemd/niri-sync-colors.service ~/.config/systemd/user/
   systemctl --user daemon-reload && systemctl --user enable --now niri-sync-colors.service
   ```

---

## 🧩 Adapting to User Configuration

Built on `lib.mkDefault`, so it never fights your existing config.

```nix
{
  imports = [ ./hardware-configuration.nix ./modules ];

  programs.inir.audio.enable = true;                  # PipeWire audio (default: on)
  programs.inir.desktop.enable = true;                 # GDM login manager
  programs.inir.desktop.enableGnomeFallback = false;   # GNOME fallback (default: off)

  users.users.your_user.extraGroups = [ "wheel" "networkmanager" "video" "i2c" ]; # for DDC/CI brightness
}
```

---

## 🗺️ Repository Structure — What Goes Where

| In this repository | System Destination | Purpose |
|---|---|---|
| `configuration.nix` | `/etc/nixos/configuration.nix` | Base system config |
| `flake.nix` | `/etc/nixos/flake.nix` | Flake pinning nixpkgs and iNiR input |
| `modules/` | `/etc/nixos/modules/` | iNiR package, deps, fonts, audio, desktop, patches |
| `niri/config.kdl` | `~/.config/niri/config.kdl` | Niri keybinds, layout, focus-ring |
| `scripts/niri-sync-colors` | `~/.local/bin/` | Updates Niri focus-ring live |
| `systemd/niri-sync-colors.service` | `~/.config/systemd/user/` | Runs `niri-sync-colors --watch` |
| `scripts/verify-setup.sh` | Run locally | Diagnostic script |
| `install.sh` | Run locally | Automated installer |

---

## 🎨 Color Sync — Niri ↔ Wallpaper

iNiR generates Material You colors from your wallpaper (`matugen`). Pick a wallpaper (<kbd>Mod</kbd> + <kbd>W</kbd>) and `niri-sync-colors` updates the `focus-ring` colors in `~/.config/niri/config.kdl` live. Run it manually with `niri-sync-colors`.

---

## ⌨️ Niri Configuration & Keybinds

| Key | Action |
|---|---|
| <kbd>Mod</kbd> + <kbd>Return</kbd> | Open terminal |
| <kbd>Mod</kbd> + <kbd>W</kbd> | Wallpaper selector |
| <kbd>Mod</kbd> + <kbd>Space</kbd> | Workspace overview |
| <kbd>Mod</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Mod</kbd> + <kbd>,</kbd> | iNiR settings |
| <kbd>Mod</kbd> + <kbd>/</kbd> | Cheatsheet |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot |
| <kbd>Mod</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | Region OCR |
| <kbd>Mod</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd>/<kbd>F</kbd>/<kbd>S</kbd> | Record region / fullscreen / stop |
| <kbd>Mod</kbd> + <kbd>E</kbd> | File manager |
| <kbd>Mod</kbd> + <kbd>B</kbd> | Web browser |
| <kbd>Mod</kbd> + <kbd>Q</kbd> / <kbd>Shift</kbd>+<kbd>Q</kbd> | Close window / quit session |
| <kbd>Mod</kbd> + <kbd>F</kbd> | Toggle fullscreen |
| <kbd>Mod</kbd> + <kbd>1</kbd>–<kbd>5</kbd> | Focus / move to workspace 1–5 |

---

## ✅ Post-Install Verification

```bash
bash scripts/verify-setup.sh
```

Checks CLI tools, the `materialyoucolor` Python module, and service status.

---

## 🔄 Updating

```bash
cd /etc/nixos && nix flake update
sudo nixos-rebuild switch --flake /etc/nixos
systemctl --user restart inir.service
```

Rollback: `sudo nixos-rebuild switch --rollback`

---

## 🐛 Troubleshooting

| Issue | Fix |
|---|---|
| Stray `~/.config/systemd/user/inir.service` | Overrides the NixOS service. Remove it — the installer does this automatically. |
| Missing `/bin/cat` | Fixed via `systemd.tmpfiles.rules` in `modules/inir.nix`. |
| Missing icons in QuickShell | Fixed by `modules/patches/inir-icon-theme.patch`. |
| DDC/CI brightness fails | Requires `video`/`i2c` groups and `hardware.i2c.enable = true`. |

---

*Made with ❄️ for NixOS and Niri*
