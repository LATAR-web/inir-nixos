# Everything iNiR needs on NixOS that isn't pulled in automatically.
# `inir doctor` reports most of these as "missing" because it assumes an
# Arch-style package manager; on NixOS they have to be declared here.
#
# Every package below was added to fix a REAL crash or missing feature,
# confirmed by hand against `inir logs --full` / `journalctl --user -u inir`.
# The "optional" block at the end is taste, not requirement — trim freely.

{ pkgs }:

with pkgs; [
  # --- Core shell / compositor glue ---
  git                      # needed by scripts/auto-update.sh and check-config-updates.sh (git fetch/pull)
  inotify-tools            # provides `inotifywait`, used by systemd/niri-sync-colors.service
  quickshell              # the actual runtime iNiR's `inir` launcher wraps
  xwayland-satellite       # Xwayland support under niri (non-native apps)
  swaylock
  swayidle
  wl-clipboard
  cliphist
  libnotify
  wlsunset
  xdg-user-dirs
  xdg-utils
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  gnome-keyring
  fish                    # some of iNiR's scripts shell out to fish specifically
  gum
  uv                       # needed to create the venv in README step 7
  bc
  ripgrep
  jq

  # --- Qt/QML modules — without these, quickshell fails with
  #     'module "org.kde.X" is not installed' and the bar/background never render ---
  kdePackages.qt5compat
  kdePackages.kirigami
  kdePackages.qtmultimedia   # required for video wallpapers; without it they fall back to a blurry static thumbnail
  kdePackages.syntax-highlighting
  kdePackages.kdialog
  kdePackages.plasma-integration
  kdePackages.plasma-browser-integration
  kdePackages.kconfig
  darkly

  # --- Color theming pipeline ---
  matugen                          # the actual engine that generates the Material You palette
  (python3.withPackages (ps: with ps; [
    pip
    materialyoucolor
    pillow
    evdev
  ]))

  # --- Screenshots / OCR / screen recording ---
  grim
  slurp
  swappy
  tesseract
  wf-recorder
  ffmpeg
  pulseaudio               # provides `pactl`; needed for wf-recorder's audio mixing — NOT running the pulseaudio daemon, just the CLI

  # --- System controls the shell's widgets call ---
  brightnessctl
  ddcutil                  # external monitor brightness over DDC/CI
  upower
  blueman
  networkmanagerapplet
  pavucontrol

  # --- Fonts the shell's icons/UI actually depend on ---
  nerd-fonts.jetbrains-mono
  material-symbols          # the icon font used throughout iNiR's UI — do not remove
  alacritty                 # terminal used by niri/config.kdl's Mod+Return bind — required for the shared config to work out of the box

  # ===========================================================================
  # OPTIONAL — features you may not use. Safe to delete any of these lines.
  # ===========================================================================
  fuzzel                    # app launcher fallback
  wtype                     # simulated keyboard input, used by a couple of automation features
  ydotool
  geoclue2                  # location for the weather widget
  fprintd                   # fingerprint unlock — only relevant if your laptop has a sensor
  libqalculate               # calculator widget backend
  translate-shell            # translate widget
  socat                      # used by a couple of IPC helper scripts
  mission-center              # system monitor GUI, launched from the dashboard
  lsp-plugins                 # audio effect plugins, only relevant if you use easyeffects/cava
  cava
  easyeffects
  mpv
  mpvScripts.mpris             # media-key/MPRIS integration for the YouTube Music widget
  yt-dlp
]
