# Extra system packages required by iNiR (github:snowarch/iNiR) on NixOS.
# `inir doctor` reports these as missing because it assumes an Arch-style
# package manager and tries to auto-install with pacman; on NixOS they
# must be declared here and passed into programs.inir.extraPackages.
{ pkgs }:

with pkgs; [
  # --- Core shell / compositor glue ---
  quickshell
  xwayland-satellite
  swaylock
  swayidle
  blueman
  uv
  networkmanagerapplet
  mission-center
  lsp-plugins
  bc
  cliphist
  ripgrep
  xdg-user-dirs
  xdg-utils
  wl-clipboard
  libnotify
  wlsunset
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  gnome-keyring
  fish
  gum
  wget
  rsync
  curl
  coreutils
  corefonts

  # --- Qt theming (fixes "org.kde.kirigami is not installed" / broken colors) ---
  kdePackages.qt5compat
  kdePackages.kirigami
  kdePackages.qtmultimedia
  kdePackages.syntax-highlighting
  kdePackages.kdialog
  kdePackages.plasma-integration
  kdePackages.plasma-browser-integration
  kdePackages.kconfig
  darkly

  # --- Screenshots / OCR / grabación ---
  grim
  slurp
  swappy
  tesseract
  wf-recorder
  ffmpeg

  # --- Input / hardware / idle ---
  upower
  wtype
  ydotool
  ddcutil
  geoclue2
  fprintd
  libqalculate

  # --- Audio / media ---
  pavucontrol
  mpv
  mpvScripts.mpris
  socat
  cava
  easyeffects

  # --- Fuentes y theming ---
  fuzzel
  translate-shell
  libsForQt5.qtstyleplugin-kvantum
  nerd-fonts.jetbrains-mono
  roboto-flex
  google-fonts
  twitter-color-emoji
  material-symbols

  # --- YT Music widget ---
  yt-dlp
  jq

  # --- Python: intérprete plano (necesario para $PATH del servicio) ---
  python3

  # --- Python: pipeline de colores Material You ---
  (python3.withPackages (ps: with ps; [
    pip
    materialyoucolor
    pillow
    evdev
  ]))
]
