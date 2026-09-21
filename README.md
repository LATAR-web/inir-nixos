# NixOS + Niri + iNiR — Reproducible Setup

A guide for installing [iNiR](https://github.com/snowarch/iNiR) (a
Quickshell-based shell) on top of Niri, on NixOS with flakes — working
around the issues `inir doctor` can't fix on non-Arch distros.

## 0. Requirements

- NixOS installed, with flakes enabled.
- A normal user with `sudo`.

## 1. Clone this repo into `/etc/nixos`

```bash
sudo mv /etc/nixos /etc/nixos.bak   # back up whatever you had
sudo git clone https://github.com/YOUR_USERNAME/inir-nixos-setup.git /etc/nixos
```

## 2. Generate YOUR hardware-configuration.nix

**Don't reuse one from another machine.** Generate your own:

```bash
sudo nixos-generate-config --show-hardware-config | sudo tee /etc/nixos/hardware-configuration.nix
```

## 3. Edit `configuration.nix`

Replace `YOUR_USERNAME`, `networking.hostName`, and `time.timeZone` with
your own values.

## 4. Apply

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

The first run will take a while — it's compiling/downloading iNiR's full
dependency tree (Qt, KDE frameworks, etc).

## 5. Verify iNiR started

```bash
systemctl --user status inir.service
```

Should say `active (running)`.

## 6. Install the niri color sync script

By default, iNiR syncs wallpaper-derived colors to terminal, GTK, editors,
etc. — but **not to niri itself** (the compositor has no concept of
"themes"). This script fills that gap:

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp scripts/niri-sync-colors ~/.local/bin/
chmod +x ~/.local/bin/niri-sync-colors
cp systemd/niri-sync-colors.service systemd/niri-sync-colors.path ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now niri-sync-colors.path
```

## 7. Create the Python venv for the color pipeline

```bash
uv venv ~/.local/share/inir/venv --python 3
source ~/.local/share/inir/venv/bin/activate
uv pip install materialyoucolor pillow numpy
deactivate
systemctl --user restart inir.service
```

## 8. Add the niri config snippets

Copy the contents of `niri/config.kdl.snippets` into your
`~/.config/niri/config.kdl` (at the root level of the file, alongside
`input {}`, `layout {}`, etc). Read it first — each block explains why it
exists.

Then reload:

```bash
niri msg action load-config-file
```

## 9. Test it

Switch wallpapers (iNiR's default keybind is `Mod+W`). The bar, panels, and
niri's `focus-ring` should all change color together.

## Known issues / gotchas

- **`inir doctor` is not safe to run on NixOS.** Its auto-fix mode assumes
  Arch: it can reinstall a launcher at `~/.local/bin/inir` and write an
  `inir.service` by hand to `~/.config/systemd/user/`, which systemd
  prioritizes over the one Nix generates (`/etc/systemd/user/`) —  silently
  making your declarative config completely ignored, with no visible error.
  If you run it by accident, check and remove those two paths.
- **If `inir.service` doesn't pick up environment changes after a
  rebuild**, you're almost always missing `systemctl --user daemon-reload
  && systemctl --user restart inir.service` — `nixos-rebuild switch`
  updates the service definition on disk, but does not restart an
  already-running process.
- **If the venv at `~/.local/share/inir/venv` errors with "No such file or
  directory"** after a rebuild, it's because the `python3` its symlink
  pointed to no longer exists in the store (version changed). You'll need
  to recreate the venv (step 7) whenever this happens — there's no fully
  avoiding it with a venv sitting loose in `$HOME`; consider migrating to
  `python3.withPackages` (already declared in `inir-deps.nix`) as the
  source of truth instead of the manual venv, going forward.
