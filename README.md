<div align="center">

# ❄️ iNiR on NixOS
### A reproducible, from-scratch guide to running [iNiR](https://github.com/snowarch/iNiR) on Niri + NixOS with flakes

[![NixOS](https://img.shields.io/badge/NixOS-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Niri](https://img.shields.io/badge/Niri-88C0D0?style=for-the-badge&logo=wayland&logoColor=white)](https://github.com/YaLTeR/niri)
[![Flakes](https://img.shields.io/badge/Flakes-enabled-7EBAE4?style=for-the-badge)](https://nixos.wiki/wiki/Flakes)
[![iNiR](https://img.shields.io/badge/iNiR-shell-orange?style=for-the-badge)](https://github.com/snowarch/iNiR)

This is **not the official iNiR repo**. It's one person's working NixOS
config plus the fixes needed to get iNiR's Arch-oriented tooling (`inir
doctor`, the wallpaper color pipeline, etc) actually working declaratively
on NixOS — documented so the next person doesn't have to rediscover all of
it from scratch. See the [official NixOS wiki page](https://github.com/snowarch/inir/wiki/NIXOS)
for the upstream-maintained flake docs.

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
sudo git clone https://github.com/LATAR-web/inir-nixos.git /etc/nixos
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

## 🧩 Alternative: the upstream `niri-flake` approach

This repo uses NixOS's built-in `programs.niri.enable`. The
[official wiki](https://github.com/snowarch/inir/wiki/NIXOS) documents a
second path using [`niri-flake`](https://github.com/sodiboo/niri-flake)
instead, which lets you declare niri's own keybinds in Nix (rather than
editing `config.kdl` by hand) and merge iNiR's actions into them:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    niri.url = "github:sodiboo/niri-flake";
    inir.url = "github:snowarch/inir";
  };
}
```

```nix
{ config, inputs, ... }: {
  imports = [
    inputs.niri.nixosModules.niri
    inputs.inir.nixosModules.inir
  ];

  programs.niri.enable = true;
  programs.inir = {
    enable = true;
    service.compositor = "niri";
    extraPackages = [ config.programs.niri.package ];
  };

  programs.niri.settings.binds = {
    "Mod+Space".action.spawn = [ "inir" "overview" "toggle" ];
    "Mod+V".action.spawn = [ "inir" "clipboard" "toggle" ];
    "Mod+Comma".action.spawn = [ "inir" "settings" ];
    "Mod+Slash".action.spawn = [ "inir" "cheatsheet" "toggle" ];
  };
}
```

Both approaches work. This repo sticks to a plain `config.kdl` because
it's easier to diff/debug when things go wrong — pick whichever fits how
you like to manage config.

---

## 🎨 Color Sync — niri ↔ wallpaper

By default, iNiR syncs wallpaper-derived colors to terminal, GTK, editors, etc. — but **not to niri itself** (the compositor has no concept of "themes"). This script fills that gap.

### 6️⃣ Install the niri color sync script

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp scripts/niri-sync-colors ~/.local/bin/
chmod +x ~/.local/bin/niri-sync-colors
cp systemd/niri-sync-colors.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now niri-sync-colors.service
```

### 7️⃣ Python packages for the color pipeline

Already declared in `modules/packages.nix` via `python3.withPackages`
(`materialyoucolor`, `pillow`, `numpy`, `evdev`) — no manual venv needed.
See [Known Issues](#-known-issues--gotchas) below for why a manual venv
is a trap here.

---

## ⌨️ Niri Config & Keybinds

### 8️⃣ Copy the niri config

This repo ships a complete, working `config.kdl`. Copy it directly:

```bash
mkdir -p ~/.config/niri
cp niri/config.kdl ~/.config/niri/config.kdl
niri msg action load-config-file
```

> 💡 **Note:** `xwayland-satellite`'s `path` uses `$HOME` — niri does not expand shell variables in strings, so if the copy fails to launch it, replace `$HOME` with your literal home directory path in that one line.

### Keybind reference

| Key | Action |
|---|---|
| `Mod+Return` | Open terminal (alacritty) |
| `Mod+W` | Toggle wallpaper selector |
| `Mod+Space` | Toggle overview |
| `Mod+V` | Toggle clipboard history |
| `Mod+Comma` | Open settings |
| `Mod+Slash` | Toggle cheatsheet |
| `Mod+Shift+W` | Cycle panel family |
| `Mod+Shift+S` | Region screenshot |
| `Mod+Shift+X` | Region OCR |
| `Mod+E` | Open file manager |
| `Mod+B` | Open browser |
| `Mod+Alt+Space` | Switch keyboard layout |
| `Mod+Q` / `Mod+Shift+Q` | Close window / quit niri |
| `Mod+F` / `Mod+Shift+F` | Fullscreen / toggle floating |
| `Mod+M` | Maximize column |
| `Mod+Grave` | Switch focus floating ↔ tiling |
| `Mod+1`–`5` | Focus workspace 1–5 |
| `Mod+Shift+1`–`5` | Move column to workspace 1–5 |

Full list in [`niri/config.kdl`](niri/config.kdl).

### 9️⃣ Test it

Switch wallpapers with `Mod+W`. The bar, panels, and niri's `focus-ring` should all change color together. 🎉

---

## 🧸 The Mascot (Kira)

iNiR ships an optional mascot named **Kira** — a separate art pack
(354 poses/animations, ~32 MiB) published at
[`snowarch/inir-mascot`](https://github.com/snowarch/inir-mascot). The
feature is **disabled by default** and does nothing until you install the
pack and enable her from **Settings → Mascot**.

On Arch, `./setup` installs it as an optional extra. On NixOS, there is no
automated path yet — you'd need to fetch the art pack manually and place
it where iNiR's `assets/images/mascot/manifest.json` expects it, then
enable the toggle in Settings. This repo doesn't automate that step (the
asset pack isn't in nixpkgs), but it's a nice-to-have once your base setup
is stable.

---

## 🔄 Updating

**This repo does not push updates to anyone.** Cloning it is a one-time
copy — if you fix something here later and `git push`, people who already
cloned it will **not** get the fix automatically. There's no
subscription, no webhook, nothing watching your machine for changes.

If you cloned this repo and want to pull in later fixes:

```bash
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

If you've made your own local edits to files this repo tracks, `git pull`
may conflict — commit your changes first (`git add -A && git commit`) so
Git can merge cleanly, or `git stash` them beforehand.

This is different from `inir update`, which really does have update
logic built in (it's an app, not a config snapshot) — see the
[official update docs](https://github.com/snowarch/inir/wiki/SETUP) for
that. For a Nix install specifically, though, `inir update` is **not**
the right path — update through `nix flake update` and rebuild instead,
same as any other flake input.

---

## 🐛 Known Issues / Gotchas

| Issue | Fix |
|---|---|
| 🚫 **`inir doctor` is not safe to run on NixOS** | Its auto-fix mode assumes Arch: it can reinstall a launcher at `~/.local/bin/inir` and write an `inir.service` by hand to `~/.config/systemd/user/`, which systemd prioritizes over the one Nix generates (`/etc/systemd/user/`) — silently making your declarative config completely ignored, with no visible error. If you run it by accident, check and remove those two paths. |
| 🔄 **`inir.service` doesn't pick up environment changes after a rebuild** | You're almost always missing `systemctl --user daemon-reload && systemctl --user restart inir.service` — `nixos-rebuild switch` updates the service definition on disk, but does not restart an already-running process. |
| 📁 **A manual Python venv under `~/.local/share/...` breaks after a rebuild** | If the venv's `python3` symlink pointed at a store path that a later rebuild garbage-collects, every script using it starts failing with "No such file or directory". Use `python3.withPackages` in Nix instead (see `modules/packages.nix`) — no venv to go stale. |
| 🐍 **A plain `python3` in `systemd.user.services.<name>.path` can't see libraries from separate `python3Packages.*` derivations** | Use a single `(python3.withPackages (ps: with ps; [ ... ]))` derivation everywhere `import materialyoucolor` (or similar) needs to work — both in `environment.systemPackages` and in the service's `.path`. Keeping two such derivations in sync by hand is fragile; consider factoring the package list into a shared `let` binding. |
| 🖼️ **Very high-resolution wallpapers fail to decode** (blank lock screen, "colors.json generation failed", `QImageIOHandler: Rejecting image... exceeds allocation limit`) | Qt's default image allocation limit is 256 MiB. Either resize oversized wallpapers (`magick file.jpg -resize 3840x2160\> -quality 90 file.jpg`) or raise the limit via `environment.variables.QT_IMAGEIO_MAXALLOC` / the `environment { QT_IMAGEIO_MAXALLOC "1024"; }` block in `config.kdl`. |
| 🔊 **NixOS has no `/bin/cat`** (and other FHS paths) some scripts hardcode | `systemd.tmpfiles.rules = [ "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat" ];` — see `configuration.nix`. |
| 🧵 **`inotifywait` on a single file misses events** | Scripts that `mv` a `.tmp` file into place (atomic rename) don't fire `close_write` on the final filename. Watch the *directory* with `-m` and filter by `--format "%f"` instead of watching the file directly — and remember to escape `%f` as `%%f` in a systemd `ExecStart=` line, since systemd treats a bare `%f` as its own specifier. |

---

<div align="center">

Made with 🖤 on NixOS

</div>
