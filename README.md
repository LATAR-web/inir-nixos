<div align="center">

# ❄️ NixOS + Niri + iNiR
### Reproducible Setup

[![NixOS](https://img.shields.io/badge/NixOS-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-88C0D0?style=for-the-badge&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![License](https://img.shields.io/badge/License-MIT-orange?style=for-the-badge)](#)

A guide for installing **[iNiR](https://github.com/snowarch/iNiR)** (a Quickshell-based shell) on top of **Niri**, on **NixOS with flakes** — working around the issues `inir doctor` can't fix on non-Arch distros.

</div>

---

## 📋 Requirements

- ✅ NixOS installed, with flakes enabled
- ✅ A normal user with `sudo`

---

## 🚀 Quick Start

### 1️⃣ Clone this repo into `/etc/nixos`

```bash
sudo mv /etc/nixos /etc/nixos.bak   # back up whatever you had
sudo git clone https://github.com/LATAR-web/inir-nixos-setup.git /etc/nixos
```

### 2️⃣ Generate YOUR hardware-configuration.nix

> ⚠️ **Don't reuse one from another machine.** Generate your own:

```bash
sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix
```

### 3️⃣ Edit `configuration.nix`

Replace `YOUR_USERNAME`, `networking.hostName`, and `time.timeZone` with your own values.

### 4️⃣ Apply

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

> 🕐 The first run will take a while — it's compiling/downloading iNiR's full dependency tree (Qt, KDE frameworks, etc).

### 5️⃣ Verify iNiR started

```bash
systemctl --user status inir.service
```

Should say `active (running)` ✅

---

## 🎨 Color Sync — niri ↔ wallpaper

By default, iNiR syncs wallpaper-derived colors to terminal, GTK, editors, etc. — but **not to niri itself** (the compositor has no concept of "themes"). This script fills that gap.

### 6️⃣ Install the niri color sync script

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp scripts/niri-sync-colors ~/.local/bin/
chmod +x ~/.local/bin/niri-sync-colors
cp systemd/niri-sync-colors.service systemd/niri-sync-colors.path ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now niri-sync-colors.path
```

### 7️⃣ Create the Python venv for the color pipeline

```bash
uv venv ~/.local/share/inir/venv --python 3
source ~/.local/share/inir/venv/bin/activate
uv pip install materialyoucolor pillow numpy
deactivate
systemctl --user restart inir.service
```

---

## ⌨️ Niri Config

### 8️⃣ Copy the niri config

This repo ships a complete, working `config.kdl` (keybinds, layout, xwayland-satellite path, etc). Copy it directly:

```bash
mkdir -p ~/.config/niri
cp niri/config.kdl ~/.config/niri/config.kdl
niri msg action load-config-file
```

> 💡 **Note:** `xwayland-satellite`'s `path` uses `$HOME` — niri does not expand shell variables in strings, so if the copy fails to launch it, replace `$HOME` with your literal home directory path in that one line.

### 9️⃣ Test it

Switch wallpapers (iNiR's default keybind is `Mod+W`). The bar, panels, and niri's `focus-ring` should all change color together. 🎉

---

## 🐛 Known Issues / Gotchas

| Issue | Fix |
|---|---|
| 🚫 **`inir doctor` is not safe to run on NixOS** | Its auto-fix mode assumes Arch: it can reinstall a launcher at `~/.local/bin/inir` and write an `inir.service` by hand to `~/.config/systemd/user/`, which systemd prioritizes over the one Nix generates (`/etc/systemd/user/`) — silently making your declarative config completely ignored, with no visible error. If you run it by accident, check and remove those two paths. |
| 🔄 **`inir.service` doesn't pick up environment changes after a rebuild** | You're almost always missing `systemctl --user daemon-reload && systemctl --user restart inir.service` — `nixos-rebuild switch` updates the service definition on disk, but does not restart an already-running process. |
| 📁 **Venv at `~/.local/share/inir/venv` errors with "No such file or directory"** | This happens after a rebuild because the `python3` its symlink pointed to no longer exists in the store (version changed). You'll need to recreate the venv (step 7) whenever this happens — consider migrating to `python3.withPackages` (already declared in `inir-deps.nix`) as the source of truth instead of the manual venv, going forward. |
| 🐍 **`python3` in `systemd.user.services.<name>.path` can't see libraries from separate `python3Packages.*` derivations** | Use a single `(python3.withPackages (ps: with ps; [ ... ]))` derivation everywhere `import materialyoucolor` (or similar) needs to work — both in `environment.systemPackages` and in the service's `.path`. Two separate `python3.withPackages` calls with the same package list also works, but keeping them in sync manually is fragile; consider factoring the package list into a shared `let` binding. |

---

<div align="center">

Made with 🖤 on NixOS

</div>
