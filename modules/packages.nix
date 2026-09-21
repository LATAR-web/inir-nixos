{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  programs.firefox.enable = false;

  environment.systemPackages = with pkgs; [
    # --- Apps de usuario ---
    git
    fastfetch
    vesktop
    vscode
    brave
    obsidian
    texmaker
    texlive.combined.scheme-small
    gcc
    gnumake
    jq
    pulseaudio
    matugen
    brightnessctl
    imagemagick
    alacritty
    localsend
    inotify-tools
gh
    (python3.withPackages (ps: with ps; [
      pip
      materialyoucolor
      pillow
      evdev
      numpy
    ]))
    # Acceso directo para OnlyOffice bajo Wayland (forzando XCB)
    (makeDesktopItem {
      name = "onlyoffice-desktopeditors";
      desktopName = "ONLYOFFICE Desktop Editors";
      exec = "env GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb onlyoffice-desktopeditors %U";
      icon = "onlyoffice-desktopeditors";
      categories = [ "Office" ];
      terminal = false;
      mimeTypes = [ "application/msword" "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ];
    })
    onlyoffice-desktopeditors
  ];
}
